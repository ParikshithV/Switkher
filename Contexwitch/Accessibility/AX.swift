//
//  AX.swift
//  Contexwitch
//

import ApplicationServices

/// Thin, typed wrappers around the C Accessibility API.
nonisolated enum AX {
    static func attribute<T>(_ element: AXUIElement, _ name: String, as type: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value else {
            return nil
        }
        return value as? T
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name, as: String.self)
    }

    static func bool(_ element: AXUIElement, _ name: String) -> Bool? {
        attribute(element, name, as: Bool.self)
    }

    static func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        attribute(element, name, as: [AXUIElement].self) ?? []
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(element, name as CFString, value) == .success
    }

    @discardableResult
    static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
