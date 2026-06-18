#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="TxtPlus.app"
OUT="build/$APP"
CONTENTS="$OUT/Contents"

rm -rf build
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

swiftc \
  -O \
  Sources/*.swift \
  -o "$CONTENTS/MacOS/TxtPlus" \
  -framework AppKit -framework Foundation

cp Info.plist "$CONTENTS/Info.plist"
if [ -d Resources ]; then
  cp -R Resources/. "$CONTENTS/Resources/"
fi

# Seal the whole bundle (binds Info.plist, seals resources). Ad-hoc, no cert.
# Helps the IMK input-method connection so CJK input attaches.
codesign --force --deep --sign - "$OUT" 2>/dev/null || true

echo "Built $OUT"
echo "Run: open $OUT"
