//
//  WindowIndexer.swift
//  Contexwitch
//

import ApplicationServices
import Foundation

/// Enumerates windows (across all Spaces) and their tabs using the
/// Accessibility API. Apps are scanned in parallel off the main thread.
nonisolated final class WindowIndexer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Switkher.WindowIndexer", qos: .userInitiated)
    private let lock = NSLock()
    /// CG windows that an exhaustive brute-force found no AX counterpart for (helper/offscreen windows).
    private var phantomWindowIDs: [pid_t: Set<CGWindowID>] = [:]
    /// Every AX window element seen so far, keyed by window ID. `kAXWindowsAttribute` only
    /// reports the current Space, so this keeps windows on other Spaces stable between scans.
    private var windowElementCache: [pid_t: [CGWindowID: AXUIElement]] = [:]
    private var manualAccessibilityPIDs: Set<pid_t> = []

    private static let tabSearchSkippedRoles: Set<String> = [
        "AXWebArea", kAXTextAreaRole, kAXTableRole, kAXOutlineRole, kAXBrowserRole, kAXListRole,
    ]

    func refresh(apps: [AppInfo], includeTabs: Bool, completion: @escaping @Sendable ([WindowEntry]) -> Void) {
        queue.async {
            completion(self.scan(apps: apps, includeTabs: includeTabs))
        }
    }

    private func scan(apps: [AppInfo], includeTabs: Bool) -> [WindowEntry] {
        let cgWindows = Self.cgWindowIDsByPID()
        let resultsLock = NSLock()
        nonisolated(unsafe) var results = [[WindowEntry]](repeating: [], count: apps.count)
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            let app = apps[index]
            let entries = scanApp(app, cgWindowIDs: cgWindows[app.pid] ?? [], includeTabs: includeTabs)
            resultsLock.withLock { results[index] = entries }
        }

        let livePIDs = Set(apps.map(\.pid))
        lock.withLock {
            phantomWindowIDs = phantomWindowIDs.filter { livePIDs.contains($0.key) }
            windowElementCache = windowElementCache.filter { livePIDs.contains($0.key) }
        }
        return results.flatMap { $0 }
    }

    private func scanApp(_ app: AppInfo, cgWindowIDs: Set<CGWindowID>, includeTabs: Bool) -> [WindowEntry] {
        let appElement = AXUIElementCreateApplication(app.pid)
        if includeTabs { enableManualAccessibilityIfNeeded(appElement, pid: app.pid) }

        var windows = AX.elements(appElement, kAXWindowsAttribute)
        var elementsByID: [CGWindowID: AXUIElement] = [:]
        for window in windows {
            if let id = PrivateAPI.windowID(of: window) { elementsByID[id] = window }
        }

        let (cached, previousPhantoms) = lock.withLock {
            (windowElementCache[app.pid] ?? [:], phantomWindowIDs[app.pid] ?? [])
        }

        // Reuse elements found earlier (e.g. while on another Space) for windows that still exist.
        for (id, element) in cached where elementsByID[id] == nil && cgWindowIDs.contains(id) {
            elementsByID[id] = element
            windows.append(element)
        }

        var phantoms = previousPhantoms.intersection(cgWindowIDs).subtracting(elementsByID.keys)
        let missing = cgWindowIDs.subtracting(elementsByID.keys).subtracting(phantoms)
        if !missing.isEmpty {
            let search = PrivateAPI.windowsFromRemoteTokens(pid: app.pid, wanted: missing)
            for element in search.windows {
                guard let id = PrivateAPI.windowID(of: element), elementsByID[id] == nil else { continue }
                elementsByID[id] = element
                windows.append(element)
            }
            // Only conclude a window has no AX element if the whole token range was searched;
            // a timed-out search says nothing about the windows it didn't reach.
            if search.isExhaustive {
                phantoms.formUnion(missing.subtracting(elementsByID.keys))
            }
        }

        let liveElements = elementsByID.filter { cgWindowIDs.contains($0.key) }
        lock.withLock {
            phantomWindowIDs[app.pid] = phantoms
            windowElementCache[app.pid] = liveElements
        }

        return windows.compactMap { makeEntry(window: $0, app: app, includeTabs: includeTabs) }
    }

    /// Chromium and Electron apps only build their accessibility tree on request.
    private func enableManualAccessibilityIfNeeded(_ appElement: AXUIElement, pid: pid_t) {
        lock.lock()
        let inserted = manualAccessibilityPIDs.insert(pid).inserted
        lock.unlock()
        if inserted { AX.set(appElement, "AXManualAccessibility", kCFBooleanTrue) }
    }

    private func makeEntry(window: AXUIElement, app: AppInfo, includeTabs: Bool) -> WindowEntry? {
        guard AX.string(window, kAXRoleAttribute) == kAXWindowRole else { return nil }
        let subrole = AX.string(window, kAXSubroleAttribute)
        guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { return nil }

        let rawTitle = AX.string(window, kAXTitleAttribute) ?? ""
        let title = rawTitle.isEmpty ? app.name : rawTitle
        let windowID = PrivateAPI.windowID(of: window)
        let baseID = "\(app.pid)-\(windowID.map(String.init) ?? String(CFHash(window)))"

        let windowItem = SwitcherItem(
            id: "w-\(baseID)", kind: .window, pid: app.pid, appName: app.name, windowID: windowID,
            title: title, windowTitle: title,
            isMinimized: AX.bool(window, kAXMinimizedAttribute) ?? false,
            isSelectedTab: false, windowElement: window, tabElement: nil
        )

        var tabs: [SwitcherItem] = []
        if includeTabs {
            for (index, tab) in tabElements(in: window).enumerated() {
                let tabTitle = AX.string(tab, kAXTitleAttribute).flatMap { $0.isEmpty ? nil : $0 }
                    ?? AX.string(tab, kAXDescriptionAttribute) ?? ""
                guard !tabTitle.isEmpty else { continue }
                let selected = AX.attribute(tab, kAXValueAttribute, as: Int.self) == 1
                tabs.append(SwitcherItem(
                    id: "t-\(baseID)-\(index)", kind: .tab, pid: app.pid, appName: app.name, windowID: windowID,
                    title: tabTitle, windowTitle: title, isMinimized: windowItem.isMinimized,
                    isSelectedTab: selected, windowElement: window, tabElement: tab
                ))
            }
            if tabs.count < 2 { tabs = [] }
        }
        return WindowEntry(window: windowItem, tabs: tabs)
    }

    /// Breadth-first search for the largest tab group in a window.
    private func tabElements(in window: AXUIElement) -> [AXUIElement] {
        var pending: [(element: AXUIElement, depth: Int)] = [(window, 0)]
        var cursor = 0
        var best: [AXUIElement] = []

        while cursor < pending.count, cursor < 400 {
            let (element, depth) = pending[cursor]
            cursor += 1
            let role = AX.string(element, kAXRoleAttribute) ?? ""

            if role == kAXTabGroupRole {
                var tabs = AX.elements(element, kAXTabsAttribute)
                if tabs.isEmpty {
                    tabs = AX.elements(element, kAXChildrenAttribute).filter {
                        AX.string($0, kAXRoleAttribute) == kAXRadioButtonRole
                    }
                }
                if tabs.count > best.count { best = tabs }
                continue
            }
            guard depth < 8, !Self.tabSearchSkippedRoles.contains(role) else { continue }
            for child in AX.elements(element, kAXChildrenAttribute) {
                pending.append((child, depth + 1))
            }
        }
        return best
    }

    // MARK: - CoreGraphics window list

    private static func normalWindows(_ options: CGWindowListOption) -> [[String: Any]] {
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (bounds["Width"] ?? 0) >= 100 && (bounds["Height"] ?? 0) >= 100
        }
    }

    static func cgWindowIDsByPID() -> [pid_t: Set<CGWindowID>] {
        var map: [pid_t: Set<CGWindowID>] = [:]
        for info in normalWindows([.optionAll, .excludeDesktopElements]) {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let id = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            map[pid, default: []].insert(id)
        }
        return map
    }

    /// On-screen windows of the current Space, front to back.
    static func frontToBackWindowIDs() -> [CGWindowID] {
        normalWindows([.optionOnScreenOnly, .excludeDesktopElements]).compactMap {
            $0[kCGWindowNumber as String] as? CGWindowID
        }
    }
}
