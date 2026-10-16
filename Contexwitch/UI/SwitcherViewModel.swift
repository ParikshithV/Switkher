//
//  SwitcherViewModel.swift
//  Contexwitch
//

import AppKit
import Combine

struct SwitcherRow: Identifiable {
    enum Style { case header, window, tab }

    let id: String
    let style: Style
    let item: SwitcherItem?
    let pid: pid_t
    let title: String
    let subtitle: String
    var parentID: String? = nil
    var indented = false
    var tabCount = 0
    var isExpanded = false
    /// 1–10 for the first ten selectable rows; pressing that digit jumps to the row.
    var shortcutIndex: Int?
}

final class SwitcherViewModel: ObservableObject {
    enum Mode { case cycle(backward: Bool), search }

    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            userNavigated = false
            rebuild()
        }
    }
    @Published private(set) var rows: [SwitcherRow] = []
    @Published private(set) var selectedID: String?
    /// Incremented whenever the search field should take focus.
    @Published private(set) var focusToken = 0

    private(set) var entries: [WindowEntry] = []
    private var recency: [CGWindowID: Int] = [:]
    private var expandedIDs: Set<String> = []
    private var mode: Mode = .search
    private var frontWindowID: CGWindowID?
    private var userNavigated = false

    var selectedItem: SwitcherItem? {
        rows.first { $0.id == selectedID }?.item
    }

    var isEmpty: Bool { entries.isEmpty }

    var hasUserNavigated: Bool { userNavigated }

    /// The app's most recently used window, preferring ones that aren't minimized.
    func mostRecentWindow(pid: pid_t) -> SwitcherItem? {
        entries.map(\.window)
            .filter { $0.pid == pid }
            .max { lhs, rhs in
                if lhs.isMinimized != rhs.isMinimized { return lhs.isMinimized }
                let left = lhs.windowID.flatMap { recency[$0] } ?? Int.min
                let right = rhs.windowID.flatMap { recency[$0] } ?? Int.min
                return left < right
            }
    }

    func prepare(mode: Mode, frontWindowID: CGWindowID?) {
        self.mode = mode
        self.frontWindowID = frontWindowID
        expandedIDs = []
        userNavigated = false
        if query.isEmpty { rebuild() } else { query = "" }
        focusToken += 1
    }

    func update(entries: [WindowEntry], recency: [CGWindowID: Int]) {
        self.entries = entries
        self.recency = recency
        rebuild()
    }

    func beginSearch(with text: String) {
        mode = .search
        query += text
        focusToken += 1
    }

    func moveSelection(by offset: Int) {
        let selectable = rows.filter { $0.item != nil }
        guard !selectable.isEmpty else { return }
        let current = selectable.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : 0)
        let next = ((current + offset) % selectable.count + selectable.count) % selectable.count
        selectedID = selectable[next].id
        userNavigated = true
    }

    func select(_ id: String) {
        selectedID = id
        userNavigated = true
    }

    func select(shortcutIndex: Int) -> Bool {
        guard let row = rows.first(where: { $0.shortcutIndex == shortcutIndex }) else { return false }
        select(row.id)
        return true
    }

    /// Expands or collapses the selected window's tabs. Returns whether anything changed.
    func setSelectionExpanded(_ expand: Bool) -> Bool {
        guard query.isEmpty, let row = rows.first(where: { $0.id == selectedID }) else { return false }
        switch row.style {
        case .window where row.tabCount > 0 && expand != row.isExpanded:
            if expand { expandedIDs.insert(row.id) } else { expandedIDs.remove(row.id) }
        case .tab where !expand:
            guard let parentID = row.parentID else { return false }
            expandedIDs.remove(parentID)
            selectedID = parentID
        default:
            return false
        }
        userNavigated = true
        rebuild()
        return true
    }

    // MARK: - Building rows

    private func rebuild() {
        let previous = selectedID
        let sorted = sortedEntries()
        var newRows = query.isEmpty ? browseRows(sorted) : searchRows(sorted)
        var nextIndex = 1
        for index in newRows.indices where newRows[index].item != nil && nextIndex <= 10 {
            newRows[index].shortcutIndex = nextIndex
            nextIndex += 1
        }
        rows = newRows

        if userNavigated, let previous, rows.contains(where: { $0.id == previous && $0.item != nil }) {
            selectedID = previous
        } else {
            selectedID = defaultSelection(sorted)
        }
    }

    private func defaultSelection(_ sorted: [WindowEntry]) -> String? {
        let selectable = rows.filter { $0.item != nil }
        guard !selectable.isEmpty else { return nil }
        if !query.isEmpty { return selectable[0].id }
        if case .cycle(backward: true) = mode { return selectable.last?.id }

        // Default to the most recent window that isn't the one currently focused,
        // so a quick tap switches back to the previous window.
        let previousWindow = sorted.first { $0.window.windowID == nil || $0.window.windowID != frontWindowID }
        return previousWindow?.id ?? selectable[0].id
    }

    private func sortedEntries() -> [WindowEntry] {
        switch Preferences.sortOrder {
        case .recent:
            return entries.enumerated().sorted { lhs, rhs in
                let left = lhs.element.window.windowID.flatMap { recency[$0] } ?? Int.min
                let right = rhs.element.window.windowID.flatMap { recency[$0] } ?? Int.min
                return left != right ? left > right : lhs.offset < rhs.offset
            }.map(\.element)
        case .alphabetical:
            return entries.sorted { lhs, rhs in
                let byApp = lhs.window.appName.localizedStandardCompare(rhs.window.appName)
                if byApp != .orderedSame { return byApp == .orderedAscending }
                return lhs.window.title.localizedStandardCompare(rhs.window.title) == .orderedAscending
            }
        }
    }

    private func browseRows(_ sorted: [WindowEntry]) -> [SwitcherRow] {
        let groupByApp = Preferences.groupByApp
        var groups: [(pid: pid_t, entries: [WindowEntry])] = []
        if groupByApp {
            for entry in sorted {
                if let index = groups.firstIndex(where: { $0.pid == entry.window.pid }) {
                    groups[index].entries.append(entry)
                } else {
                    groups.append((entry.window.pid, [entry]))
                }
            }
        } else {
            groups = [(0, sorted)]
        }

        var rows: [SwitcherRow] = []
        for group in groups {
            if groupByApp, let first = group.entries.first {
                rows.append(SwitcherRow(id: "h-\(group.pid)", style: .header, item: nil, pid: group.pid,
                                        title: first.window.appName, subtitle: ""))
            }
            for entry in group.entries {
                let window = entry.window
                let expanded = expandedIDs.contains(entry.id)
                var details: [String] = groupByApp ? [] : [window.appName]
                if window.isMinimized { details.append("Minimized") }
                rows.append(SwitcherRow(
                    id: window.id, style: .window, item: window, pid: window.pid, title: window.title,
                    subtitle: details.joined(separator: " · "), tabCount: entry.tabs.count, isExpanded: expanded
                ))
                guard expanded else { continue }
                for tab in entry.tabs {
                    rows.append(SwitcherRow(
                        id: tab.id, style: .tab, item: tab, pid: tab.pid, title: tab.title,
                        subtitle: tab.isSelectedTab ? "Active tab" : "", parentID: window.id, indented: true
                    ))
                }
            }
        }
        return rows
    }

    private func searchRows(_ sorted: [WindowEntry]) -> [SwitcherRow] {
        var matches: [(row: SwitcherRow, score: Int, order: Int)] = []
        for entry in sorted {
            let window = entry.window
            if let score = FuzzyMatcher.score(query, fields: [(window.title, 3), (window.appName, 2)]) {
                matches.append((SwitcherRow(
                    id: window.id, style: .window, item: window, pid: window.pid, title: window.title,
                    subtitle: window.isMinimized ? "\(window.appName) · Minimized" : window.appName,
                    tabCount: entry.tabs.count
                ), score + 1, matches.count))
            }
            for tab in entry.tabs {
                guard let score = FuzzyMatcher.score(query, fields: [(tab.title, 3), (tab.appName, 2)]) else { continue }
                matches.append((SwitcherRow(
                    id: tab.id, style: .tab, item: tab, pid: tab.pid, title: tab.title,
                    subtitle: "Tab · \(tab.appName) — \(tab.windowTitle)", parentID: window.id
                ), score, matches.count))
            }
        }
        return matches
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .map(\.row)
    }
}
