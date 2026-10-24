import Foundation

/// The one shape every switch shares.
///
/// The rule: `isOn` always asks the system. A switch never stores a guess
/// about its own state, so if something else changes the setting (System
/// Settings, Terminal, another app) the menu still shows the truth.
@MainActor
protocol Switch: AnyObject {
    var id: String { get }
    var name: String { get }
    var onIcon: String { get }   // SF Symbol name
    var offIcon: String { get }  // SF Symbol name

    /// Read the real state from the system.
    var isOn: Bool { get }

    /// Declared here (not only in the extension below) so a conforming
    /// class's own value wins when called through `any Switch`.
    var stopsWhenHidden: Bool { get }

    /// Apply the change. Throws if the system refused (e.g. permission denied).
    func set(on: Bool) throws
}

extension Switch {
    /// True for switches that keep something *running* (an assertion, an
    /// event tap). Hiding one of these turns it off first, so nothing runs
    /// invisibly. Settings (Dark Mode, desktop icons) keep their value.
    var stopsWhenHidden: Bool { false }
}

struct SwitchError: LocalizedError {
    let message: String
    /// A System Settings pane that fixes this error, shown as an
    /// "Open Settings…" link under the message.
    var settings: URL? = nil
    var errorDescription: String? { message }
}

/// Deep links into Privacy & Security. Pane *names* change between macOS
/// versions (on macOS 27 the Accessibility permission list is called
/// "Device Control and Data Access"), so error text doesn't name them.
enum SettingsPane {
    static let automation = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
    static let accessibility = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
