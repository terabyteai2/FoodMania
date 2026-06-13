#!/usr/bin/env bash
# tokenize_fonts.sh FILE...  — replace bare `fontSize: <num>` literals with
# PosFont tokens (design-grounded scale). Value-keyed + idempotent.
# Decimal rules run before integer rules; a trailing non-[0-9.] guard prevents
# 13.5 being mangled by the 13 rule and 120 by the 12 rule.
# Mapping mirrors PosFont in app_theme.dart (drift/typos snap to nearest token).
set -euo pipefail

# value:token  — DECIMALS FIRST, then integers.
map=(
  "9.5:f9_5"  "6.5:f9_5"  "10.5:f10_5" "11.5:f11_5" "11.4:f11_5" "12.5:f12_5"
  "13.5:f13_5" "14.5:f14_5" "15.5:f16" "16.5:f16"
  "9:f9_5" "10:f10" "11:f11" "12:f12" "13:f13" "14:f14" "15:f15" "16:f16"
  "17:f17" "18:f18" "19:f19" "20:f20" "21:f21" "22:f22" "24:f26" "26:f26"
  "27:f28" "28:f28" "30:f30" "34:f34" "36:f34" "40:f40" "44:f40" "48:f48"
  "54:f56" "56:f56" "82:f82"
)

for f in "$@"; do
  for pair in "${map[@]}"; do
    v="${pair%%:*}"; t="${pair#*:}"
    ve="${v//./\\.}"   # escape dot in decimals
    sed -i -E "s/(fontSize:[[:space:]]*)${ve}([^0-9.])/\1PosFont.${t}\2/g" "$f"
  done
done
