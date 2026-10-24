# Levers

A small menubar app for macOS with four switches you flip from one panel:

- **Keep Awake**: keeps the screen on and the Mac awake, either until you turn it off or for 15 minutes to 8 hours (timer button).
- **Dark Mode**: switches the system appearance.
- **Hide Desktop Icons**: clears the desktop for screenshots and screen sharing.
- **Lock Keyboard**: ignores every key so you can wipe the keyboard. The mouse keeps working, so you can always click it off.

Show, hide and reorder switches with **Edit**. Turn on **Launch at Login** in the panel footer. A flip count sits at the bottom right; hover for the per-switch breakdown, right-click to hide or reset, or untick it in Edit.

Requires **macOS 26** or later.

## How each switch works

`isOn` always asks the system and never caches, so the panel stays right even if you change a setting somewhere else.

| Switch | Mechanism | Reads state from | Permission |
|---|---|---|---|
| Keep Awake | IOKit `IOPMAssertionCreateWithName` (`PreventUserIdleDisplaySleep`: screen and system stay awake), optional timeout the system enforces (`TimeoutActionRelease`) | `IOPMAssertionCopyProperties` on its own assertion | none |
| Dark Mode | `NSAppleScript` → System Events `appearance preferences` | global pref `AppleInterfaceStyle` | Automation (asked once) |
| Hide Desktop Icons | Finder pref `CreateDesktop` + Finder restart | `CFPreferencesCopyAppValue` on `com.apple.finder` | none |
| Lock Keyboard | an active `CGEvent` tap that swallows key, modifier and media-key events | `CGEvent.tapIsEnabled` on its own tap | Accessibility |

Launch at Login uses `SMAppService.mainApp` (macOS 13+), with no helper app or LaunchAgent.

## Install (build from source)

There's no signed download yet, so build it yourself. It takes about a minute. You need only the Xcode Command Line Tools (`xcode-select --install`), not Xcode.

```bash
git clone https://github.com/jptramos/levers.git
cd levers
./scripts/bundle.sh          # swift build -c release → build/Levers.app (ad-hoc signed)
cp -R build/Levers.app ~/Applications/
open ~/Applications/Levers.app
```

An app you build yourself isn't quarantined, so Gatekeeper doesn't block it. Copy it to `~/Applications` before turning on Launch at Login, because `bundle.sh` deletes and rebuilds `build/`.

**Permissions** are asked only when you first use the switch that needs them:

- Dark Mode asks to control System Events (Automation).
- Lock Keyboard asks for keyboard access (Privacy & Security → Accessibility; on macOS 27 the list is called *Device Control and Data Access*).

With an ad-hoc signature, macOS ties the Accessibility grant to the exact build, so **after a rebuild, switch Levers off and on again in that list**.

With no Xcode project, `bundle.sh` assembles the `.app` by hand: the binary goes in `Contents/MacOS/`, plus an `Info.plist` (`LSUIElement` = no Dock icon) and the app icon. The icon is drawn in code by `scripts/make-icon.swift` and packed into `Resources/AppIcon.icns` with `iconutil`. The menubar glyph is drawn in code as a template image (`Sources/Levers/MenuBarGlyph.swift`).

## Test hooks

```bash
build/Levers.app/Contents/MacOS/Levers --status        # print each switch's live state, exit
build/Levers.app/Contents/MacOS/Levers --login on      # register the login item, exit (--login off removes it)
open build/Levers.app --args --on keep-awake            # flip a switch at launch
open build/Levers.app --args --off dark-mode
pmset -g assertions | grep Levers                       # check Keep Awake
```

`open --args` is ignored if the app is already running. Quit it first.

## Gotchas (Command Line Tools + SwiftUI)

- With a macOS 26 target, SwiftUI's `@State` is a Swift macro whose plugin ships only with Xcode. With just the Command Line Tools it fails ("plugin for module 'SwiftUIMacros' not found"). Use `@Published` on an `ObservableObject` instead.
- Drag-to-reorder math must use `.global` coordinates. The row's own frame moves on every swap, so a `.local` translation jumps by a row.
- A protocol-extension default (`stopsWhenHidden`) can only be overridden through `any Switch` if the protocol *declares* the property.
- `kAXTrustedCheckOptionPrompt` is a C mutable global and won't compile under Swift 6 strict concurrency. Use its value, `"AXTrustedCheckOptionPrompt"`.
- No asset catalog without Xcode (`actool`), so the icon is a classic `.icns`. It's drawn on Apple's 824pt grid so macOS 26 doesn't put it inside a gray tile.

## Undo

- Keep Awake: turn it off or quit. The system drops the assertion.
- Dark Mode: System Settings → Appearance. Revoke access under Privacy & Security → Automation → Levers.
- Hide Desktop Icons: turn it off, or run `defaults delete com.apple.finder CreateDesktop; killall Finder`.
- Lock Keyboard: click the toggle off, or quit Levers. Remove its grant under Privacy & Security → Accessibility.
- Launch at Login: untick it, or remove Levers in System Settings → General → Login Items.

## License

MIT. See [LICENSE](LICENSE).
