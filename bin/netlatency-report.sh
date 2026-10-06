#!/bin/bash
# Summarise ~/logs/netlatency.csv by hour of day, so a
# recurring daily degradation window stands out.
#
# Usage: netlatency-report.sh [csv]

CSV="${1:-$HOME/logs/netlatency.csv}"

if [ ! -f "$CSV" ]; then
    echo "No data yet: $CSV"
    exit 1
fi

n=$(( $(wc -l < "$CSV") - 1 ))
echo "Source : $CSV"
echo "Samples: $n"
echo
echo "nas_lan is the control - it bypasses the router."
echo "If it stays fast while the others spike, the"
echo "router is the problem."
echo

for probe in router internet nas_lan dns; do
    echo "=== $probe : average by hour of day ==="
    awk -F, -v P="$probe" '
      NR>1 && $2==P {
          h = substr($1,12,2)
          if ($4 != "") { sum[h]+=$4; n[h]++ }
          loss[h]+=$5; ln[h]++
      }
      END {
          any = 0
          for (i=0; i<24; i++) {
              h = sprintf("%02d", i)
              if (!ln[h]) continue
              any = 1
              avg = n[h] ? sum[h]/n[h] : 0
              b = int(avg/50); if (b > 40) b = 40
              bar = ""
              for (j=0; j<b; j++) bar = bar "#"
              printf "  %s:00  %8.1f ms  loss %5.1f%%  %s\n", \
                     h, avg, loss[h]/ln[h], bar
          }
          if (!any) print "  (no samples yet)"
      }' "$CSV"
    echo
done

echo "=== worst 10 samples (router) ==="
awk -F, 'NR>1 && $2=="router" && $4!=""' "$CSV" \
  | sort -t, -k4 -gr | head -10 \
  | awk -F, '{printf "  %s  %8.1f ms  loss %s%%\n", \
              $1, $4, $5}'

echo
echo "=== MECHANISM: what differs when it fails? ==="
echo "Compares router samples that were BAD (>50ms or"
echo ">5% loss) against GOOD ones."
echo
echo "  wan_pps is the WHOLE household's WAN packet rate,"
echo "  read from the modem itself - the only view that"
echo "  includes other devices. ubuntu-s1's own rx/tx is"
echo "  the control: it was ANTI-correlated with failure."
echo
echo "  wan_pps much higher when BAD  -> the modem is being"
echo "    loaded by other devices (many flows = NAT/CPU"
echo "    pressure). Note bytes cannot be read: the modem's"
echo "    byte counters are stuck at 2^32-1."
echo "  wan_pps FLAT when BAD         -> not load at all;"
echo "    points at the modem itself (thermal, firmware,"
echo "    or an upstream fault)."
echo
awk -F, '
  NR>1 && $2=="router" && $4!="" && $8!="" {
      bad = ($4 > 50 || $5 > 5)
      w = ($12 != "")
      if (bad) { bc++; bct+=$8; brx+=$9; btx+=$10
                 if (w) { bwn++; bwtx+=$12; bwrx+=$13 } }
      else     { gc++; gct+=$8; grx+=$9; gtx+=$10
                 if (w) { gwn++; gwtx+=$12; gwrx+=$13 } }
  }
  END {
      if (bc == 0) {
          print "  No bad samples with these columns yet."
          print "  (conntrack added 2026-08-19, wan_pps"
          print "   2026-08-20; need one degraded evening)"
          exit
      }
      printf "  %-8s %6s %9s %9s %8s %9s %9s\n", \
             "state","n","conntrack","rx kB/s","tx kB/s", \
             "wan tx/s","wan rx/s"
      printf "  %-8s %6d %9.0f %9.1f %8.1f %9s %9s\n", \
             "BAD", bc, bct/bc, brx/bc, btx/bc, \
             (bwn ? sprintf("%.0f", bwtx/bwn) : "-"), \
             (bwn ? sprintf("%.0f", bwrx/bwn) : "-")
      printf "  %-8s %6d %9.0f %9.1f %8.1f %9s %9s\n", \
             "good", gc, gct/gc, grx/gc, gtx/gc, \
             (gwn ? sprintf("%.0f", gwtx/gwn) : "-"), \
             (gwn ? sprintf("%.0f", gwrx/gwn) : "-")
      print ""
      if (gct/gc > 0)
          printf "  conntrack ratio bad/good: %.2fx\n", \
                 (bct/bc)/(gct/gc)
      if (bwn && gwn && gwtx/gwn > 0)
          printf "  wan pkt/s ratio bad/good: %.2fx  <-- the one that matters\n", \
                 (bwtx/bwn)/(gwtx/gwn)
      else
          printf "  wan pkt/s: not yet sampled during a bad window\n"
  }' "$CSV"

echo
echo "=== EVENTS ==="
grep ',EVENT,' "$CSV" 2>/dev/null | awk -F, \
  '{printf "  %s  %s\n", $1, $3}' | tail -20 \
  || echo "  (none)"
