//
//  HotKeyController.swift
//  Contexwitch
//

import AppKit
import Carbon.HIToolbox

/// Registers the global shortcuts from Preferences using Carbon hotkeys,
/// which work system-wide without extra permissions.
final class HotKeyController {
    static let shared = HotKeyController()

    private enum HotKeyID: UInt32 {
        case cycleForward = 1, cycleBackward, search
    }

    /// Suspended while the shortcut recorder is capturing keys.
    var isSuspended = false {
        didSet { apply(force: true) }
    }

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var appliedShortcuts: [Shortcut]?
    private var handlerRef: EventHandlerRef?

    func apply(force: Bool = false) {
        let cycle = Preferences.cycleShortcut
        let search = Preferences.searchShortcut
        if !force, appliedShortcuts == [cycle, search] { return }

        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        appliedShortcuts = nil
        guard !isSuspended else { return }

        installHandlerIfNeeded()
        register(.cycleForward, cycle)
        if !cycle.modifiers.contains(.shift) {
            var backward = cycle
            backward.modifiers.insert(.shift)
            register(.cycleBackward, backward)
        }
        register(.search, search)
        appliedShortcuts = [cycle, search]
    }

    private func register(_ id: HotKeyID, _ shortcut: Shortcut) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4358_5357) /* CXSW */, id: id.rawValue)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { hotKeyRefs.append(ref) }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, &handlerRef)
    }

    fileprivate func handle(_ rawID: UInt32) {
        guard let id = HotKeyID(rawValue: rawID) else { return }
        let switcher = SwitcherController.shared
        switch id {
        case .cycleForward: switcher.cycle(backward: false, holdModifiers: Preferences.cycleShortcut.modifiers)
        case .cycleBackward: switcher.cycle(backward: true, holdModifiers: Preferences.cycleShortcut.modifiers)
        case .search: switcher.toggleSearch()
        }
    }
}

private nonisolated func hotKeyEventHandler(_ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated { HotKeyController.shared.handle(id) }
    return noErr
}
