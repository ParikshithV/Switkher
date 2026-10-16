//
//  CommandTabInterceptor.swift
//  Contexwitch
//

import AppKit
import Carbon.HIToolbox

/// ⌘Tab is reserved by the system and can't be registered as a Carbon hotkey,
/// so replacing it needs an event tap (requires Accessibility access).
final class CommandTabInterceptor {
    static let shared = CommandTabInterceptor()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isEnabled: Bool { tap != nil }

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: commandTabTapCallback, userInfo: nil
        ) else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    private func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

private nonisolated func commandTabTapCallback(
    _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { CommandTabInterceptor.shared.reenable() }
        return Unmanaged.passUnretained(event)
    }
    let flags = event.flags
    guard type == .keyDown || type == .keyUp,
          event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Tab),
          flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) else {
        return Unmanaged.passUnretained(event)
    }
    if type == .keyDown {
        let backward = flags.contains(.maskShift)
        MainActor.assumeIsolated {
            SwitcherController.shared.cycle(backward: backward, holdModifiers: .command)
        }
    }
    return nil
}
