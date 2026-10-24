import ServiceManagement

/// Launch at Login, via SMAppService (macOS 13+).
///
/// `SMAppService.mainApp` is "this app itself as a login item". Registering
/// it adds Levers to System Settings › General › Login Items; macOS then
/// opens it at login. No helper app or LaunchAgent plist is needed.
///
/// Same rule as the switches: the state is never stored here. `status`
/// asks the system each time, so if the user removes Levers in System
/// Settings the checkbox shows it.
@MainActor
enum LoginItem {
    private static var service: SMAppService { .mainApp }

    /// On when registered. `.requiresApproval` means registered but the user
    /// switched it off in System Settings, so it won't launch.
    static var isOn: Bool { service.status == .enabled }
    static var needsApproval: Bool { service.status == .requiresApproval }

    static func set(on: Bool) throws {
        // register() on an already-registered app (or unregister() on one that
        // isn't) throws; skip the no-op so the toggle never shows that error.
        if on == isOn { return }
        if on { try service.register() } else { try service.unregister() }
    }

    /// Opens System Settings › Login Items so the user can approve.
    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    static var statusText: String {
        switch service.status {
        case .enabled: "on"
        case .requiresApproval: "requires-approval"
        case .notRegistered: "off"
        case .notFound: "not-found"
        @unknown default: "unknown"
        }
    }
}
