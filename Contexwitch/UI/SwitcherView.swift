//
//  SwitcherView.swift
//  Contexwitch
//

import SwiftUI
import UniformTypeIdentifiers

struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel
    let onActivate: () -> Void
    let onOpenFavorite: (FavoriteApp) -> Void

    @AppStorage(PrefKey.favoriteApps) private var favorites = FavoriteApps()
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if model.rows.isEmpty {
                emptyState
            } else {
                list
            }
            if !favorites.items.isEmpty {
                Divider()
                FavoritesBar(favorites: favorites.items, onOpen: onOpenFavorite)
            }
            Divider()
            footer
        }
        .frame(width: SwitcherPanel.size.width, height: SwitcherPanel.size.height)
        .background(WindowGlassBackground(cornerRadius: SwitcherPanel.cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: SwitcherPanel.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SwitcherPanel.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _, _ in searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search windows and tabs", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 19))
                .focused($searchFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.rows) { row in
                        SwitcherRowView(row: row, isSelected: row.id == model.selectedID)
                            .id(row.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard row.item != nil else { return }
                                model.select(row.id)
                                onActivate()
                            }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            if !AX.isTrusted {
                Image(systemName: "lock.shield")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Switkher needs Accessibility access to see your windows.")
                    .foregroundStyle(.secondary)
                Button("Grant Access…") { AppDelegate.openAccessibilitySettings() }
            } else {
                Image(systemName: model.query.isEmpty ? "macwindow.on.rectangle" : "magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text(model.query.isEmpty ? "No windows open" : "No windows or tabs match “\(model.query)”")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            KeyHint(keys: "↩", label: "Switch")
            KeyHint(keys: "↑↓", label: "Navigate")
            KeyHint(keys: "1–9", label: "Jump")
            if model.query.isEmpty { KeyHint(keys: "→", label: "Show tabs") }
            Spacer()
            KeyHint(keys: "esc", label: "Close")
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
    }
}

private struct SwitcherRowView: View {
    let row: SwitcherRow
    let isSelected: Bool

    var body: some View {
        if row.style == .header {
            Text(row.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 2)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            IndexBadge(index: row.shortcutIndex, isSelected: isSelected)
            if row.indented { Color.clear.frame(width: 14, height: 1) }

            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: AppIcons.icon(for: row.pid))
                    .resizable()
                    .frame(width: row.style == .tab ? 20 : 26, height: row.style == .tab ? 20 : 26)
                if row.style == .tab, !row.indented {
                    Image(systemName: "square.on.square.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .offset(x: 3, y: 3)
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 13, weight: row.style == .window ? .medium : .regular))
                    .lineLimit(1)
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)

            if row.tabCount > 0 {
                HStack(spacing: 3) {
                    Text("\(row.tabCount) tabs")
                    Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                }
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
            }
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .frame(height: row.style == .tab ? 34 : 42)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.9) : .clear)
        )
    }
}

private struct FavoritesBar: View {
    let favorites: [FavoriteApp]
    let onOpen: (FavoriteApp) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(favorites.sorted { $0.letter < $1.letter }) { favorite in
                    FavoriteButton(favorite: favorite) { onOpen(favorite) }
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 52)
    }
}

private struct FavoriteButton: View {
    let favorite: FavoriteApp
    let action: () -> Void

    @State private var isHovered = false

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: favorite.bundleID).isEmpty
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(favorite.letter)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
                Image(nsImage: FavoriteIcons.icon(for: favorite))
                    .resizable()
                    .frame(width: 26, height: 26)
                    .overlay(alignment: .bottom) {
                        Circle()
                            .fill(Color.primary.opacity(isRunning ? 0.6 : 0))
                            .frame(width: 4, height: 4)
                            .offset(y: 5)
                    }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
        }
        .buttonStyle(.plain)
        .help(favorite.name)
        .onHover { isHovered = $0 }
    }
}

private struct IndexBadge: View {
    let index: Int?
    let isSelected: Bool

    var body: some View {
        Group {
            if let index {
                Text(index == 10 ? "0" : "\(index)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                    )
            } else {
                Color.clear
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }
}

enum AppIcons {
    private static var cache: [pid_t: NSImage] = [:]

    static func icon(for pid: pid_t) -> NSImage {
        if let cached = cache[pid] { return cached }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
            ?? NSWorkspace.shared.icon(for: .application)
        cache[pid] = icon
        return icon
    }
}
