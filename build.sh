#!/bin/bash
# Builds MailToGmail.app from MailToGmail.swift. Requires Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")"

APP="MailToGmail.app"

[ -f MailToGmail.icns ] || ./make_icon.sh

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O MailToGmail.swift -o "$APP/Contents/MacOS/MailToGmail"
cp MailToGmail.icns "$APP/Contents/Resources/MailToGmail.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>MailToGmail</string>
    <key>CFBundleDisplayName</key>     <string>MailToGmail</string>
    <key>CFBundleExecutable</key>      <string>MailToGmail</string>
    <key>CFBundleIdentifier</key>      <string>local.em.mailtogmail</string>
    <key>CFBundleIconFile</key>        <string>MailToGmail</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>11.0</string>
    <key>LSUIElement</key>             <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>local.em.mailtogmail.mailto</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mailto</string>
            </array>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

xattr -cr "$APP"

# This app requests no privacy-scoped OS permission (unlike Caffeine, which
# needs a stable identity so its Accessibility grant survives rebuilds), so an
# ad-hoc signature's changing cdhash between builds costs nothing here — the
# named-identity path below is a purely cosmetic/consistency nicety.
IDENTITY="MailToGmail Local Signing"
if security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "warning: '$IDENTITY' not in keychain - falling back to ad-hoc." >&2
    codesign --force --sign - "$APP"
fi
echo "Built $(pwd)/$APP"
