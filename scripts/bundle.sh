#!/bin/zsh
# Build Levers and wrap the binary into Levers.app.
#
# Without Xcode there is no app target, so we assemble the bundle by hand.
# A .app is just a folder layout macOS recognizes:
#   Levers.app/Contents/Info.plist      ← metadata (LSUIElement hides the Dock icon)
#   Levers.app/Contents/MacOS/Levers  ← the executable
set -euo pipefail
cd "${0:A:h}/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Levers"

APP="build/Levers.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Levers"

# App icon: drawn by scripts/make-icon.swift. Regenerate only if missing,
# so normal builds don't pay for it (delete the .icns to redraw).
[[ -f Resources/AppIcon.icns ]] || swift scripts/make-icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>io.github.jptramos.levers</string>
    <key>CFBundleName</key>              <string>Levers</string>
    <key>CFBundleExecutable</key>        <string>Levers</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>26.0</string>
    <!-- Menubar-only: no Dock icon, no app menu. -->
    <key>LSUIElement</key>               <true/>
    <!-- Shown in the Automation prompt when Dark Mode first talks to System Events. -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Levers asks System Events to switch Dark Mode on and off.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature ("-"): no developer account needed. macOS privacy (TCC)
# keys permissions to the signature, so a rebuild may re-prompt Automation.
codesign --force --sign - "$APP"
echo "Built $APP"
