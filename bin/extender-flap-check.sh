#!/bin/bash
# extender-flap-check.sh — alert when a WiFi extender starts flapping
# or goes fully dead. Part of ~/Projects/Network-Problems.
# Cron: 12,42 * * * *   (twice an hour, offset off tsmon's 2-57/5)
#
# Why this exists (2026-08-26):
# tsmon.sh already recorded the fault for 18 hours and nothing said
# a word. Extender A's clients (.70 .212) flapped up/down ~55 times
# between 04:32 and 22:12 and then stayed down, while Doc's phone
# (.169) fell off home WiFi at 07:07 and spent the whole day on
# cellular. Every existing alert watches ROUTER LATENCY, and the
# router was clean all day — 0.7 ms, 0% loss, right through the
# usual 15:00-23:00 bad window. A perfectly healthy Hub and a dead
# extender look identical to every probe we had.
#
# So this watches the extenders themselves, on two signals:
#
#   FLAPPING  — a repeater that cycles is usually heat or a wedged
#               radio. It is visible hours before it dies, which is
#               the whole point of alerting on it.
#   DEAD      — every client of one extender unreachable for long
#               enough that it is not just a WiFi retry.
#
# Phones are deliberately EXCLUDED (tag phone_*). A phone leaving
# the house is not a fault; .169 goes to the clinic every weekday.
# Only infrastructure tags (extA, extB) are judged.
#
# Reads:  ~/logs/tsmon.csv   (wifi rows, written every 5 min)
# State:  ~/logs/.extender-flap-state   (alert cooldown)
# Log:    ~/logs/extender-flap.log

set -uo pipefail

CSV=/home/doc/logs/tsmon.csv
LOG=/home/doc/logs/extender-flap.log
STATE=/home/doc/logs/.extender-flap-state
CHAT_ID="8675098461"

# Window to count flaps over, and what counts as too many. A healthy
# extender scores 0-2 here; 2026-08-26's extA scored ~18 per 6h.
WINDOW_HOURS="${EXT_WINDOW_HOURS:-6}"
FLAP_THRESHOLD="${EXT_FLAP_THRESHOLD:-6}"
# Consecutive all-clients-down samples before calling it dead.
# tsmon runs every 5 min, so 6 samples = 30 minutes.
DOWN_THRESHOLD="${EXT_DOWN_THRESHOLD:-6}"
# A flap count alone is HISTORY: after a power-cycle the 6h window
# still holds the whole bad day and would keep crying wolf. Require
# the tag to still be misbehaving RIGHT NOW - at least this many
# transitions inside the recent window - before alerting on flaps.
# A genuinely fixed extender goes quiet on its own within the hour.
RECENT_MIN="${EXT_RECENT_MIN:-60}"
RECENT_FLAP_MIN="${EXT_RECENT_FLAP_MIN:-2}"
# Don't re-send the same alert more often than this.
COOLDOWN_HOURS="${EXT_COOLDOWN_HOURS:-6}"
# Tags that are allowed to come and go without it being a fault.
EXCLUDE_TAG_RE="${EXT_EXCLUDE_TAG_RE:-^phone}"

DRYRUN=0
[ "${1:-}" = "--dry-run" ] && DRYRUN=1

[ -f "$CSV" ] || { echo "no $CSV" >&2; exit 1; }
touch "$STATE"

CUTOFF=$(date -d "$WINDOW_HOURS hours ago" +%Y-%m-%dT%H:%M:%S)
RCUT=$(date -d "$RECENT_MIN minutes ago" +%Y-%m-%dT%H:%M:%S)

# Per-tag verdict. Timestamps all carry the same local offset, so a
# lexical compare on the first 19 chars is a correct time compare
# (the twice-a-year DST edge is not worth the mktime dependency).
#
# flaps  = MAX over the tag's clients, not sum: one flapping repeater
#          drops all of its clients at once, so summing would just
#          multiply the same event by the client count.
# down   = MIN over the tag's clients: the extender is only "dead"
#          if every one of its clients has been unreachable, which
#          is what separates a dead repeater from one dropped client.
REPORT=$(awk -F, -v cutoff="$CUTOFF" -v rcut="$RCUT" -v excl="$EXCLUDE_TAG_RE" '
  $2 != "wifi" { next }
  {
    ip = $3; st = $4; tag = $6; ts = substr($1, 1, 19)
    if (tag == "" || tag ~ excl) next
    tagof[ip] = tag
    if (st == "down") streak[ip]++; else streak[ip] = 0
    if (ts >= cutoff) {
      if (ip in prev && prev[ip] != st) flaps[ip]++
      prev[ip] = st
      samples[ip]++
    }
    if (ts >= rcut) {
      if (ip in rprev && rprev[ip] != st) rflaps[ip]++
      rprev[ip] = st
    }
  }
  END {
    for (ip in tagof) {
      t = tagof[ip]
      f = (ip in flaps) ? flaps[ip] : 0
      if (!(t in maxflap) || f > maxflap[t]) maxflap[t] = f
      rf = (ip in rflaps) ? rflaps[ip] : 0
      if (!(t in maxrflap) || rf > maxrflap[t]) maxrflap[t] = rf
      d = streak[ip]
      if (!(t in mindown) || d < mindown[t]) mindown[t] = d
      n[t]++
      s[t] += samples[ip]
      worst[t] = (f == maxflap[t]) ? ip : worst[t]
    }
    for (t in n)
      printf "%s %d %d %d %d %s %d\n", t, maxflap[t], mindown[t], n[t], s[t], worst[t], maxrflap[t]
  }' "$CSV")

now=$(date +%s)
cool=$(( COOLDOWN_HOURS * 3600 ))

send_telegram() {
    source /home/doc/.claude/channels/telegram/.env
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg chat_id "$CHAT_ID" --arg text "$1" \
            '{chat_id: $chat_id, text: $text}')" > /dev/null
}

# Cooldown is keyed on tag+kind so a flap alert and a later dead
# alert for the same extender both get through — the escalation
# from "flapping" to "dead" is exactly what Doc needs to see.
should_send() {
    local key="$1" last
    last=$(awk -v k="$key" '$1==k{print $2}' "$STATE" | tail -1)
    [ -z "$last" ] && return 0
    [ $(( now - last )) -ge "$cool" ]
}
mark_sent() {
    local key="$1"
    grep -v "^$key " "$STATE" > "$STATE.tmp" 2>/dev/null || true
    echo "$key $now" >> "$STATE.tmp"
    mv "$STATE.tmp" "$STATE"
}

ALERTS=""
KEYS=()
HEALTHY=()
while read -r tag flaps down nips nsamp worst rflaps; do
    [ -z "$tag" ] && continue
    if [ "$down" -ge "$DOWN_THRESHOLD" ]; then
        mins=$(( down * 5 ))
        ALERTS+="DEAD  $tag — all $nips clients unreachable ${mins}min"$'\n'
        KEYS+=("$tag:dead")
    elif [ "$flaps" -ge "$FLAP_THRESHOLD" ] && [ "$rflaps" -ge "$RECENT_FLAP_MIN" ]; then
        ALERTS+="FLAP  $tag — $flaps up/down in ${WINDOW_HOURS}h (worst $worst)"$'\n'
        KEYS+=("$tag:flap")
    else
        HEALTHY+=("$tag")
    fi
done <<< "$REPORT"

# An extender that has recovered must not carry its cooldown - if it
# dies again at 03:00 that alert has to land immediately, not be
# swallowed by the entry written when it died at 22:56.
if [ "$DRYRUN" != 1 ] && [ "${#HEALTHY[@]}" -gt 0 ]; then
    for t in "${HEALTHY[@]}"; do
        if grep -q "^$t:" "$STATE" 2>/dev/null; then
            grep -v "^$t:" "$STATE" > "$STATE.tmp" 2>/dev/null || true
            mv "$STATE.tmp" "$STATE"
            echo "[$(date '+%F %T')] $t recovered, cooldown cleared" >> "$LOG"
        fi
    done
fi

if [ "$DRYRUN" = 1 ]; then
    echo "cutoff=$CUTOFF  flap>=$FLAP_THRESHOLD  down>=$DOWN_THRESHOLD"
    echo "--- per-tag (tag maxflaps downstreak nclients nsamples worst recentflaps) ---"
    echo "$REPORT"
    echo "healthy: ${HEALTHY[*]:-none}"
    echo "--- would alert ---"
    echo "${ALERTS:-（none）}"
    exit 0
fi

[ -z "$ALERTS" ] && exit 0

# Include the router line so the message answers the obvious next
# question — is this the extender, or is the Hub down again?
rout=$(ping -c 5 -W 2 -i 0.3 192.168.2.1 2>/dev/null)
ravg=$(echo "$rout" | sed -n 's|.*= [0-9.]*/\([0-9.]*\)/.*|\1|p')
rloss=$(echo "$rout" | sed -n 's/.* \([0-9]*\)% packet loss.*/\1/p')

MSG="WiFi extender alert $(date '+%a %d %b %H:%M')
$ALERTS
Hub 192.168.2.1: ${ravg:-n/a} ms, loss ${rloss:-100}%
(Hub clean => the extender is the fault; power-cycle it.)"

sent=0
[ "${#KEYS[@]}" -eq 0 ] && exit 0
for k in "${KEYS[@]}"; do should_send "$k" && sent=1; done
if [ "$sent" = 1 ]; then
    send_telegram "$MSG"
    for k in "${KEYS[@]}"; do mark_sent "$k"; done
    echo "[$(date '+%F %T')] SENT" >> "$LOG"; echo "$MSG" >> "$LOG"
else
    echo "[$(date '+%F %T')] suppressed (cooldown): ${ALERTS//$'\n'/ }" >> "$LOG"
fi
