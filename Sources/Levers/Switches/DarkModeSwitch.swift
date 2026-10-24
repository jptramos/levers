import AppKit

/// Toggles system Dark Mode by asking System Events over Apple Events.
///
/// There is no public "set dark mode" API. The supported route is
/// AppleScript: System Events exposes `appearance preferences` with a
/// `dark mode` property. Sending an Apple Event to another app needs the
/// user's OK, so macOS shows an Automation prompt the first time
/// (System Settings → Privacy & Security → Automation). If the user says
/// no, the script fails with error -1743 and we surface that.
@MainActor
final class DarkModeSwitch: Switch {
    let id = "dark-mode"
    let name = "Dark Mode"
    let onIcon = "moon.fill"
    let offIcon = "sun.max"

    /// State check without Apple Events: the global preference
    /// `AppleInterfaceStyle` is "Dark" in dark mode and absent in light.
    /// Reading it needs no permission. (In "Auto" mode macOS also keeps
    /// this key current.)
    ///
    /// `UserDefaults.standard` searches this app's domain *and then* the
    /// global domain, so it finds the key. (A `suiteName:` of the global
    /// domain is rejected by Foundation and always reads nil.)
    var isOn: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    func set(on: Bool) throws {
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(on ? "true" : "false")
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            throw SwitchError(message: "Could not build AppleScript")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 {
                throw SwitchError(message: "Levers isn't allowed to control System Events. Turn it on under Automation → Levers.", settings: SettingsPane.automation)
            }
            let msg = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown error"
            throw SwitchError(message: "AppleScript error \(code): \(msg)")
        }
    }
}
