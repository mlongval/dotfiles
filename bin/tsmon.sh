#!/bin/bash
# Log Tailscale reachability alongside plain LAN health, so
# "I can't reach the server from my phone" can be pinned to
# a cause instead of guessed at.
#
# Context (2026-08-16): Doc reported recurring trouble
# reaching ubuntu-s1 from his iPhone. ~/logs/netlatency.csv
# showed the router at 192.168.2.1 sitting at ~1000 ms with
# 40-60% packet loss for 2.5 hours that afternoon, while the
# NAS (switch-only, bypasses the router) stayed at 0.4 ms.
# Same signature as 2026-08-12. Degradation only ever lands
# in the 15:00-23:00 window - never overnight - which rules
# out the 2:17am offsite backup that was the prior suspect.
#
# A router in that state breaks Tailscale both ways: direct
# LAN connections to 192.168.2.234 stall, and the DERP relay
# path is just as dead because it also crosses the router.
#
# This script records which of those two paths is failing,
# which is the thing netlatency.csv cannot tell you:
#   - is tailscaled itself healthy
#   - is the phone online in the tailnet at all
#   - is it connected direct or via DERP relay
#   - what round-trip does it actually get
#
# The LAN control probe is repeated here on purpose. It makes
# each row self-contained: if a peer is unreachable while the
# NAS is at 0.4 ms and the router is at 1000 ms, the router is
# the answer and no cross-referencing is needed.
#
# CSV:       ~/logs/tsmon.csv
# Forensics: ~/logs/tsmon-events/
# Report:    ~/bin/tsmon-report.sh

set -uo pipefail

LOGDIR="$HOME/logs"
CSV="$LOGDIR/tsmon.csv"
EVENTS="$LOGDIR/tsmon-events"
mkdir -p "$LOGDIR" "$EVENTS"

TS=$(date -Is)
TSCLI=$(command -v tailscale || echo /usr/bin/tailscale)

# Peers to actively probe with `tailscale ping`. These are the
# devices Doc actually connects FROM. Everything else is only
# recorded passively from `tailscale status`.
WATCH="${TSMON_WATCH:-gandalf-iphone lili-iphone ipad-pro-12-9-gen-4}"

[ -f "$CSV" ] || echo \
  "timestamp,kind,name,status,rtt_ms,path,detail" >> "$CSV"

row() {
    # kind,name,status,rtt_ms,path,detail
    echo "$TS,$1,$2,$3,${4:-},${5:-},${6:-}" >> "$CSV"
}

# --- is the daemon even up -----------------------------
if systemctl is-active --quiet tailscaled; then
    # A climbing restart count is the tell for a flapping
    # daemon, which looks identical to a network fault
    # from the phone's side.
    nrestarts=$(systemctl show tailscaled -p NRestarts --value 2>/dev/null)
    started=$(systemctl show tailscaled -p ActiveEnterTimestamp \
              --value 2>/dev/null)
    row daemon tailscaled up "" "" \
        "restarts=${nrestarts:-0};since=${started// /_}"
else
    row daemon tailscaled down "" "" "systemctl is-active said not active"
fi

# --- LAN control, same probes as netlatency-log.sh -----
# nas_lan bypasses the router; router does not. The pair is
# what makes a Tailscale failure interpretable.
lanprobe() {
    local label="$1" ip="$2" out avg loss
    out=$(ping -c 5 -i 0.3 -W 2 "$ip" 2>/dev/null)
    loss=$(printf '%s' "$out" | grep -oE '[0-9.]+% packet loss' \
           | grep -oE '^[0-9.]+')
    avg=$(printf '%s' "$out" \
          | awk -F'/' '/^rtt|^round-trip/ {print $5}')
    row lan "$label" ok "${avg:-}" "" "loss=${loss:-100}"
    echo "${avg:-99999}"
}
ROUTER_RTT=$(lanprobe router  192.168.2.1)
lanprobe nas_lan 192.168.2.175 >/dev/null

# --- TCP probes: the decisive test ---------------------
# Pinging the router only proves its ICMP responder is
# slow, and consumer routers routinely deprioritise ICMP
# when busy. A TCP handshake to the router's OWN web UI
# cannot be deprioritised the same way - it has to be
# serviced by the main CPU.
#
# This discriminates the two causes, which matter because
# they have opposite fixes:
#
#   router_tcp slow too  -> the Giga Hub's CPU is genuinely
#                           saturated. Offloading NAT to a
#                           dedicated router behind it WILL
#                           help.
#   router_tcp fast, ICMP slow, WAN slow
#                        -> ICMP is merely deprioritised and
#                           the real problem is upstream
#                           (Bell PON / fibre congestion). A
#                           new router will NOT help.
#
# nas_tcp is the control: it stays on the switch.
tcpprobe() {
    local label="$1" host="$2" port="$3" s e
    s=$(date +%s%N)
    if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        e=$(date +%s%N)
        row tcp "$label" ok "$(( (e-s)/1000000 ))" "" "port=$port"
    else
        row tcp "$label" fail "" "" "port=$port;timeout_or_refused"
    fi
}
tcpprobe router_tcp 192.168.2.1     80
tcpprobe nas_tcp    192.168.2.175   22
tcpprobe wan_tcp    1.1.1.1        443

# --- Bell Fibe TV boxes --------------------------------
# Five ARRIS boxes, identified 2026-08-16 by OUI. Four are
# on WiFi and one (.200) is wired. Bell Fibe TV is IPTV, so
# these stream continuously during prime time - which is
# exactly the 15:00-23:00 window where the router falls
# over. Tracking their jitter tells us whether the WiFi
# side is what loads the Hub.
#
# Baseline measured while the router was healthy:
#   .200 wired  0.40 ms avg, mdev 0.06   <- reference
#   .168 wifi  22.6 ms avg, mdev 28.6
#   .158 wifi  27.4 ms avg, mdev 44.4
#   .19  wifi  29.3 ms avg, mdev 48.7
#   .59  wifi  63.5 ms avg, mdev 96.8, max 392 ms  <- worst
TVBOXES="${TSMON_TVBOXES:-192.168.2.19:wifi 192.168.2.59:wifi \
192.168.2.158:wifi 192.168.2.168:wifi 192.168.2.200:wired}"

for entry in $TVBOXES; do
    ip=${entry%%:*}; link=${entry##*:}
    out=$(ping -c 10 -i 0.2 -W 2 "$ip" 2>/dev/null)
    loss=$(printf '%s' "$out" | grep -oE '[0-9.]+% packet loss' \
           | grep -oE '^[0-9.]+')
    # min/avg/max/mdev - mdev is the interesting one here,
    # since WiFi contention shows up as jitter long before
    # it shows up as loss.
    nums=$(printf '%s' "$out" \
           | grep -oE '= [0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' \
           | sed 's/= //')
    avg=$(printf '%s' "$nums" | cut -d/ -f2)
    max=$(printf '%s' "$nums" | cut -d/ -f3)
    mdev=$(printf '%s' "$nums" | cut -d/ -f4)
    row tvbox "$ip" "$([ -n "$avg" ] && echo up || echo down)" \
        "${avg:-}" "$link" "max=${max:-};mdev=${mdev:-};loss=${loss:-100}"
done

# --- WiFi extenders ------------------------------------
# Two TP-Link units, and they are REPEATERS, not APs -
# established 2026-08-16 by MAC translation, which only a
# wireless repeater does (an AP with wired backhaul bridges
# client MACs through unchanged):
#
#   MyQ opener .212  real 0c:83:cc:04:9a:94 -> seen as 8c:90:2d:b7:f2:71
#   Chromecast .55   real f4:f5:d8:39:58:10 -> seen as 26:23:51:13:99:95
#
# The Chromecast also reports ssid=BELL932_EXT5 (TP-Link's
# "_EXT" range-extender default) and bssid=20:23:51:13:99:95,
# the same radio as bridge MAC 26:23:51:13:99:95.
#
#   extender A  8c:90:2d:b7:f2:71  ssid BELL932_HAUT -> .70 .212 .169
#   extender B  26:23:51:13:99:95  ssid BELL932_EXT5 -> .55 .75 .145 .160 .191
#
# This matters because .169 is gandalf-iphone. Doc's phone
# does not talk to the Hub directly - it goes phone ->
# extender A -> Hub -> ubuntu-s1. Two wireless hops, either
# of which can be the thing that breaks "I can't reach the
# server from my phone".
#
# Probing the phone's LAN address separates the layers: if the
# phone is bad at the IP level, the problem is the WiFi path
# and not Tailscale at all.
#
# The phone's LAN address is NOT hardcoded, and that is
# deliberate (2026-08-26): it used to be pinned to .169, the
# phone spent a day on cellular, and DHCP handed it .166 when
# it came back. tsmon went on probing .169 - an address with
# nothing behind it - and would have reported the phone as
# permanently down forever. Any hardcoded LAN IP for a device
# that leaves the house is a time bomb.
#
# Instead we read it from `tailscale status`, which already
# knows: a peer connected DIRECT reports its LAN socket in
# CurAddr. Three cases, and they are genuinely different
# things that used to be flattened into "down":
#
#   CurAddr on the LAN prefix -> phone is on home WiFi. Probe
#                                it, and cache the address.
#   CurAddr elsewhere / relayed via DERP
#                             -> phone is AWAY (cellular, or
#                                at the clinic). Not a fault.
#                                Do NOT ping the cached IP:
#                                the lease may already belong
#                                to another device.
#   no peer at all            -> phone offline in the tailnet.
TSCSV_JSON=$(mktemp)
trap 'rm -f "$TSCSV_JSON"' EXIT
"$TSCLI" status --json >"$TSCSV_JSON" 2>/dev/null
JSONF="$TSCSV_JSON"
STATUS_JSON=$(cat "$JSONF")

PHONE_PEER="${TSMON_PHONE_PEER:-gandalf-iphone}"
LAN_PREFIX="${TSMON_LAN_PREFIX:-192.168.2.}"
PHONE_CACHE="$LOGDIR/.tsmon-phone-ip"

# prints: "<lan_ip>" if on the LAN, else "away <curaddr-or-relay>"
phone_lan_ip() {
    python3 - "$JSONF" "$PHONE_PEER" "$LAN_PREFIX" <<'PYEOF' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
peer, pfx = sys.argv[2], sys.argv[3]
for p in (d.get("Peer") or {}).values():
    n = (p.get("DNSName") or p.get("HostName") or "").split(".")[0]
    if n != peer:
        continue
    if not p.get("Online"):
        print("away offline_in_tailnet"); sys.exit()
    cur = p.get("CurAddr") or ""
    ip = cur.rsplit(":", 1)[0] if cur else ""
    if ip.startswith(pfx):
        print(ip)
    else:
        print("away " + (cur or "derp:" + (p.get("Relay") or "?")))
    sys.exit()
print("away not_in_tailnet")
PYEOF
}

# CurAddr is only populated while a DIRECT path is up. Tailscale
# lets an idle peer fall back to DERP, and then CurAddr is empty
# even though the phone is sitting on home WiFi three metres away
# - observed on the very first live run, 2026-08-27 00:06, which
# reported "away reason=derp:tor" for a phone that `tailscale
# ping` reached at 192.168.2.166 seconds earlier.
#
# So when the JSON says away, nudge the path awake and ask again:
# `tailscale ping` forces direct and prints the address it used.
# Only an away verdict is retried, so a phone genuinely on
# cellular costs one extra probe and still ends up away.
PHONE_RESULT=$(phone_lan_ip)
case "$PHONE_RESULT" in
    away*)
        # Scan EVERY line, not just the last: `tailscale ping`
        # often pongs via DERP first and only then upgrades to
        # direct, so the direct address can sit mid-output while
        # the final line is still a relay. Taking tail -1 lost it
        # roughly one run in three (measured 2026-08-27).
        pout=$(timeout 25 "$TSCLI" ping --c 5 --timeout 5s "$PHONE_PEER" 2>&1)
        pip=$(printf '%s' "$pout" | grep -oE "via ${LAN_PREFIX//./\\.}[0-9]+" \
              | head -1 | sed 's/^via //')
        [ -n "$pip" ] && PHONE_RESULT="$pip"
        ;;
esac
PHONE_TAG=phone_behind_extA
EXTENDERS="${TSMON_EXTENDERS:-192.168.2.70:extA 192.168.2.212:extA \
192.168.2.55:extB}"

case "$PHONE_RESULT" in
    away*)
        # Record WHY, and what the last known LAN address was,
        # so the report can tell "left the house" from "broken".
        row wifi "${PHONE_PEER}" away "" "$PHONE_TAG" \
            "reason=${PHONE_RESULT#away };last_lan=$(cat "$PHONE_CACHE" 2>/dev/null || echo none)"
        ;;
    "$LAN_PREFIX"*)
        echo "$PHONE_RESULT" > "$PHONE_CACHE"
        EXTENDERS="$EXTENDERS $PHONE_RESULT:$PHONE_TAG"
        ;;
    *)
        row wifi "${PHONE_PEER}" unknown "" "$PHONE_TAG" \
            "reason=could_not_resolve"
        ;;
esac

for entry in $EXTENDERS; do
    ip=${entry%%:*}; tag=${entry##*:}
    out=$(ping -c 8 -i 0.2 -W 2 "$ip" 2>/dev/null)
    loss=$(printf '%s' "$out" | grep -oE '[0-9.]+% packet loss' \
           | grep -oE '^[0-9.]+')
    nums=$(printf '%s' "$out" \
           | grep -oE '= [0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' | sed 's/= //')
    avg=$(printf '%s' "$nums" | cut -d/ -f2)
    max=$(printf '%s' "$nums" | cut -d/ -f3)
    mdev=$(printf '%s' "$nums" | cut -d/ -f4)
    row wifi "$ip" "$([ -n "$avg" ] && echo up || echo down)" \
        "${avg:-}" "$tag" "max=${max:-};mdev=${mdev:-};loss=${loss:-100}"
done

# --- multicast rate ------------------------------------
# IPTV is multicast. A box stuck re-joining groups, or
# IGMP snooping failing on the Hub, floods the wired LAN
# too - and ubuntu-s1 sees that flood. Counter deltas are
# taken against the previous run (5 min ago) via a state
# file, which costs nothing.
STATE="$LOGDIR/.tsmon-mcast"
now_m=$(awk '/eno1/{print $9}' /proc/net/dev)
now_t=$(date +%s)
if [ -f "$STATE" ]; then
    read -r prev_m prev_t < "$STATE"
    dt=$(( now_t - prev_t ))
    if [ "$dt" -gt 0 ] && [ "$now_m" -ge "${prev_m:-0}" ]; then
        row mcast eno1 ok "" "" \
            "pkts_per_s=$(( (now_m - prev_m) / dt ));window_s=$dt"
    fi
fi
echo "$now_m $now_t" > "$STATE"

# --- tailnet state -------------------------------------
# JSONF was captured once, above, before the extender probes.
if [ ! -s "$JSONF" ]; then
    row self ubuntu-s1 unknown "" "" "tailscale status --json returned nothing"
else
    # Script arrives on stdin, JSON comes in by path - keeping
    # them separate avoids fighting over stdin.
    python3 - "$CSV" "$TS" "$JSONF" <<'PY' || \
        row self ubuntu-s1 parse_error "" "" "python3 parse failed"
import json, sys

csv_path, ts, json_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(json_path) as fh:
    d = json.load(fh)

def row(kind, name, status, rtt="", path="", detail=""):
    with open(csv_path, "a") as f:
        f.write(f"{ts},{kind},{name},{status},{rtt},{path},{detail}\n")

self_ = d.get("Self", {})
row("self", self_.get("HostName", "ubuntu-s1"),
    "online" if self_.get("Online") else "offline",
    "", "", f"derp_home={self_.get('Relay','')}")

# BackendState: Running / NeedsLogin / Stopped / NoState
row("backend", "state", d.get("BackendState", "unknown"), "", "",
    f"health={'|'.join(d.get('Health') or []) or 'ok'}")

for p in (d.get("Peer") or {}).values():
    name = (p.get("DNSName") or p.get("HostName") or "?").split(".")[0]
    online = p.get("Online")
    if not online:
        continue
    cur = p.get("CurAddr") or ""
    path = "direct" if cur else "derp"
    row("peer", name, "online", "", path,
        f"addr={cur or p.get('Relay','')};rx={p.get('RxBytes',0)};tx={p.get('TxBytes',0)}")
PY
fi

# --- active reachability probe to Doc's devices --------
# `tailscale ping` is the only thing that proves the data
# path works end to end; `status` only proves the control
# plane agrees the peer exists.
for peer in $WATCH; do
    online=$(printf '%s' "$STATUS_JSON" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit()
for p in (d.get('Peer') or {}).values():
    n=(p.get('DNSName') or p.get('HostName') or '').split('.')[0]
    if n=='$peer' and p.get('Online'): print('yes')
" 2>/dev/null)

    if [ "$online" != "yes" ]; then
        row tsping "$peer" offline "" "" "not online in tailnet; not probed"
        continue
    fi

    out=$(timeout 20 "$TSCLI" ping --c 3 --timeout 5s "$peer" 2>&1 | tail -1)
    if printf '%s' "$out" | grep -q '^pong'; then
        rtt=$(printf '%s' "$out" | grep -oE 'in [0-9]+ms' | grep -oE '[0-9]+')
        if printf '%s' "$out" | grep -qi 'DERP'; then
            path=derp
        else
            path=direct
        fi
        row tsping "$peer" pong "${rtt:-}" "$path" "$(printf '%s' "$out" | tr ',' ';')"
    else
        row tsping "$peer" fail "" "" "$(printf '%s' "$out" | tr ',' ';' | cut -c1-120)"
    fi
done

# --- forensics when the router is in its bad state -----
# This is the window where the phone problem actually
# happens, so grab the evidence that identifies WHICH
# device is hammering the router. Nothing on ubuntu-s1
# looked guilty when checked by hand, so the culprit is
# most likely another host on the LAN - capture what we
# can see of it while it is happening.
if awk "BEGIN{exit !(${ROUTER_RTT:-0} > 100)}"; then
    f="$EVENTS/router-degraded-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "=== $TS  router_rtt=${ROUTER_RTT}ms ==="
        echo "--- conntrack ---"
        cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null
        echo "--- eno1 counters (errors/drops) ---"
        ip -s link show eno1
        echo "--- established connections ---"
        ss -tunp state established 2>/dev/null | head -60
        echo "--- our own WAN-bound talkers ---"
        ss -tun state established 2>/dev/null \
            | awk '{print $6}' | sed 's/:[0-9]*$//' \
            | grep -vE '^(192\.168\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.|10\.|100\.|127\.)' \
            | sort | uniq -c | sort -rn | head -20
        echo "--- qbittorrent transfer (classic router-killer) ---"
        docker exec qbittorrent sh -c \
            'cat /proc/net/dev 2>/dev/null | head -5' 2>/dev/null \
            || echo "(could not read from container)"
        echo "--- arp: who is on the LAN right now ---"
        ip neigh show dev eno1
        echo "--- tailscale status ---"
        "$TSCLI" status 2>/dev/null | grep -v 'offline, last seen'
    } > "$f" 2>&1
fi
