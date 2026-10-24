# Levers

**A tiny Mac menubar panel of switches for the things you toggle all day.**

<img src="docs/panel.png" alt="The Levers panel: Keep Awake, Dark Mode, Hide Desktop Icons and Lock Keyboard switches" width="320"> <img src="docs/edit.png" alt="Edit mode: hide switches with the minus buttons, drag the handles to reorder" width="320">

- ☕ **Keep Awake**: keeps your screen on and your Mac awake, until you turn it off or for a set time (15 minutes to 8 hours, using the timer button).
- 🌙 **Dark Mode**: flips light and dark without opening System Settings.
- 👁️ **Hide Desktop Icons**: a clean desktop for screenshots, demos and screen sharing.
- ⌨️ **Lock Keyboard**: ignores every key so you can wipe the keyboard. The mouse still works, so you can always click it off.

Click **Edit** to hide switches you don't use or drag them into your own order. Tick **Launch at Login** to have it always there. The small number at the bottom right counts your flips; right-click it to hide it.

Free and open source (MIT). Needs **macOS 26** or later.

## Install

There's no ready-made download yet, so you build it yourself. It takes about a minute, and you need only Apple's free Command Line Tools, not Xcode.

1. Install the tools once, if you haven't: `xcode-select --install`
2. Build Levers and put it in your Applications folder:

```bash
git clone https://github.com/jptramos/levers.git
cd levers
./scripts/bundle.sh
cp -R build/Levers.app ~/Applications/
open ~/Applications/Levers.app
```

Levers appears in the menubar as three little sliders. It has no Dock icon.

## Permissions

Levers asks only when you first use a switch that needs it:

- **Dark Mode** asks to control *System Events*. That's how apps are allowed to change system settings.
- **Lock Keyboard** asks for access to your keyboard (System Settings → Privacy & Security → Accessibility; on macOS 27 it's called *Device Control and Data Access*).

If you say no by accident, the panel shows an **Open Settings…** link to fix it.

If you rebuild Levers yourself, macOS treats each build as a new app for keyboard access. Switch Levers off and on again in that list.

## Turning things back

- **Keep Awake**: switch it off, or quit Levers.
- **Dark Mode**: switch it off, or use System Settings → Appearance.
- **Hide Desktop Icons**: switch it off. If Levers is gone, run `defaults delete com.apple.finder CreateDesktop; killall Finder`.
- **Lock Keyboard**: click the switch off, or quit Levers.
- **Launch at Login**: untick it, or remove Levers under System Settings → General → Login Items.

## How it works

Curious what each switch actually calls, or how a Mac app gets built without Xcode? See **[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)**.

## License

MIT. See [LICENSE](LICENSE).
