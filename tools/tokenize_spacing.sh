#!/usr/bin/env bash
# tokenize_spacing.sh FILE... — replace bare spacing literals with PosSpacing
# (gaps/padding ≤40) or PosSize (fixed dims >40) tokens. Value-keyed + idempotent.
# Phase-2 forms: SizedBox width/height, EdgeInsets.all(V), single-arg EdgeInsets.only.
# Phase-3 forms: EdgeInsets.symmetric (single- and multi-line), EdgeInsets.fromLTRB
#   (single-line), EdgeInsets.only multi-arg (single-line, line-anchored).
# Residuals left untouched: multi-line fromLTRB / multi-line only — too ambiguous
#   to distinguish from Positioned(left/top/right/bottom) args safely.
# Snaps: 1→s2 · 1.5→s2 · 15→s16.  Literal 0 / EdgeInsets.zero are NOT touched.
set -euo pipefail

map=(
  "1.5:PosSpacing.s2" "1:PosSpacing.s2" "2:PosSpacing.s2" "3:PosSpacing.s3"
  "4:PosSpacing.s4" "5:PosSpacing.s5" "6:PosSpacing.s6" "7:PosSpacing.s7"
  "8:PosSpacing.s8" "9:PosSpacing.s9" "10:PosSpacing.s10" "11:PosSpacing.s11"
  "12:PosSpacing.s12" "13:PosSpacing.s13" "14:PosSpacing.s14" "15:PosSpacing.s16"
  "16:PosSpacing.s16" "18:PosSpacing.s18" "20:PosSpacing.s20" "22:PosSpacing.s22"
  "24:PosSpacing.s24" "26:PosSpacing.s26" "28:PosSpacing.s28" "30:PosSpacing.s30"
  "32:PosSpacing.s32" "40:PosSpacing.s40"
  "44:PosSize.d44" "46:PosSize.d46" "48:PosSize.d48" "52:PosSize.d52"
  "54:PosSize.d54" "56:PosSize.d56" "72:PosSize.d72" "100:PosSize.d100"
  "104:PosSize.d104" "112:PosSize.d112" "240:PosSize.d240" "360:PosSize.d360"
  "380:PosSize.d380"
)

for f in "$@"; do
  for pair in "${map[@]}"; do
    v="${pair%%:*}"; t="${pair#*:}"; ve="${v//./\\.}"

    # ── Phase-2 forms ──────────────────────────────────────────────────────────
    # SizedBox(width:/height: V) — single- and two-arg on one line
    sed -i -E "/SizedBox\(/ s/((width|height):[[:space:]]*)${ve}([^0-9.])/\1${t}\3/g" "$f"
    # EdgeInsets.all(V)
    sed -i -E "s/(EdgeInsets\.all\()${ve}(\))/\1${t}\2/g" "$f"
    # EdgeInsets.only(side: V)  — single arg only
    sed -i -E "s/(EdgeInsets\.only\((left|top|right|bottom):[[:space:]]*)${ve}(\))/\1${t}\3/g" "$f"

    # ── Phase-3: EdgeInsets.symmetric ─────────────────────────────────────────
    # Single-line: symmetric(horizontal: V ...) and symmetric(... vertical: V)
    sed -i -E "s/(EdgeInsets\.symmetric\([^)]*horizontal:[[:space:]]*)${ve}([,\)])/\1${t}\2/g" "$f"
    sed -i -E "s/(EdgeInsets\.symmetric\([^)]*vertical:[[:space:]]*)${ve}([,\)])/\1${t}\2/g" "$f"
    # Multi-line: standalone horizontal:/vertical: lines (exclusively symmetric args
    # in this codebase — confirmed no Positioned conflict for these param names).
    sed -i -E "s/^([[:space:]]*horizontal:[[:space:]]*)${ve}([,]?[[:space:]]*)$/\1${t}\2/" "$f"
    sed -i -E "s/^([[:space:]]*vertical:[[:space:]]*)${ve}([,]?[[:space:]]*)$/\1${t}\2/" "$f"

    # ── Phase-3: EdgeInsets.fromLTRB(N1, N2, N3, N4) — single-line only ───────
    # Four passes, one per positional argument.
    sed -i -E "s/(EdgeInsets\.fromLTRB\()${ve}(,)/\1${t}\2/g" "$f"
    sed -i -E "s/(EdgeInsets\.fromLTRB\([^,]+,[[:space:]]*)${ve}(,)/\1${t}\2/g" "$f"
    sed -i -E "s/(EdgeInsets\.fromLTRB\([^,]+,[^,]+,[[:space:]]*)${ve}(,)/\1${t}\2/g" "$f"
    sed -i -E "s/(EdgeInsets\.fromLTRB\([^,]+,[^,]+,[^,]+,[[:space:]]*)${ve}(\))/\1${t}\2/g" "$f"

    # ── Phase-3: EdgeInsets.only multi-arg — single-line, line-anchored ────────
    # Safe: the /EdgeInsets\.only\(/ guard prevents touching Positioned args
    # (Positioned lines never start with EdgeInsets.only).
    for side in left top right bottom; do
      sed -i -E "/EdgeInsets\.only\(/ s/(\b${side}:[[:space:]]*)${ve}([,\)])/\1${t}\2/g" "$f"
    done
  done
done
