#!/bin/zsh
# Build Levers and wrap the binary into an .app.
#
#   ./scripts/bundle.sh          → build/Levers Dev.app  (dev build, the default)
#   ./scripts/bundle.sh release  → build/Levers.app      (what install.sh installs)
#
# Dev and release are two different apps to macOS: different bundle IDs, so
# separate permissions, settings and login items. Rebuilding the dev app
# never disturbs the copy you use every day.
#
# Without Xcode there is no app target, so we assemble the bundle by hand.
# A .app is just a folder layout macOS recognizes:
#   Levers.app/Contents/Info.plist      ← metadata (LSUIElement hides the Dock icon)
#   Levers.app/Contents/MacOS/Levers    ← the executable
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-dev}"
case "$MODE" in
  dev)     BUNDLE_ID="io.github.jptramos.levers.dev"; NAME="Levers Dev" ;;
  release) BUNDLE_ID="io.github.jptramos.levers";     NAME="Levers" ;;
  *) echo "usage: $0 [dev|release]" >&2; exit 2 ;;
esac

VERSION="$(<VERSION)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "VERSION must look like 1.2.3, got: $VERSION" >&2; exit 1; }
# Build number: commits so far (always increases); 1 outside a git checkout.
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Levers"

APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Levers"

# App icon: drawn by scripts/make-icon.swift. Regenerate only if missing,
# so normal builds don't pay for it (delete the .icns to redraw).
[[ -f Resources/AppIcon.icns ]] || swift scripts/make-icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>              <string>$NAME</string>
    <key>CFBundleExecutable</key>        <string>Levers</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$BUILD</string>
    <key>LSMinimumSystemVersion</key>    <string>26.0</string>
    <!-- Menubar-only: no Dock icon, no app menu. -->
    <key>LSUIElement</key>               <true/>
    <!-- Shown in the Automation prompt when Dark Mode first talks to System Events. -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Levers asks System Events to switch Dark Mode on and off.</string>
</dict>
</plist>
PLIST

# Signing. macOS ties privacy permissions (Accessibility, Automation) to the
# app's signature. An ad-hoc signature ("-") is a fingerprint of these exact
# bytes, so every rebuild looks like a new app and keyboard access is lost.
# A signing certificate is stable: macOS then matches "bundle ID + certificate",
# and permissions survive rebuilds. Make one free in Keychain Access
# (Certificate Assistant → Create a Certificate → Code Signing), named
# "Levers Local Signing", or point LEVERS_SIGN_ID at your own.
#
# Hardened runtime (--options runtime): macOS refuses to load outside code
# into Levers (DYLD_INSERT_LIBRARIES, unsigned libraries). Without it, any
# program running as you could start Levers with its own code inside and
# borrow Levers' keyboard and Automation permissions. The entitlements file
# re-allows the one thing the runtime would otherwise block: Apple Events.
# Strip extended attributes (quarantine, Finder info) from the bundle first:
# codesign refuses to sign files that carry them ("detritus not allowed").
xattr -cr "$APP"
SIGN_ID="${LEVERS_SIGN_ID:-Levers Local Signing}"
SIGN=(codesign --force --options runtime --entitlements Resources/Levers.entitlements)
if security find-identity -p codesigning 2>/dev/null | grep -qF "\"$SIGN_ID\""; then
  "${SIGN[@]}" --sign "$SIGN_ID" "$APP"
  echo "Built $APP $VERSION ($BUILD), signed with \"$SIGN_ID\""
else
  "${SIGN[@]}" --sign - "$APP"
  echo "Built $APP $VERSION ($BUILD), ad-hoc signed (no \"$SIGN_ID\" certificate found:"
  echo "  keyboard access must be re-granted after each rebuild; see the comment in this script)"
fi

# Fail loudly if the signature didn't take (a half-signed app won't launch right).
codesign --verify --strict "$APP" || { echo "Signature check FAILED for $APP" >&2; exit 1; }
