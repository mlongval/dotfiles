#!/bin/bash
# tvbox-check.sh — nightly 21:00 snapshot of the Giga Hub and the Fibe TV
# boxes, posted to Telegram. Part of ~/Projects/Network-Problems.
# Cron: 3 21 * * *   (see FINDINGS.md)
set -u
CHAT_ID="8675098461"
source /home/doc/.claude/channels/telegram/.env
CSV=/home/doc/logs/netlatency.csv
LOG=/home/doc/logs/tvbox-check.log
TODAY=$(date +%F)

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg chat_id "$CHAT_ID" --arg text "$1" \
            '{chat_id: $chat_id, text: $text}')" > /dev/null
}

# one line per host: avg ms / loss %
probe() {  # ip label
    local out avg loss
    out=$(ping -c 5 -W 2 -i 0.3 "$1" 2>/dev/null)
    loss=$(echo "$out" | sed -n 's/.* \([0-9]*\)% packet loss.*/\1/p')
    avg=$(echo "$out" | sed -n 's|.*= [0-9.]*/\([0-9.]*\)/.*|\1|p')
    printf "  %-6s %-14s %6s ms  loss %3s%%\n" "$2" "$1" "${avg:-n/a}" "${loss:-100}"
}

LIVE="$(probe 192.168.2.1 hub)
$(probe 192.168.2.200 wired)
$(probe 192.168.2.19 wifi)
$(probe 192.168.2.158 wifi)
$(probe 192.168.2.168 wifi)
$(probe 192.168.2.59 wifi)"

HUB_NOW=$(echo "$LIVE" | head -1 | awk '{print $3}')
STATE="OK"
awk -v v="$HUB_NOW" 'BEGIN{exit !(v+0>100)}' && STATE="DEGRADED"

# today's router rows from netlatency.csv: rtt=$4 loss=$5 wan_tx=$12 wan_rx=$13 conntrack=$8
TODAY_STATS=$(awk -F, -v d="$TODAY" '
  $2=="router" && substr($1,1,10)==d {
    n++; bad=($4+0>100||$5+0>5)
    if(bad){nb++; if(!f)f=substr($1,12,5); l=substr($1,12,5)
            if($12!=""){bp+=$12+$13; bc+=$8; nbc++}}
    else   {if($12!=""){gp+=$12+$13; gc+=$8; ngc++}}
  }
  END{
    printf "  samples %d, degraded %d", n, nb
    if(nb) printf " (%s-%s)", f, l
    printf "\n"
    if(nbc&&ngc) printf "  wan pps good %.0f vs bad %.0f | conntrack good %.0f vs bad %.0f\n", gp/ngc, bp/nbc, gc/ngc, bc/nbc
  }' "$CSV")

VERDICT=""
if echo "$TODAY_STATS" | grep -q 'vs bad'; then
    VERDICT=$(echo "$TODAY_STATS" | awk '/vs bad/{
        g=$4; b=$6; sub(/\|.*/,"")
        if(b>g*1.5) print "  -> WAN pps much higher when bad: household load on the Hub"
        else print "  -> WAN pps flat when bad: Hub failing on its own (thermal/firmware/upstream)"}')
fi

MSG="TV-box check $(date '+%a %d %b %H:%M') — Hub $STATE
Live pings:
$LIVE
Today (netlatency.csv):
$TODAY_STATS${VERDICT:+
$VERDICT}"

echo "[$(date '+%F %T')]" >> "$LOG"; echo "$MSG" >> "$LOG"
send_telegram "$MSG"
