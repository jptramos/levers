import AppKit
import CoreGraphics

/// Locks the keyboard (for cleaning it) with an active Quartz event tap.
///
/// An event tap is a hook into the window server's event stream. A
/// *session* tap sees every event headed to apps in this login session;
/// inserted at the *head*, it sees them first. An *active* (default) tap
/// can change or drop events: returning nil from the callback means the
/// event never arrives anywhere. We only mask keyboard events, so the
/// mouse keeps working and the toggle can always be clicked off.
///
/// Permission: creating an active tap needs Accessibility
/// (Privacy & Security → Accessibility; on macOS 27 the list is called
/// "Device Control and Data Access"). Without it
/// `CGEvent.tapCreate` returns nil.
///
/// Crash safety: the tap belongs to this process. If Levers quits or
/// is killed, the window server drops the tap and the keyboard is back.
@MainActor
final class LockKeyboardSwitch: TimedSwitch {
    let id = "lock-keyboard"
    let name = "Lock Keyboard"
    let onIcon = "keyboard.fill"
    let offIcon = "keyboard"
    let stopsWhenHidden = true

    private var runLoopSource: CFRunLoopSource?

    /// The lock always ends on its own: about as long as a wipe takes,
    /// 45 s by default. There's deliberately no "until turned off" choice,
    /// so the keyboard can never stay locked if the mouse is out of reach.
    let durations: [(label: String, seconds: TimeInterval?)] = [
        ("30 seconds", 30), ("45 seconds", 45), ("1 minute", 60),
        ("2 minutes", 120), ("5 minutes", 300),
    ]
    let timerHelp = "Unlock after…"
    private static let defaultSeconds: TimeInterval = 45

    /// The chosen length, remembered across launches. A missing or
    /// hand-edited value falls back to 45 s.
    var duration: TimeInterval? {
        let s = UserDefaults.standard.double(forKey: "lockSeconds")
        return durations.compactMap(\.seconds).contains(s) ? s : Self.defaultSeconds
    }

    private var autoUnlock: Task<Void, Never>?
    private(set) var unlockAt: Date?

    /// A live countdown while locked: "Unlocks in 0:43".
    var detail: String? {
        guard isOn, let unlockAt else { return nil }
        return "Unlocks in \(countdown(to: unlockAt))"
    }
    var countsDown: Bool { isOn }

    func choose(_ seconds: TimeInterval?) throws {
        UserDefaults.standard.set(seconds ?? Self.defaultSeconds, forKey: "lockSeconds")
        if isOn {  // restart the countdown with the new length
            unlock()
            try lock()
        }
    }

    /// State check: ask the window server whether our tap is enabled.
    var isOn: Bool {
        guard let tap = LockTap.port else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func set(on: Bool) throws {
        on ? try lock() : unlock()
    }

    private func lock() throws {
        guard !isOn else { return }

        // Ask for Accessibility; `prompt: true` shows the system dialog
        // the first time. Returns the current answer immediately.
        // The key is `kAXTrustedCheckOptionPrompt`, but C exposes it as a
        // mutable global, which Swift 6 strict concurrency rejects; its
        // documented value is this string.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw SwitchError(message: "Levers needs permission to control this Mac. Turn Levers on in Privacy & Security, then try again.", settings: SettingsPane.accessibility)
        }

        // Event types are bit positions in the mask.
        // 14 = NX_SYSDEFINED: media keys (volume, brightness, play).
        // CGEventType has no public case for it, hence the raw value.
        let types: [UInt64] = [
            UInt64(CGEventType.keyDown.rawValue),
            UInt64(CGEventType.keyUp.rawValue),
            UInt64(CGEventType.flagsChanged.rawValue),  // modifier keys alone
            14,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // active: may drop events
            eventsOfInterest: mask,
            callback: lockTapCallback,
            userInfo: nil
        ) else {
            throw SwitchError(message: "Could not create event tap (is Accessibility allowed?)")
        }

        // A tap delivers events through a run loop source; attach it to
        // the main run loop so the callback runs on the main thread.
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        LockTap.port = tap
        runLoopSource = source

        let seconds = duration ?? Self.defaultSeconds
        unlockAt = Date().addingTimeInterval(seconds)
        autoUnlock = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.unlock()
        }
    }

    private func unlock() {
        autoUnlock?.cancel()
        autoUnlock = nil
        unlockAt = nil
        guard let tap = LockTap.port else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        LockTap.port = nil
        runLoopSource = nil
    }
}

/// The tap's mach port, reachable from the C callback (which can't
/// capture Swift context). Only touched on the main thread: the callback
/// runs on the main run loop.
private enum LockTap {
    nonisolated(unsafe) static var port: CFMachPort?
}

/// Called by the window server for every masked event.
/// Must be a plain C function: no captures.
private func lockTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // macOS switches a tap off if a callback is slow, or on some
        // secure-input events. Turn it straight back on so the lock holds.
        if let tap = LockTap.port { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    default:
        return nil  // drop the key event
    }
}
