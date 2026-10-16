//
//  FavoriteApps.swift
//  Contexwitch
//

import AppKit

nonisolated struct FavoriteApp: Codable, Hashable, Identifiable, Sendable {
    /// A single uppercase letter, A–Z.
    var letter: String
    var bundleID: String
    var path: String

    var id: String { bundleID }

    var name: String {
        let name = FileManager.default.displayName(atPath: path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// Prefers the current location of the bundle in case the app was moved.
    var applicationURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return url }
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}

nonisolated struct FavoriteApps: RawRepresentable, Equatable, Sendable {
    static let letters = (UnicodeScalar("A").value...UnicodeScalar("Z").value).map { String(UnicodeScalar($0)!) }

    var items: [FavoriteApp]

    init(items: [FavoriteApp] = []) {
        self.items = items
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let items = try? JSONDecoder().decode([FavoriteApp].self, from: data) else { return nil }
        self.items = items
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(items) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    func favorite(for letter: String) -> FavoriteApp? {
        items.first { $0.letter == letter }
    }

    /// Adds an app bundle, preferring its first letter if that's free.
    mutating func add(appAt url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier,
              !items.contains(where: { $0.bundleID == bundleID }) else { return }
        let used = Set(items.map(\.letter))
        let free = Self.letters.filter { !used.contains($0) }
        let initial = FileManager.default.displayName(atPath: url.path).first.map { String($0).uppercased() }
        guard let letter = free.first(where: { $0 == initial }) ?? free.first else { return }
        items.append(FavoriteApp(letter: letter, bundleID: bundleID, path: url.path))
    }
}

enum FavoriteIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for favorite: FavoriteApp) -> NSImage {
        if let cached = cache[favorite.bundleID] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: favorite.applicationURL?.path ?? favorite.path)
        cache[favorite.bundleID] = icon
        return icon
    }
}
