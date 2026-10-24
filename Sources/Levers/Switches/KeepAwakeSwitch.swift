import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac from idle-sleeping using an IOKit power assertion.
///
/// An assertion is a "please don't sleep" ticket held by this process.
/// The kernel's power manager counts open tickets; while any
/// `PreventUserIdleSystemSleep` ticket is open, the Mac won't idle-sleep.
/// If the app quits or crashes, the kernel releases the ticket for us.
/// `pmset -g assertions` lists every open ticket and who holds it.
@MainActor
final class KeepAwakeSwitch: Switch {
    let id = "keep-awake"
    let name = "Keep Awake"
    let onIcon = "cup.and.saucer.fill"
    let offIcon = "cup.and.saucer"
    let stopsWhenHidden = true

    private var assertionID: IOPMAssertionID = 0

    /// State check: ask IOKit whether *our* assertion is still alive,
    /// rather than trusting the stored ID.
    var isOn: Bool {
        guard assertionID != 0 else { return false }
        // Copies the properties of one assertion; nil if it no longer exists.
        // "Copy" in a CoreFoundation name means we own the result and must release it.
        guard let props = IOPMAssertionCopyProperties(assertionID) else { return false }
        props.release()
        return true
    }

    func set(on: Bool) throws {
        if on {
            guard !isOn else { return }
            var newID: IOPMAssertionID = 0
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Levers Keep Awake" as CFString,
                &newID
            )
            guard status == kIOReturnSuccess else {
                throw SwitchError(message: "IOPMAssertionCreateWithName failed (\(status))")
            }
            assertionID = newID
        } else {
            guard assertionID != 0 else { return }
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
