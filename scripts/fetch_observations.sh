#!/bin/bash
# Télécharge les observations marégraphiques REFMAR (data.shom.fr) pour une station.
# Données sous Licence Ouverte 2.0 (Etalab) — attribution : Shom / REFMAR.
# Source 4 = données validées (pas horaire). Source 1 = brut temps réel (pas 10 min),
# utilisé en secours quand la validation n'est pas encore publiée.
#
# Usage: fetch_observations.sh <station_id> <YYYY-MM debut> <YYYY-MM fin> <dossier_sortie>
set -euo pipefail

STATION="${1:?station id}"
START="${2:?YYYY-MM}"
END="${3:?YYYY-MM}"
OUT="${4:?output dir}"
BASE="https://services.data.shom.fr/maregraphie/observation/json"

mkdir -p "$OUT"

cur="$START-01"
end_excl=$(date -j -v+1m -f "%Y-%m-%d" "$END-01" "+%Y-%m-%d")

while [ "$cur" != "$end_excl" ]; do
  nxt=$(date -j -v+1m -f "%Y-%m-%d" "$cur" "+%Y-%m-%d")
  ym="${cur%-01}"
  for src in 4 1; do
    f="$OUT/${ym}_src${src}.json"
    [ -s "$f" ] && { echo "skip $ym (déjà présent src$src)"; break; }
    url="$BASE/$STATION?dtStart=${cur}T00:00:00Z&dtEnd=${nxt}T00:00:00Z&interval=10&sources=$src"
    curl -s --max-time 60 "$url" -o "$f.tmp"
    n=$(python3 -c "import json;print(len(json.load(open('$f.tmp')).get('data',[])))" 2>/dev/null || echo 0)
    if [ "$n" -gt 100 ]; then
      mv "$f.tmp" "$f"
      echo "$ym src$src: $n points"
      break
    else
      rm -f "$f.tmp"
      echo "$ym src$src: vide, essai source suivante"
    fi
  done
  sleep 1
  cur="$nxt"
done
echo "terminé."
