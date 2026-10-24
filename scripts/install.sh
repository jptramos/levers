#!/bin/zsh
# Build the release app and install it to ~/Applications, replacing the old
# copy and relaunching it. Your settings (layout, flip count, timer) live in
# ~/Library/Preferences and are kept. Then it checks Levers' permissions.
set -euo pipefail
cd "${0:A:h}/.."

./scripts/bundle.sh release

DEST="$HOME/Applications/Levers.app"
mkdir -p "$HOME/Applications"
# Quit the running release copy (the "/Levers.app/" path never matches
# "Levers Dev.app"). Quitting ends Keep Awake and Lock Keyboard if they're on.
pkill -f "/Levers.app/Contents/MacOS/Levers" 2>/dev/null && sleep 1 || true
rm -rf "$DEST"
cp -R build/Levers.app "$DEST"
open "$DEST"
echo "Installed $DEST ($(<VERSION))"

# Permission check. TCC answers for the app that launched a process, so ask
# through LaunchServices (`open`), not by running the binary from this shell.
OUT="$(mktemp)"
open -n -W --stdout "$OUT" "$DEST" --args --status
ACCESS="$(grep '^accessibility=' "$OUT" | cut -d= -f2)"
rm -f "$OUT"
if [[ "$ACCESS" == "granted" ]]; then
  echo "Keyboard access: granted"
else
  echo "Keyboard access: NOT granted. Flip Lock Keyboard once and allow Levers."
  echo "  If Levers is already listed but on, remove it with − first (it belongs to an older build)."
fi
