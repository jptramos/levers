Read `docs/DEVELOPING.md` before changing code: it has the add-a-lever → test → release loop. `docs/HOW-IT-WORKS.md` explains each switch.

- Test in the dev build (`./scripts/bundle.sh` → `build/Levers Dev.app`). Never rebuild or replace the installed `~/Applications/Levers.app` while testing.
- Ship with `./scripts/release.sh`. Commit and tag locally; never push without the owner's explicit OK for that push.
- Ask before running anything that changes system settings or permissions (`tccutil`, `defaults write`, Finder restarts). Say what it changes and how to undo it.
- No Xcode: Command Line Tools only. Use `@Published` on `ObservableObject`, not `@State` (its macro plugin ships only with Xcode).
