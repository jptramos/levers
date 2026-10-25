#!/bin/zsh
# Cut a release: bump VERSION, commit, tag, then install it.
#
#   ./scripts/release.sh          → 1.1.0 → 1.1.1  (patch: fixes)
#   ./scripts/release.sh minor    → 1.1.0 → 1.2.0  (new features)
#   ./scripts/release.sh major    → 1.1.0 → 2.0.0
#
# Commits and tags locally only. Publishing is a separate, deliberate step.
set -euo pipefail
cd "${0:A:h}/.."

# Only release committed work, so the tag means exactly what's in it.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Uncommitted changes. Commit or stash them first." >&2; exit 1
fi

[[ "$(<VERSION)" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "VERSION must look like 1.2.3" >&2; exit 1; }
IFS=. read -r MAJ MIN PAT < VERSION
case "${1:-patch}" in
  patch) PAT=$((PAT + 1)) ;;
  minor) MIN=$((MIN + 1)); PAT=0 ;;
  major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
  *) echo "usage: $0 [patch|minor|major]" >&2; exit 2 ;;
esac
NEW="$MAJ.$MIN.$PAT"
echo "$NEW" > VERSION
git add VERSION
git commit -q -m "Release v$NEW"
git tag "v$NEW"
echo "Tagged v$NEW"

./scripts/install.sh
