#!/usr/bin/env bash
# Build release zips: CasualMinMaxer-<version>.zip containing both addon folders.
# Usage: scripts/package.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:-$(git describe --tags --always 2>/dev/null || echo dev)}
OUT=dist
rm -rf "$OUT/stage" && mkdir -p "$OUT/stage"
cp -r CasualMinMaxer CasualMinMaxer_Data "$OUT/stage/"
# stamp the version the way the CurseForge packager would
sed -i "s/@project-version@/$VERSION/" "$OUT/stage/CasualMinMaxer/CasualMinMaxer.toc" "$OUT/stage/CasualMinMaxer_Data/CasualMinMaxer_Data.toc" 2>/dev/null || true
find "$OUT/stage" -name "*.orig" -o -name "*.rej" -o -name ".DS_Store" | xargs -r rm -f
( cd "$OUT/stage" && zip -qr "../CasualMinMaxer-$VERSION.zip" CasualMinMaxer CasualMinMaxer_Data )
rm -rf "$OUT/stage"
ls -la "$OUT/CasualMinMaxer-$VERSION.zip"
