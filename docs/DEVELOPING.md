# Developing Levers

How to add a lever, try it safely, and ship it. For how the existing switches work, see [HOW-IT-WORKS.md](HOW-IT-WORKS.md).

## The loop

1. **Write the lever.** Add `Sources/Levers/Switches/YourSwitch.swift` conforming to the `Switch` protocol (`Sources/Levers/Switch.swift`):
   - `id`, `name`, `onIcon`, `offIcon` (SF Symbol names).
   - `isOn`: **ask the system every time**. Never store a guess, so the panel stays true if the setting changes elsewhere.
   - `set(on:)`: make the change; throw a `SwitchError` (optionally with a `settings` link) if the system refuses.
   - `stopsWhenHidden = true` if it keeps something running (an assertion, an event tap).
   - `detail` for an optional second line under the name.
2. **Register it.** Add one line to the `all` list in `SwitchBoard` (`Sources/Levers/LeversApp.swift`). Saved layouts keep their order; new levers appear at the end.
3. **Build the dev app.** `./scripts/bundle.sh` → `build/Levers Dev.app`. It has its own bundle ID (`io.github.jptramos.levers.dev`), so its permissions, settings and login item are separate from your installed Levers. Its panel title says "Levers Dev". Rebuild as often as you like.
4. **Try it.** `open "build/Levers Dev.app"`, flip the new lever, or use the test hooks in HOW-IT-WORKS.md (`--status`, `--on <id>`). Grant any permission it needs to *Levers Dev*. Quit it from its panel when done.
5. **Release.** Commit, then `./scripts/release.sh minor` for a new lever (`patch` for fixes, `major` for big changes). It bumps `VERSION`, commits, tags `vX.Y.Z`, and installs the real app with `install.sh`.

## Rules of thumb

- **Don't test on the installed copy.** Rebuilding or replacing `~/Applications/Levers.app` mid-work can cost its keyboard permission. That's what the dev app is for.
- **Permissions after an install.** Without a signing certificate, every build is a new app to macOS for keyboard access. `install.sh` says when it's needed. Toggling the old entry in Settings does **not** work. Remove it with **−**, or run `tccutil reset Accessibility io.github.jptramos.levers` (clears only Levers' entry), then allow the fresh prompt. A local "Levers Local Signing" code-signing certificate makes permissions survive rebuilds (see `scripts/bundle.sh`).
- **Check permissions through LaunchServices.** `open -n -W --stdout out.txt ~/Applications/Levers.app --args --status`. Running the binary from a shell reports the *shell's* permissions.
- **Measure, don't guess.** Memory with `footprint <pid>`, one action per test. Idle should stay near 0% CPU.
- **Ask before changing system settings while testing.** Levers flips real settings on your Mac (appearance, Finder, sleep).
