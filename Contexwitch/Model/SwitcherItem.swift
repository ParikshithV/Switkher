//
//  SwitcherItem.swift
//  Contexwitch
//

import ApplicationServices

nonisolated struct AppInfo: Sendable {
    let pid: pid_t
    let name: String
    let bundleID: String?
}

/// A window or tab that can be switched to.
nonisolated struct SwitcherItem: Identifiable, @unchecked Sendable {
    enum Kind: Sendable { case window, tab }

    let id: String
    let kind: Kind
    let pid: pid_t
    let appName: String
    let windowID: CGWindowID?
    let title: String
    /// For tabs, the title of the containing window.
    let windowTitle: String
    let isMinimized: Bool
    let isSelectedTab: Bool
    let windowElement: AXUIElement
    let tabElement: AXUIElement?
}

nonisolated struct WindowEntry: Identifiable, @unchecked Sendable {
    let window: SwitcherItem
    let tabs: [SwitcherItem]

    var id: String { window.id }
}
