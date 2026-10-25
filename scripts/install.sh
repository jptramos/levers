#!/bin/zsh
# Build the release app and install it to ~/Applications, replacing the old
# copy and relaunching it. Your settings (layout, flip count, timer) live in
# ~/Library/Preferences and are kept. Then it checks Levers' permissions.
set -euo pipefail
cd "${0:A:h}/.."

./scripts/bundle.sh release

DEST="$HOME/Applications/Levers.app"
mkdir -p "$HOME/Applications"
# Quit the running installed copy: only processes named exactly "Levers"
# whose executable is this app (not Levers Dev, not anything else).
# Quitting ends Keep Awake and Lock Keyboard if they're on.
for pid in $(pgrep -x Levers || true); do
  [[ "$(ps -o comm= -p "$pid")" == "$DEST/Contents/MacOS/Levers" ]] && kill "$pid" && sleep 1
done
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
  # Without a signing certificate each build is a new app to macOS, and the
  # old Levers row in Settings stays "on" but no longer applies. Toggling it
  # doesn't help; clearing it does. This removes only Levers' own entry.
  tccutil reset Accessibility io.github.jptramos.levers >/dev/null
  pkill -x -f "$DEST/Contents/MacOS/Levers" 2>/dev/null; sleep 1
  open "$DEST"
  echo "Keyboard access: cleared the old entry (it belonged to the previous build)."
  echo "  Flip Lock Keyboard once and allow Levers in the prompt that appears."
fi
