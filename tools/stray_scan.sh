#!/usr/bin/env bash
# stray_scan.sh — design-token "stray" counter for the QuickBytes token migration.
# Counts hardcoded design literals that should be routed through tokens in
# admin_app/lib/src/core/theme/app_theme.dart (PosColors/PosFont/PosSpacing/
# PosSize/PosRadii/PosShadows). Run from repo root. See migration_status_report.txt.
#
# Usage: tools/stray_scan.sh            # scan both apps
#        tools/stray_scan.sh admin_app  # scan one app
#
# Scope guards (excluded — separate token system / physical print px / runtime data):
EX='app_theme\.dart|desktop_pos/|pc_theme\.dart|customer_menu_themes\.dart|menu_image_view\.dart|ticket_bitmap\.dart|report_pdf_service\.dart|qr_pdf_screen\.dart'

scan_app() {
  local app="$1"
  local base="$app/lib/src"
  [ -d "$base" ] || { echo "  (no $base)"; return; }
  c() { grep -rnE "$1" "$base" --include=*.dart 2>/dev/null | grep -vE "$EX" | wc -l | tr -d ' '; }
  echo "###### $app"
  printf "  color   Color(0x…) hex           : %s\n" "$(c 'Color\(0x')"
  printf "  radii   bare circular(<num>)     : %s\n" "$(c 'circular\(\s*[0-9]')"
  printf "  shadow  bare BoxShadow(          : %s\n" "$(c 'BoxShadow\(')"
  printf "  type    fontSize: <num>          : %s\n" "$(c 'fontSize:\s*[0-9]')"
  printf "  space   EdgeInsets w/ <num>       : %s\n" "$(c 'EdgeInsets\.[a-zA-Z]+\([[:space:]]*[0-9]|EdgeInsets\.[a-zA-Z]+\([^)]*[,:][[:space:]]*[0-9]')"
  printf "  space   SizedBox w/h <num>        : %s\n" "$(c 'SizedBox\(\s*(width|height):\s*[0-9]')"
}

apps=("${1:-admin_app terminal_app}")
for a in ${apps[@]}; do scan_app "$a"; done
