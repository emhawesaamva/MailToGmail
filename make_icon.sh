#!/bin/bash
# Renders MailToGmail.icns from MakeIcon.swift.
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

swiftc -O MakeIcon.swift -o "$WORK/makeicon"
mkdir -p "$WORK/png" "$WORK/MailToGmail.iconset"
"$WORK/makeicon" "$WORK/png"

cd "$WORK"
cp png/16.png   MailToGmail.iconset/icon_16x16.png
cp png/32.png   MailToGmail.iconset/icon_16x16@2x.png
cp png/32.png   MailToGmail.iconset/icon_32x32.png
cp png/64.png   MailToGmail.iconset/icon_32x32@2x.png
cp png/128.png  MailToGmail.iconset/icon_128x128.png
cp png/256.png  MailToGmail.iconset/icon_128x128@2x.png
cp png/256.png  MailToGmail.iconset/icon_256x256.png
cp png/512.png  MailToGmail.iconset/icon_256x256@2x.png
cp png/512.png  MailToGmail.iconset/icon_512x512.png
cp png/1024.png MailToGmail.iconset/icon_512x512@2x.png

iconutil -c icns MailToGmail.iconset -o MailToGmail.icns
cd - >/dev/null
mv "$WORK/MailToGmail.icns" ./MailToGmail.icns
echo "Built $(pwd)/MailToGmail.icns"
