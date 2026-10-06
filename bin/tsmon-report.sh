#!/bin/bash
# Read back ~/logs/tsmon.csv and ~/logs/netlatency.csv and
# answer the only question that matters: when the phone
# could not reach the server, what was the router doing?
#
# Usage: tsmon-report.sh [days_back]   (default 7)

set -uo pipefail

DAYS="${1:-7}"
TSCSV="$HOME/logs/tsmon.csv"
NLCSV="$HOME/logs/netlatency.csv"
SINCE=$(date -d "$DAYS days ago" +%Y-%m-%d)

echo "=== Since $SINCE ==="
echo

if [ -s "$NLCSV" ]; then
    echo "--- Router health by hour of day (LAN, from netlatency.csv) ---"
    echo "    degraded = RTT to 192.168.2.1 over 100 ms"
    awk -F, -v since="$SINCE" '
        $2=="router" && substr($1,1,10) >= since {
            h=substr($1,12,2); tot[h]++; if ($4+0 > 100) bad[h]++
        }
        END {
            for (i=0; i<24; i++) {
                k=sprintf("%02d", i)
                if (!(k in tot)) continue
                p = 100*bad[k]/tot[k]
                printf "    %s:00  %4d/%-4d  %5.1f%%  ", k, bad[k], tot[k], p
                n=int(p/2); for (j=0; j<n; j++) printf "#"
                printf "\n"
            }
        }' "$NLCSV"
    echo

    echo "--- Contiguous degraded windows ---"
    awk -F, -v since="$SINCE" '
        $2=="router" && substr($1,1,10) >= since {
            bad = ($4+0 > 100)
            if (bad && !inw)       { inw=1; start=$1; n=1 }
            else if (bad && inw)   { n++ }
            else if (!bad && inw)  { inw=0; printf "    %s -> %s  (%d samples)\n", start, prev, n }
            prev=$1
        }
        END { if (inw) printf "    %s -> %s  (%d samples) ONGOING\n", start, prev, n }
    ' "$NLCSV"
    echo
fi

[ -s "$TSCSV" ] || { echo "(no tsmon.csv yet - monitor has not run)"; exit 0; }

echo "--- Tailscale daemon problems ---"
awk -F, -v since="$SINCE" '
    substr($1,1,10) >= since && $2=="daemon" && $4!="up" {print "    "$0; n++}
    substr($1,1,10) >= since && $2=="backend" && $4!="Running" {print "    "$0; n++}
    END { if (!n) print "    none - tailscaled stayed up and Running" }
' "$TSCSV"
echo

echo "--- Reachability to Doc's devices (tailscale ping) ---"
awk -F, -v since="$SINCE" '
    substr($1,1,10) >= since && $2=="tsping" {
        tot[$3]++
        if ($4=="pong")        { ok[$3]++;   sum[$3]+=$5; if($6=="derp") derp[$3]++ }
        else if ($4=="fail")   { fail[$3]++ }
        else                   { off[$3]++ }
    }
    END {
        printf "    %-26s %6s %7s %7s %7s %9s %7s\n", \
               "peer","probes","pong","FAIL","offline","avg_rtt","viaDERP"
        for (p in tot)
            printf "    %-26s %6d %7d %7d %7d %8.0fms %7d\n", \
                   p, tot[p], ok[p], fail[p], off[p], \
                   (ok[p] ? sum[p]/ok[p] : 0), derp[p]
    }
' "$TSCSV"
echo

echo "--- Every failed reach, with the router RTT at that moment ---"
echo "    (this is the correlation: router slow => phone cannot connect)"
awk -F, -v since="$SINCE" '
    substr($1,1,10) < since { next }
    $2=="lan" && $3=="router" { rtt[$1]=$5 }
    $2=="tsping" && $4=="fail" { f[++n]=$1"\t"$3 }
    END {
        if (!n) { print "    none - every probe got a pong"; exit }
        for (i=1; i<=n; i++) {
            split(f[i], a, "\t")
            r = (a[1] in rtt) ? rtt[a[1]] "ms" : "?"
            printf "    %s  %-24s router=%s\n", a[1], a[2], r
        }
    }
' "$TSCSV"
echo

echo "--- Bell Fibe TV boxes (IPTV load on the Hub) ---"
echo "    .200 is wired and is the reference. If the WiFi boxes"
echo "    degrade while .200 stays flat, the Hub's WiFi is the load."
awk -F, -v since="$SINCE" '
    substr($1,1,10) >= since && $2=="tvbox" {
        split($7, d, ";"); sub("mdev=", "", d[2])
        n[$3]++; link[$3]=$6; sa[$3]+=$5; sm[$3]+=d[2]
        if ($5+0 > mx[$3]) mx[$3]=$5+0
        h=substr($1,12,2)+0
        if (h>=15 && h<=22) { pn[$3]++; pa[$3]+=$5 } else { on[$3]++; oa[$3]+=$5 }
    }
    END {
        if (!length(n)) { print "    no samples yet"; exit }
        printf "    %-16s %-6s %8s %8s %9s %10s %10s\n", \
               "box","link","avg","jitter","worst","peak_avg","offpk_avg"
        for (b in n)
            printf "    %-16s %-6s %7.1fms %7.1fms %8.0fms %9s %9s\n", \
                   b, link[b], sa[b]/n[b], sm[b]/n[b], mx[b], \
                   (pn[b] ? sprintf("%.0fms", pa[b]/pn[b]) : "-"), \
                   (on[b] ? sprintf("%.0fms", oa[b]/on[b]) : "-")
    }
' "$TSCSV"
echo

echo "--- WiFi extenders and the phone's path ---"
echo "    Doc's iPhone sits behind extender A. If it is bad here,"
echo "    the fault is the WiFi path, not Tailscale. Its LAN address"
echo "    is resolved from tailscale status each run, not hardcoded"
echo "    (DHCP moved it .169 -> .166 on 2026-08-26)."
awk -F, -v since="$SINCE" '
    substr($1,1,10) >= since && $2=="wifi" {
        # away = phone is off the home LAN (cellular/clinic). That is
        # not a fault and must not be averaged in as 0 ms, which is
        # what made the old hardcoded-.169 rows so misleading.
        if ($4 == "away" || $4 == "unknown") { aw[$3]++; atag[$3]=$6; next }
        split($7, d, ";"); sub("mdev=", "", d[2]); sub("max=", "", d[1])
        n[$3]++; tag[$3]=$6; sa[$3]+=$5; sm[$3]+=d[2]
        if (d[1]+0 > mx[$3]) mx[$3]=d[1]+0
    }
    END {
        if (!length(n) && !length(aw)) { print "    no samples yet"; exit }
        printf "    %-16s %-20s %8s %8s %9s\n", "ip","role","avg","jitter","worst"
        for (b in n)
            printf "    %-16s %-20s %7.1fms %7.1fms %8.0fms\n", \
                   b, tag[b], sa[b]/n[b], sm[b]/n[b], mx[b]
        for (b in aw)
            printf "    %-16s %-20s %8s  (off home LAN, %d samples)\n", \
                   b, atag[b], "away", aw[b]
    }
' "$TSCSV"
echo
echo "    Multicast on eno1 (IPTV flood check, want single digits):"
awk -F, -v since="$SINCE" '
    substr($1,1,10) >= since && $2=="mcast" {
        split($7, d, ";"); sub("pkts_per_s=", "", d[1])
        n++; s+=d[1]; if (d[1]+0 > m) m=d[1]+0
    }
    END {
        if (!n) { print "      no samples yet"; exit }
        printf "      avg %.1f pkt/s, peak %d pkt/s over %d samples\n", s/n, m, n
        if (m > 200) print "      ^ HIGH - IPTV multicast is flooding the wired LAN"
    }
' "$TSCSV"
echo

echo "--- VERDICT: does a dedicated router help? ---"
echo "    Compares ICMP vs TCP to the router during degraded windows."
awk -F, -v since="$SINCE" '
    substr($1,1,10) < since { next }
    $2=="lan" && $3=="router"     { icmp[$1]=$5 }
    $2=="tcp" && $3=="router_tcp" { rtcp[$1]=($4=="ok" ? $5 : 9999) }
    $2=="tcp" && $3=="wan_tcp"    { wtcp[$1]=($4=="ok" ? $5 : 9999) }
    $2=="tcp" && $3=="nas_tcp"    { ntcp[$1]=($4=="ok" ? $5 : 9999) }
    END {
        for (t in icmp) {
            if (icmp[t]+0 <= 100) continue          # only degraded moments
            if (!(t in rtcp)) continue
            n++
            if (rtcp[t]+0 > 100) cpu++              # router CPU really is busy
            else                 upstream++         # ICMP merely deprioritised
            si+=icmp[t]; sr+=rtcp[t]; sw+=wtcp[t]; sn+=ntcp[t]
        }
        if (!n) {
            print "    No degraded samples with TCP data yet."
            print "    (The TCP probes were added 2026-08-16 - wait for the"
            print "     next evening window, then re-run this report.)"
            exit
        }
        printf "    Degraded samples analysed: %d\n", n
        printf "      avg router ICMP : %8.0f ms\n", si/n
        printf "      avg router TCP  : %8.0f ms   <- the discriminator\n", sr/n
        printf "      avg WAN TCP     : %8.0f ms\n", sw/n
        printf "      avg NAS TCP     : %8.0f ms   (control, bypasses router)\n", sn/n
        printf "\n"
        printf "      router CPU saturated : %d samples\n", cpu
        printf "      ICMP-only / upstream : %d samples\n", upstream
        printf "\n"
        if (cpu > upstream)
            print  "    => Router CPU is genuinely saturated. A dedicated\n       router behind the Giga Hub (Advanced DMZ) SHOULD help."
        else
            print  "    => Router CPU responds fine; the loss is upstream.\n       A dedicated router would NOT fix this. Talk to Bell."
    }
' "$TSCSV"
echo

echo "--- Captured forensic snapshots (router in bad state) ---"
if compgen -G "$HOME/logs/tsmon-events/*.txt" >/dev/null; then
    ls -1t "$HOME/logs/tsmon-events"/*.txt | head -10 | sed 's/^/    /'
else
    echo "    none yet"
fi
