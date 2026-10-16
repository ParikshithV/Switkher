//
//  Shortcut.swift
//  Contexwitch
//

import AppKit
import Carbon.HIToolbox

nonisolated struct Shortcut: Equatable, RawRepresentable, Sendable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    var keyLabel: String

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static let defaultCycle = Shortcut(keyCode: UInt32(kVK_Tab), modifiers: .option, keyLabel: "⇥")
    static let defaultSearch = Shortcut(keyCode: UInt32(kVK_Space), modifiers: .option, keyLabel: "Space")

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
        self.keyLabel = keyLabel
    }

    init(event: NSEvent) {
        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags,
            keyLabel: Self.label(forKeyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
        )
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let keyCode = UInt32(parts[0]), let modifiers = UInt(parts[1]) else { return nil }
        self.init(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers), keyLabel: String(parts[2]))
    }

    var rawValue: String { "\(keyCode):\(modifiers.rawValue):\(keyLabel)" }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyLabel
    }

    private static func label(forKeyCode keyCode: Int, characters: String?) -> String {
        switch keyCode {
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return characters?.uppercased() ?? "?"
        }
    }
}
