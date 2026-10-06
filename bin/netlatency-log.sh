#!/bin/bash
# Log network latency + load + session/throughput
# context, so the daily degradation can be pinned to a
# time window AND to a mechanism.
#
# Context (2026-08-12..19): the router at 192.168.2.1
# intermittently adds ~1s latency and drops 40-80% of
# packets, 15:00-23:00, while the LAN itself stays
# clean. The NAS probe is the control - it goes via
# the switch only and bypasses the router. If nas_lan
# stays fast while router/internet go slow, the router
# is confirmed as the culprit.
#
# 2026-08-19: added conntrack + throughput columns.
# Why: ubuntu-s1's own bandwidth turned out to be
# ANTI-correlated with the failure (Aug 15 pushed
# 2 MB/s and the router was perfect; Aug 13 pushed
# 17 kB/s and it lost 23% of packets). So raw
# bandwidth is not the trigger. The leading
# hypothesis is now NAT/session-table exhaustion -
# many small connections, little data - which is the
# classic consumer-router failure and fits
# qbittorrent. These columns test that directly:
#   conntrack  - session count (the suspect)
#   rx/tx_kBps - bandwidth  (the ruled-out control)
#   qbit       - whether qbittorrent is running
#
# CSV:       ~/logs/netlatency.csv
# Forensics: ~/logs/netlatency-highsys/
# Markers:   netlatency-mark.sh "note"

set -uo pipefail

LOGDIR="$HOME/logs"
CSV="$LOGDIR/netlatency.csv"
FORENSIC="$LOGDIR/netlatency-highsys"
IFACE=eno1
mkdir -p "$LOGDIR" "$FORENSIC"

TS=$(date -Is)

HDR="timestamp,probe,target,rtt_ms,loss_pct,load1,sys_pct"
HDR="$HDR,conntrack,rx_kBps,tx_kBps,qbit"
HDR="$HDR,wan_tx_pps,wan_rx_pps"
[ -f "$CSV" ] || echo "$HDR" > "$CSV"

# --- household-wide WAN packet rate, read from the modem ---
# The Bell Giga Hub 4000E (Sagemcom Fast 5689E) exposes UPnP
# WANCommonInterfaceConfig. It does NOT implement the optional
# GetActiveConnection / NumberOfActiveConnections actions, so the
# NAT table size cannot be read directly. Packet counters DO work
# (byte counters are pinned at 2^32-1, a firmware bug, so ignore
# them). This is the only view of what the WHOLE household pushes
# through the modem - ubuntu-s1's own counters miss every other
# device, which is why the cause stayed invisible for a week.
#
# High packets/s is the best available proxy for session/CPU
# pressure on the modem: many small packets => many flows.
#
# Rate is computed against the previous run (5 min) via a state
# file, so each run makes only two SOAP calls.
WAN_URL="http://192.168.2.1:49152/47393558/upnp/control/WANCommonIFC1"
WAN_SVC="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1"
WAN_STATE="$LOGDIR/.netlatency-wan-state"

wan_query() {
    timeout 8 curl -sS -X POST "$WAN_URL" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SOAPAction: \"$WAN_SVC#$1\"" \
        --data "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:$1 xmlns:u=\"$WAN_SVC\"></u:$1></s:Body></s:Envelope>" \
        2>/dev/null | grep -oE '[0-9]+' | tail -1
}

WAN_TX_PPS=""
WAN_RX_PPS=""
NOW_EPOCH=$(date +%s)
CUR_TX=$(wan_query GetTotalPacketsSent)
CUR_RX=$(wan_query GetTotalPacketsReceived)

if [ -n "$CUR_TX" ] && [ -n "$CUR_RX" ]; then
    if [ -f "$WAN_STATE" ]; then
        read -r P_TX P_RX P_EP < "$WAN_STATE" 2>/dev/null || true
        DT=$(( NOW_EPOCH - ${P_EP:-0} ))
        # Guard against counter reset (modem reboot) and a stale
        # or absent state file.
        if [ "${P_TX:-0}" -gt 0 ] && [ "$DT" -gt 0 ] \
           && [ "$DT" -lt 3600 ] \
           && [ "$CUR_TX" -ge "${P_TX:-0}" ] \
           && [ "$CUR_RX" -ge "${P_RX:-0}" ]; then
            WAN_TX_PPS=$(( (CUR_TX - P_TX) / DT ))
            WAN_RX_PPS=$(( (CUR_RX - P_RX) / DT ))
        fi
    fi
    echo "$CUR_TX $CUR_RX $NOW_EPOCH" > "$WAN_STATE"
fi

# --- %sys and throughput sampled over the same 2s ---
read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat
RX1=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
TX1=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)
sleep 2
read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat
RX2=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
TX2=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)

tot=$(( (u2+n2+s2+i2+w2+q2+sq2) \
      - (u1+n1+s1+i1+w1+q1+sq1) ))
sysd=$(( s2 - s1 ))
if [ "$tot" -gt 0 ]; then
    SYS=$(awk "BEGIN{printf \"%.1f\", $sysd*100/$tot}")
else
    SYS=""
fi
RXKB=$(awk "BEGIN{printf \"%.1f\", ($RX2-$RX1)/2048}")
TXKB=$(awk "BEGIN{printf \"%.1f\", ($TX2-$TX1)/2048}")

LOAD=$(awk '{print $1}' /proc/loadavg)

# Session count - the current prime suspect. This is
# ubuntu-s1's own table, not the router's (which we
# cannot query), but it tracks how many sessions this
# host pushes through the router.
CT=$(cat /proc/sys/net/netfilter/nf_conntrack_count \
     2>/dev/null || echo "")

if docker ps --format '{{.Names}}' 2>/dev/null \
   | grep -qi qbittorrent; then
    QBIT=1
else
    QBIT=0
fi

EXTRA="$LOAD,$SYS,$CT,$RXKB,$TXKB,$QBIT"
EXTRA="$EXTRA,$WAN_TX_PPS,$WAN_RX_PPS"

probe() {
    local label="$1" ip="$2" out avg loss
    out=$(ping -c 5 -i 0.3 -W 2 "$ip" 2>/dev/null)
    loss=$(printf '%s' "$out" \
           | grep -oE '[0-9.]+% packet loss' \
           | grep -oE '^[0-9.]+')
    avg=$(printf '%s' "$out" \
          | awk -F'/' '/^rtt|^round-trip/ {print $5}')
    echo "$TS,$label,$ip,${avg:-},${loss:-100},$EXTRA" \
        >> "$CSV"
}

probe router   192.168.2.1
probe internet 8.8.8.8
probe nas_lan  192.168.2.175

# --- DNS resolution time, as apps experience it -----
s=$(date +%s%N)
if timeout 30 getent hosts google.com >/dev/null 2>&1
then rc=0; else rc=100; fi
e=$(date +%s%N)
echo "$TS,dns,google.com,$(( (e-s)/1000000 )),$rc,$EXTRA" \
    >> "$CSV"

# --- forensics if kernel CPU goes pathological ------
if [ -n "$SYS" ] && awk "BEGIN{exit !($SYS > 40)}"; then
    f="$FORENSIC/highsys-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "=== $TS  sys=${SYS}%  load=$LOAD ==="
        echo "--- top by CPU ---"
        ps -eo pcpu,pmem,stat,etimes,user,comm \
           --sort=-pcpu | head -25
        echo "--- runnable / uninterruptible ---"
        ps -eo stat,pid,user,comm | awk '$1 ~ /^[RD]/'
        echo "--- pressure ---"
        for p in cpu io memory; do
            echo "[$p]"
            cat "/proc/pressure/$p" 2>/dev/null
        done
    } > "$f" 2>&1
fi
