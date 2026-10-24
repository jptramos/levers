import Foundation

/// Hides desktop icons by flipping Finder's `CreateDesktop` preference.
///
/// Finder draws the desktop only if `com.apple.finder` → `CreateDesktop`
/// is true (or missing, the default). Finder reads that key at launch,
/// so after writing it we restart Finder.
///
/// Writing goes through `/usr/bin/defaults` rather than CFPreferences:
/// both talk to `cfprefsd` (the daemon that owns every app's preference
/// files), but `defaults` is the exact command a user would type, so the
/// undo is obvious: `defaults delete com.apple.finder CreateDesktop; killall Finder`.
@MainActor
final class HideDesktopIconsSwitch: Switch {
    let id = "hide-desktop-icons"
    let name = "Hide Desktop Icons"
    let onIcon = "eye.slash.fill"
    let offIcon = "eye"

    private let domain = "com.apple.finder" as CFString
    private let key = "CreateDesktop" as CFString

    /// "On" means icons are hidden, i.e. CreateDesktop is explicitly false.
    var isOn: Bool {
        // Ask cfprefsd for a fresh copy of Finder's prefs before reading.
        CFPreferencesAppSynchronize(domain)
        guard let value = CFPreferencesCopyAppValue(key, domain) else { return false }
        // The value may be stored as a Bool, a number, or the string "false".
        if let b = value as? Bool { return !b }
        if let s = value as? String { return ["false", "no", "0"].contains(s.lowercased()) }
        return false
    }

    func set(on: Bool) throws {
        if on {
            try run("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", "false"])
        } else {
            // Deleting restores the default (icons shown) instead of writing `true`.
            try? run("/usr/bin/defaults", ["delete", "com.apple.finder", "CreateDesktop"])
        }
        // Finder relaunches itself automatically (launchd keeps it alive).
        try run("/usr/bin/killall", ["Finder"])
    }

    private func run(_ path: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw SwitchError(message: "\(path) \(args.joined(separator: " ")) exited \(p.terminationStatus)")
        }
    }
}
