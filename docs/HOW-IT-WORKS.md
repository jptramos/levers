# How Levers works

The technical side: what each switch calls, how the app is built without Xcode, and what tripped me up. For what Levers does and how to install it, see the [README](../README.md).

## How each switch works

`isOn` always asks the system and never caches, so the panel stays right even if you change a setting somewhere else.

| Switch | Mechanism | Reads state from | Permission |
|---|---|---|---|
| Keep Awake | IOKit `IOPMAssertionCreateWithName` (`PreventUserIdleDisplaySleep`: screen and system stay awake), optional timeout the system enforces (`TimeoutActionRelease`) | `IOPMAssertionCopyProperties` on its own assertion | none |
| Dark Mode | `NSAppleScript` → System Events `appearance preferences` | global pref `AppleInterfaceStyle` | Automation (asked once) |
| Hide Desktop Icons | Finder pref `CreateDesktop` + Finder restart | `CFPreferencesCopyAppValue` on `com.apple.finder` | none |
| Lock Keyboard | an active `CGEvent` tap that swallows key, modifier and media-key events | `CGEvent.tapIsEnabled` on its own tap | Accessibility |

Launch at Login uses `SMAppService.mainApp` (macOS 13+), with no helper app or LaunchAgent.

## Building without Xcode

| Command | Builds | Use |
|---|---|---|
| `./scripts/bundle.sh` | `build/Levers Dev.app` (`io.github.jptramos.levers.dev`) | development: a separate app with its own permissions and settings, so rebuilding never disturbs your installed copy |
| `./scripts/install.sh` | `build/Levers.app` → `~/Applications` | install or update the real app, relaunch it, check permissions |
| `./scripts/release.sh [patch\|minor\|major]` | bumps `VERSION`, commits, tags `vX.Y.Z`, then installs | cutting a version |

Signing: with a "Levers Local Signing" code-signing certificate in your keychain, builds are signed with it, and macOS keeps permissions across rebuilds (it matches bundle ID + certificate). Without it, builds are ad-hoc signed, which ties permissions to each exact build.

With no Xcode project, `bundle.sh` assembles the `.app` by hand: the binary goes in `Contents/MacOS/`, plus an `Info.plist` (`LSUIElement` = no Dock icon) and the app icon. The icon is drawn in code by `scripts/make-icon.swift` and packed into `Resources/AppIcon.icns` with `iconutil`. The menubar glyph is drawn in code as a template image (`Sources/Levers/MenuBarGlyph.swift`).

## Test hooks

```bash
"build/Levers Dev.app/Contents/MacOS/Levers" --status        # print each switch's live state, exit
"build/Levers Dev.app/Contents/MacOS/Levers" --login on      # register the login item, exit (--login off removes it)
open "build/Levers Dev.app" --args --on keep-awake            # flip a switch at launch
open "build/Levers Dev.app" --args --off dark-mode
pmset -g assertions | grep Levers                       # check Keep Awake
```

`open --args` is ignored if the app is already running. Quit it first.

## Gotchas (Command Line Tools + SwiftUI)

- With a macOS 26 target, SwiftUI's `@State` is a Swift macro whose plugin ships only with Xcode. With just the Command Line Tools it fails ("plugin for module 'SwiftUIMacros' not found"). Use `@Published` on an `ObservableObject` instead.
- Drag-to-reorder math must use `.global` coordinates. The row's own frame moves on every swap, so a `.local` translation jumps by a row.
- A protocol-extension default (`stopsWhenHidden`) can only be overridden through `any Switch` if the protocol *declares* the property.
- `kAXTrustedCheckOptionPrompt` is a C mutable global and won't compile under Swift 6 strict concurrency. Use its value, `"AXTrustedCheckOptionPrompt"`.
- No asset catalog without Xcode (`actool`), so the icon is a classic `.icns`. It's drawn on Apple's 824pt grid so macOS 26 doesn't put it inside a gray tile.
