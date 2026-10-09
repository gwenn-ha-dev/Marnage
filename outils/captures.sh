#!/bin/bash
# README captures — CHARTE.md §12. `make shots` delegates here.
#
# Each shot launches the built app on one port, in one language, and captures
# its window with the charter's capturer. Ports and tides are public data:
# nothing here needs to be made up. The day is today's — rerun before a release.
set -euo pipefail
cd "$(dirname "$0")/.."
capturer=${CHARTE:-../../Charte}/outils/capturer.sh
app=build/Marnage.app
[ -d "$app" ] || { echo "captures: build the app first (make package)" >&2; exit 1; }

shot() {  # shot <station slug> <language> <out>
  pkill -x Marnage 2>/dev/null || true
  sleep 1
  open -n "$app" --args -station.slug "$1" -AppleLanguages "($2)" -AppleLocale "${2}_$( [ "$2" = en ] && echo GB || echo FR )"
  sleep 4
  "$capturer" Marnage "$3"
}

for lang in en fr; do
  suffix=$( [ "$lang" = en ] && echo "" || echo ".fr" )
  shot saint-malo "$lang" "docs/img/saint-malo$suffix.png"
  shot brest      "$lang" "docs/img/brest$suffix.png"
  shot le-havre   "$lang" "docs/img/le-havre$suffix.png"
done
pkill -x Marnage 2>/dev/null || true
