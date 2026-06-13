#!/usr/bin/env bash
# ram_diag.sh — Sample device-wide + app memory for the QuickBytes POS terminal.
#
# Designed for low-RAM Sunmi terminals (e.g. VS2, 878 MB total). Writes a CSV
# you can graph and a periodic human-readable snapshot to stderr.
#
# Usage:
#   tools/ram_diag.sh [-s SERIAL] [-p PACKAGE] [-i INTERVAL_SEC] [-n SAMPLES] [-o OUTFILE]
#
# Defaults: first adb device, package com.terabyteai.foodmania.posadmin,
#           5s interval, run until Ctrl-C, out=ram_diag_<ts>.csv
set -uo pipefail

SERIAL=""
PKG="com.terabyteai.foodmania.posadmin"
INTERVAL=5
SAMPLES=0            # 0 = infinite
OUT=""

while getopts "s:p:i:n:o:h" opt; do
  case "$opt" in
    s) SERIAL="$OPTARG" ;;
    p) PKG="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    n) SAMPLES="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    h) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bad option" >&2; exit 1 ;;
  esac
done

ADB="adb"
[ -n "$SERIAL" ] && ADB="adb -s $SERIAL"
[ -z "$OUT" ] && OUT="ram_diag_$(date +%Y%m%d-%H%M%S).csv"

# meminfo field grabber (returns kB integer)
mi() { echo "$1" | awk -v k="$2" '$1==k":"{print $2}'; }

echo "ts,uptime_s,mem_total_kb,mem_free_kb,mem_avail_kb,swap_total_kb,swap_free_kb,swap_used_kb,app_pid,app_pss_kb,app_rss_kb,app_swap_pss_kb,java_heap_kb,native_heap_kb,code_kb,graphics_kb" > "$OUT"
echo "Logging to $OUT (interval ${INTERVAL}s, samples=${SAMPLES:-inf}). Ctrl-C to stop." >&2

i=0
while :; do
  i=$((i+1))
  TS=$(date +%H:%M:%S)
  MEM=$($ADB shell cat /proc/meminfo 2>/dev/null)
  UP=$($ADB shell cat /proc/uptime 2>/dev/null | awk '{print int($1)}')
  MT=$(mi "$MEM" MemTotal);  MF=$(mi "$MEM" MemFree);  MA=$(mi "$MEM" MemAvailable)
  ST=$(mi "$MEM" SwapTotal); SF=$(mi "$MEM" SwapFree)
  SU=$(( ${ST:-0} - ${SF:-0} ))

  PID=$($ADB shell pidof "$PKG" 2>/dev/null | tr -d '\r' | awk '{print $1}')
  PSS=""; RSS=""; SWP=""; JH=""; NH=""; CODE=""; GFX=""
  if [ -n "$PID" ]; then
    DM=$($ADB shell dumpsys meminfo "$PKG" 2>/dev/null | tr -d '\r')
    PSS=$(echo "$DM"  | awk '/TOTAL PSS/{for(i=1;i<=NF;i++) if($i=="PSS:"){print $(i+1); exit}}')
    # App Summary lines
    JH=$(echo "$DM"   | awk '/Java Heap:/{print $3}'    | head -1)
    NH=$(echo "$DM"   | awk '/Native Heap:/{print $3}'  | head -1)
    CODE=$(echo "$DM" | awk '/^[[:space:]]*Code:/{print $2}' | head -1)
    GFX=$(echo "$DM"  | awk '/Graphics:/{print $2}'     | head -1)
    RSS=$(echo "$DM"  | awk '/TOTAL RSS/{print $6}'     | head -1)
    SWP=$(echo "$DM"  | awk '/TOTAL SWAP/{print $NF}'   | head -1)
  fi

  echo "$TS,${UP:-},${MT:-},${MF:-},${MA:-},${ST:-},${SF:-},${SU},${PID:-},${PSS:-},${RSS:-},${SWP:-},${JH:-},${NH:-},${CODE:-},${GFX:-}" >> "$OUT"
  printf '[%s] free=%sMB avail=%sMB swapUsed=%sMB | app(%s) pss=%sMB rss=%sMB java=%sMB native=%sMB gfx=%sMB code=%sMB\n' \
    "$TS" "$(( ${MF:-0}/1024 ))" "$(( ${MA:-0}/1024 ))" "$(( SU/1024 ))" \
    "${PID:-down}" "$(( ${PSS:-0}/1024 ))" "$(( ${RSS:-0}/1024 ))" \
    "$(( ${JH:-0}/1024 ))" "$(( ${NH:-0}/1024 ))" "$(( ${GFX:-0}/1024 ))" "$(( ${CODE:-0}/1024 ))" >&2

  [ "$SAMPLES" -ne 0 ] && [ "$i" -ge "$SAMPLES" ] && break
  sleep "$INTERVAL"
done
