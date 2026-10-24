import AppKit
import ApplicationServices

/// Read-only permission checks for `--status`. Neither one shows a prompt.
///
/// TCC (the privacy system) answers for the *responsible* process: the app
/// that launched you. Run the binary from Terminal and you get Terminal's
/// answer. To get Levers' own answer, launch it through LaunchServices:
///   open -n -W --stdout /tmp/levers.txt build/Levers.app --args --status
enum Permissions {
    /// Accessibility (needed by Lock Keyboard). No prompt.
    static var accessibility: String { AXIsProcessTrusted() ? "granted" : "not-granted" }

    /// Automation of System Events (needed by Dark Mode).
    /// `askUserIfNeeded: false` only reads the current answer.
    static var automation: String {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        guard var desc = target.aeDesc?.pointee else { return "unknown" }
        let status = AEDeterminePermissionToAutomateTarget(&desc, typeWildCard, typeWildCard, false)
        switch status {
        case noErr: return "granted"
        case OSStatus(errAEEventNotPermitted): return "denied"  // -1743
        case OSStatus(errAEEventWouldRequireUserConsent): return "not-asked"  // -1744
        case OSStatus(procNotFound): return "unknown (System Events not running)"  // -600
        default: return "unknown (\(status))"
        }
    }
}
