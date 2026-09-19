#!/usr/bin/env bash
# Re-download the client DB2 tables the pipeline needs for random enchants and socket bonuses.
# Source: wago.tools CSV export of the live TBC Classic (Anniversary) client build.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD=${1:-2.5.6.69795}
for t in ItemRandomSuffix ItemRandomProperties SpellItemEnchantment RandPropPoints; do
  curl -fsSL -o "pipeline/dbc/$t.csv" "https://wago.tools/db2/$t/csv?build=$BUILD"
  echo "$t: $(($(wc -l < "pipeline/dbc/$t.csv") - 1)) rows"
done
sed -i "s/^Build: .*/Build: $BUILD/" pipeline/dbc/README.md
