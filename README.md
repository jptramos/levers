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
2. Build Levers, install it to your Applications folder and open it:

```bash
git clone https://github.com/jptramos/levers.git
cd levers
./scripts/install.sh
```

To update later, `git pull` and run `./scripts/install.sh` again. Your layout and settings are kept.

Levers appears in the menubar as three little sliders. It has no Dock icon.

## Permissions

Levers asks only when you first use a switch that needs it:

- **Dark Mode** asks to control *System Events*. That's how apps are allowed to change system settings.
- **Lock Keyboard** asks for access to your keyboard (System Settings → Privacy & Security → Accessibility; on macOS 27 it's called *Device Control and Data Access*).

If you say no by accident, the panel shows an **Open Settings…** link to fix it.

**After an update, keyboard access may need re-granting.** Without a signing certificate, macOS treats each build as a new app, and the old Levers entry in that list stops working even though it still shows as on. `install.sh` tells you when this happens. Remove the old entry with **−** (or run `tccutil reset Accessibility io.github.jptramos.levers`, which clears only Levers' entry), then flip Lock Keyboard and allow it again. To avoid this for good, create a free signing certificate named "Levers Local Signing" in Keychain Access (Certificate Assistant → Create a Certificate → type *Code Signing*). The scripts use it automatically.

## Turning things back

- **Keep Awake**: switch it off, or quit Levers.
- **Dark Mode**: switch it off, or use System Settings → Appearance.
- **Hide Desktop Icons**: switch it off. If Levers is gone, run `defaults delete com.apple.finder CreateDesktop; killall Finder`.
- **Lock Keyboard**: click the switch off, or quit Levers.
- **Launch at Login**: untick it, or remove Levers under System Settings → General → Login Items.

## How it works

Curious what each switch actually calls, or how a Mac app gets built without Xcode? See **[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)**. Want to add a lever? See **[docs/DEVELOPING.md](docs/DEVELOPING.md)**.

## License

MIT. See [LICENSE](LICENSE).
