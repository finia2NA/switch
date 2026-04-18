#!/usr/bin/env bash
# Render icon-1024.png into every asset-catalog size required by macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/tools/icon-1024.png"
DST="$ROOT/Sources/Switch/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$DST"
for sz in 16 32 64 128 256 512 1024; do
    sips -z "$sz" "$sz" "$SRC" --out "$DST/icon_${sz}x${sz}.png" >/dev/null
done
# 2x variants for 16,32,128,256,512
for sz in 16 32 128 256 512; do
    twox=$((sz * 2))
    sips -z "$twox" "$twox" "$SRC" --out "$DST/icon_${sz}x${sz}@2x.png" >/dev/null
done
echo "wrote icons to $DST"
