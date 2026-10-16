//
//  ModifierLongPressMonitor.swift
//  Contexwitch
//

import AppKit
import Carbon.HIToolbox

enum LongPressKey: String, CaseIterable, Identifiable {
    case off, option, rightOption, command, rightCommand, control, function

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "Off"
        case .option: "⌥ Option (either)"
        case .rightOption: "Right ⌥ Option"
        case .command: "⌘ Command (either)"
        case .rightCommand: "Right ⌘ Command"
        case .control: "⌃ Control"
        case .function: "fn / 🌐"
        }
    }

    var modifier: NSEvent.ModifierFlags? {
        switch self {
        case .off: nil
        case .option, .rightOption: .option
        case .command, .rightCommand: .command
        case .control: .control
        case .function: .function
        }
    }

    /// Key codes reported by the flagsChanged event when the key goes down.
    var keyCodes: Set<UInt16> {
        switch self {
        case .off: []
        case .option: [UInt16(kVK_Option), UInt16(kVK_RightOption)]
        case .rightOption: [UInt16(kVK_RightOption)]
        case .command: [UInt16(kVK_Command), UInt16(kVK_RightCommand)]
        case .rightCommand: [UInt16(kVK_RightCommand)]
        case .control: [UInt16(kVK_Control), UInt16(kVK_RightControl)]
        case .function: [UInt16(kVK_Function)]
        }
    }
}

/// Opens the switcher when a modifier key is held on its own. Pressing any
/// other key or clicking before the delay elapses cancels it, so ordinary
/// modifier shortcuts (⌥←, ⌥-click, …) are unaffected.
final class ModifierLongPressMonitor {
    static let shared = ModifierLongPressMonitor()

    private static let trackedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    private var monitors: [Any] = []
    private var timer: Timer?
    private var key: LongPressKey = .off

    func apply() {
        let newKey = Preferences.longPressKey
        guard newKey != key || (newKey != .off && monitors.isEmpty) else { return }
        key = newKey
        cancel()
        if key == .off {
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
        } else if monitors.isEmpty {
            install()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func install() {
        let interrupting: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let monitors: [Any?] = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                MainActor.assumeIsolated { ModifierLongPressMonitor.shared.handleFlagsChanged(event) }
            },
            NSEvent.addGlobalMonitorForEvents(matching: interrupting) { _ in
                MainActor.assumeIsolated { ModifierLongPressMonitor.shared.cancel() }
            },
            // Global monitors don't see events sent to our own windows (e.g. Settings).
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                ModifierLongPressMonitor.shared.handleFlagsChanged(event)
                return event
            },
            NSEvent.addLocalMonitorForEvents(matching: interrupting) { event in
                ModifierLongPressMonitor.shared.cancel()
                return event
            },
        ]
        self.monitors = monitors.compactMap { $0 }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        cancel()
        guard let modifier = key.modifier, !SwitcherController.shared.isVisible,
              key.keyCodes.contains(event.keyCode),
              event.modifierFlags.intersection(Self.trackedModifiers) == modifier else { return }

        timer = Timer.scheduledTimer(withTimeInterval: Preferences.longPressDelay, repeats: false) { _ in
            MainActor.assumeIsolated { ModifierLongPressMonitor.shared.fire(modifier) }
        }
    }

    private func fire(_ modifier: NSEvent.ModifierFlags) {
        timer = nil
        guard NSEvent.modifierFlags.intersection(Self.trackedModifiers) == modifier else { return }
        SwitcherController.shared.openForLongPress(holdModifiers: modifier)
    }
}
