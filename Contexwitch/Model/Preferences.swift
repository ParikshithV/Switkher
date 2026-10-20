//
//  Preferences.swift
//  Contexwitch
//

import Foundation
import ServiceManagement

enum PrefKey {
    static let sortOrder = "sortOrder"
    static let groupByApp = "groupByApp"
    static let trackTabs = "trackTabs"
    static let replaceCommandTab = "replaceCommandTab"
    static let cycleShortcut = "cycleShortcut"
    static let searchShortcut = "searchShortcut"
    static let longPressKey = "longPressKey"
    static let longPressDelay = "longPressDelay"
    static let favoriteApps = "favoriteApps"
    static let didEnableLaunchAtLogin = "didEnableLaunchAtLogin"
}

enum SortOrder: String, CaseIterable, Identifiable {
    case recent, alphabetical

    var id: Self { self }
    var title: String {
        switch self {
        case .recent: "Most recently used"
        case .alphabetical: "Alphabetical"
        }
    }
}

enum Preferences {
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            PrefKey.sortOrder: SortOrder.recent.rawValue,
            PrefKey.groupByApp: false,
            PrefKey.trackTabs: true,
            PrefKey.replaceCommandTab: false,
            PrefKey.cycleShortcut: Shortcut.defaultCycle.rawValue,
            PrefKey.searchShortcut: Shortcut.defaultSearch.rawValue,
            PrefKey.longPressKey: LongPressKey.option.rawValue,
            PrefKey.longPressDelay: 0.4,
            PrefKey.favoriteApps: FavoriteApps().rawValue,
        ])
    }

    /// Launch at login is on by default. The login item lives in the system, not in
    /// UserDefaults, so register it once on first launch and leave it to the user after that.
    static func enableLaunchAtLoginOnFirstRun() {
        guard !defaults.bool(forKey: PrefKey.didEnableLaunchAtLogin) else { return }
        defaults.set(true, forKey: PrefKey.didEnableLaunchAtLogin)
        try? SMAppService.mainApp.register()
    }

    static var longPressKey: LongPressKey {
        defaults.string(forKey: PrefKey.longPressKey).flatMap(LongPressKey.init(rawValue:)) ?? .option
    }
    static var longPressDelay: TimeInterval { defaults.double(forKey: PrefKey.longPressDelay) }
    static var favoriteApps: FavoriteApps {
        defaults.string(forKey: PrefKey.favoriteApps).flatMap(FavoriteApps.init(rawValue:)) ?? FavoriteApps()
    }

    static var sortOrder: SortOrder {
        defaults.string(forKey: PrefKey.sortOrder).flatMap(SortOrder.init(rawValue:)) ?? .recent
    }
    static var groupByApp: Bool { defaults.bool(forKey: PrefKey.groupByApp) }
    static var trackTabs: Bool { defaults.bool(forKey: PrefKey.trackTabs) }
    static var replaceCommandTab: Bool { defaults.bool(forKey: PrefKey.replaceCommandTab) }
    static var cycleShortcut: Shortcut {
        defaults.string(forKey: PrefKey.cycleShortcut).flatMap(Shortcut.init(rawValue:)) ?? .defaultCycle
    }
    static var searchShortcut: Shortcut {
        defaults.string(forKey: PrefKey.searchShortcut).flatMap(Shortcut.init(rawValue:)) ?? .defaultSearch
    }
}
