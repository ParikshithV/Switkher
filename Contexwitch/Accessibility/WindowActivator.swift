//
//  WindowActivator.swift
//  Contexwitch
//

import AppKit

enum WindowActivator {
    static func activate(_ item: SwitcherItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }
        if app.isHidden { app.unhide() }

        let window = item.windowElement
        if AX.bool(window, kAXMinimizedAttribute) == true {
            AX.set(window, kAXMinimizedAttribute, kCFBooleanFalse)
        }
        if let tab = item.tabElement {
            AX.perform(tab, kAXPressAction)
        }

        var focused = false
        if let windowID = item.windowID {
            focused = PrivateAPI.focus(pid: item.pid, windowID: windowID)
        }
        AX.perform(window, kAXRaiseAction)

        if !focused {
            AX.set(window, kAXMainAttribute, kCFBooleanTrue)
            AX.set(AXUIElementCreateApplication(item.pid), kAXFrontmostAttribute, kCFBooleanTrue)
            app.activate()
        }
        RecencyTracker.shared.bump(item.windowID)
    }
}
