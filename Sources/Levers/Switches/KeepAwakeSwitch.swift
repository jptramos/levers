import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac from idle-sleeping using an IOKit power assertion.
///
/// An assertion is a "please don't sleep" ticket held by this process.
/// The kernel's power manager counts open tickets. We hold a
/// `PreventUserIdleDisplaySleep` ticket: the screen stays on, and since the
/// display can't sleep, neither does the system (it implies
/// PreventUserIdleSystemSleep).
/// If the app quits or crashes, the kernel releases the ticket for us.
/// `pmset -g assertions` lists every open ticket and who holds it.
///
/// Timer: the assertion itself carries the timeout. With the "release"
/// timeout action, the power manager drops the ticket when time is up, so
/// the timer works even if Levers is busy or asleep. No Swift Timer needed.
@MainActor
final class KeepAwakeSwitch: Switch {
    let id = "keep-awake"
    let name = "Keep Awake"
    let onIcon = "cup.and.saucer.fill"
    let offIcon = "cup.and.saucer"
    let stopsWhenHidden = true

    /// Choices in the row's timer menu. nil = until turned off.
    static let durations: [(label: String, seconds: TimeInterval?)] = [
        ("Until turned off", nil),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 hour", 3600),
        ("2 hours", 2 * 3600),
        ("4 hours", 4 * 3600),
        ("8 hours", 8 * 3600),
    ]

    private var assertionID: IOPMAssertionID = 0
    private(set) var deadline: Date?

    /// The chosen duration, remembered across launches (0 = until turned off).
    var duration: TimeInterval? {
        get {
            let s = UserDefaults.standard.double(forKey: "keepAwakeSeconds")
            return s > 0 ? s : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepAwakeSeconds") }
    }

    /// State check: ask IOKit whether *our* assertion is still alive,
    /// rather than trusting the stored ID. After a timeout the power
    /// manager has released it, so this reads off on its own.
    var isOn: Bool {
        guard assertionID != 0 else { return false }
        // Copies the properties of one assertion; nil if it no longer exists.
        // "Copy" in a CoreFoundation name means we own the result and must release it.
        guard let props = IOPMAssertionCopyProperties(assertionID) else {
            // Gone: the timeout released it. Forget the ID so later reads
            // skip the IOKit call.
            assertionID = 0
            deadline = nil
            return false
        }
        props.release()
        return true
    }

    /// Row subtitle, only while a timed run is on: "Until 6:42 PM".
    /// Off (or on with no timer) shows nothing; the chosen duration is
    /// checkmarked in the timer menu instead.
    var detail: String? {
        guard isOn, let deadline else { return nil }
        return "Until \(deadline.formatted(date: .omitted, time: .shortened))"
    }

    func set(on: Bool) throws {
        if on {
            guard !isOn else { return }
            var newID: IOPMAssertionID = 0
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Levers Keep Awake" as CFString,
                &newID
            )
            guard status == kIOReturnSuccess else {
                throw SwitchError(message: "IOPMAssertionCreateWithName failed (\(status))")
            }
            assertionID = newID
            deadline = nil
            if let duration {
                // IOPMLib's kIOPMAssertionTimeoutKey / ...ActionKey / ...ActionRelease
                // are CFSTR() macros, which Swift can't import; these are their values.
                let a = IOPMAssertionSetProperty(newID, "TimeoutSeconds" as CFString, duration as CFNumber)
                let b = IOPMAssertionSetProperty(newID, "TimeoutAction" as CFString, "TimeoutActionRelease" as CFString)
                guard a == kIOReturnSuccess, b == kIOReturnSuccess else {
                    // Don't leave an untimed assertion that the row claims is timed.
                    IOPMAssertionRelease(newID)
                    assertionID = 0
                    throw SwitchError(message: "Couldn't set the timer (\(a == kIOReturnSuccess ? b : a))")
                }
                deadline = Date().addingTimeInterval(duration)
            }
        } else {
            guard assertionID != 0 else { return }
            IOPMAssertionRelease(assertionID)  // harmless if the timeout already released it
            assertionID = 0
            deadline = nil
        }
    }

    /// Pick a new duration. If it's running, restart it so the new
    /// timeout applies from now.
    func choose(_ seconds: TimeInterval?) throws {
        duration = seconds
        if isOn {
            try set(on: false)
            try set(on: true)
        }
    }
}
