//
//  MenuBarPopover.swift
//  Contexwitch
//
//  All settings live in the menu bar popover.
//

import Carbon.HIToolbox
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarPopover: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general, shortcuts, favorites

        var id: Self { self }
        var title: String {
            switch self {
            case .general: "General"
            case .shortcuts: "Shortcuts"
            case .favorites: "Favorites"
            }
        }
        var icon: String {
            switch self {
            case .general: "gearshape.fill"
            case .shortcuts: "command"
            case .favorites: "star.fill"
            }
        }
    }

    @State private var tab: Tab = .general
    @State private var isTrusted = AX.isTrusted
    @Namespace private var tabNamespace
    private let trustTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            header
            tabBar
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralTab(isTrusted: isTrusted)
                    case .shortcuts: ShortcutsTab()
                    case .favorites: FavoritesTab()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            .scrollIndicators(.never)
            .frame(height: 400)
            footer
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 380)
        .onReceive(trustTimer) { _ in isTrusted = AX.isTrusted }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Switkher")
                    .font(.system(size: 15, weight: .semibold))
                Text("Window & tab switcher")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: openSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .help("Search windows & tabs (\(Preferences.searchShortcut.displayString))")
        }
        .padding(.horizontal, 16)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { tab = item }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tab == item ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background {
                            if tab == item {
                                Capsule()
                                    .fill(Color.primary.opacity(0.1))
                                    .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassSurface(in: Capsule(), interactive: true)
        .padding(.horizontal, 14)
    }

    private var footer: some View {
        HStack {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            Text("Version \(version)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit Switkher") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .glassButtonStyle()
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
    }

    private func openSearch() {
        NSApp.keyWindow?.orderOut(nil)
        DispatchQueue.main.async { SwitcherController.shared.toggleSearch() }
    }
}

// MARK: - Tabs

private struct GeneralTab: View {
    let isTrusted: Bool

    @AppStorage(PrefKey.sortOrder) private var sortOrder = SortOrder.recent
    @AppStorage(PrefKey.groupByApp) private var groupByApp = false
    @AppStorage(PrefKey.trackTabs) private var trackTabs = true
    @AppStorage(PrefKey.replaceCommandTab) private var replaceCommandTab = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 14) {
            if !isTrusted { permissionBanner }

            SettingsCard(title: "Switcher") {
                SettingsRow(icon: "arrow.up.arrow.down", tint: .blue, title: "Sort windows") {
                    Picker("Sort windows", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                RowDivider()
                SettingsRow(icon: "square.grid.2x2.fill", tint: .indigo, title: "Group by app") {
                    Toggle("Group by app", isOn: $groupByApp).labelsHidden()
                }
                RowDivider()
                SettingsRow(icon: "square.on.square", tint: .teal, title: "Track tabs",
                            subtitle: "Browsers, Finder, Terminal, editors. No extensions.") {
                    Toggle("Track tabs", isOn: $trackTabs).labelsHidden()
                }
            }

            SettingsCard(title: "System") {
                SettingsRow(icon: "power", tint: .green, title: "Launch at login") {
                    Toggle("Launch at login", isOn: $launchAtLogin).labelsHidden()
                }
                RowDivider()
                SettingsRow(icon: "command", tint: .gray, title: "Replace ⌘Tab",
                            subtitle: "Use Switkher instead of the app switcher.") {
                    Toggle("Replace ⌘Tab", isOn: $replaceCommandTab).labelsHidden()
                }
                if isTrusted {
                    RowDivider()
                    SettingsRow(icon: "lock.shield.fill", tint: .green, title: "Accessibility") {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility access needed")
                    .font(.system(size: 13, weight: .semibold))
                Text("Required to see and switch windows.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Grant") { AppDelegate.openAccessibilitySettings() }
                .glassButtonStyle(prominent: true)
                .tint(.orange)
                .controlSize(.small)
        }
        .padding(12)
        .glassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ShortcutsTab: View {
    @AppStorage(PrefKey.cycleShortcut) private var cycleShortcut = Shortcut.defaultCycle
    @AppStorage(PrefKey.searchShortcut) private var searchShortcut = Shortcut.defaultSearch
    @AppStorage(PrefKey.longPressKey) private var longPressKey = LongPressKey.option
    @AppStorage(PrefKey.longPressDelay) private var longPressDelay = 0.4

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Keyboard") {
                SettingsRow(icon: "rectangle.stack.fill", tint: .blue, title: "Switch windows",
                            subtitle: "Hold to cycle, release to switch.") {
                    ShortcutRecorder(shortcut: $cycleShortcut)
                }
                RowDivider()
                SettingsRow(icon: "magnifyingglass", tint: .purple, title: "Search windows & tabs") {
                    ShortcutRecorder(shortcut: $searchShortcut)
                }
            }

            SettingsCard(title: "Hold to open") {
                SettingsRow(icon: "hand.tap.fill", tint: .orange, title: "Hold key",
                            subtitle: "Hold on its own to open the switcher.") {
                    Picker("Hold key", selection: $longPressKey) {
                        ForEach(LongPressKey.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if longPressKey != .off {
                    RowDivider()
                    SettingsRow(icon: "timer", tint: .pink, title: "Delay") {
                        HStack(spacing: 8) {
                            Slider(value: $longPressDelay, in: 0.2...1.0, step: 0.05)
                                .frame(width: 110)
                            Text("\(Int(longPressDelay * 1000)) ms")
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }

            TipView(text: "While the switcher is open, keep holding and press **1–9** to jump to a window, or a favorite's **letter** to open its app.")
        }
        .controlSize(.small)
    }
}

private struct FavoritesTab: View {
    @AppStorage(PrefKey.favoriteApps) private var favorites = FavoriteApps()

    var body: some View {
        VStack(spacing: 14) {
            if favorites.items.isEmpty {
                emptyState
            } else {
                SettingsCard(title: "Favorite apps") {
                    let sorted = favorites.items.sorted { $0.letter < $1.letter }
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, favorite in
                        if index > 0 { RowDivider(inset: 12) }
                        favoriteRow(favorite)
                    }
                }
            }

            Button(action: addFavorites) {
                Label("Add Apps…", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle(prominent: true)
            .controlSize(.large)
            .disabled(favorites.items.count >= FavoriteApps.letters.count)

            TipView(text: "Hold the switcher key and press a letter to switch to that app, or launch it. In search, use **⌥ + letter**.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.square.on.square.fill")
                .font(.system(size: 34))
                .foregroundStyle(.yellow.gradient)
            Text("No favorites yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Give your most-used apps a letter to jump to them instantly.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .glassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func favoriteRow(_ favorite: FavoriteApp) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(availableLetters(for: favorite), id: \.self) { letter in
                    Button(letter) { setLetter(letter, for: favorite) }
                }
            } label: {
                Text(favorite.letter)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(width: 26, height: 26)
                    .glassSurface(in: RoundedRectangle(cornerRadius: 8, style: .continuous), interactive: true)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Change letter")

            Image(nsImage: FavoriteIcons.icon(for: favorite))
                .resizable()
                .frame(width: 24, height: 24)
            Text(favorite.name)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.snappy) {
                    favorites.items.removeAll { $0.bundleID == favorite.bundleID }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove \(favorite.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func availableLetters(for favorite: FavoriteApp) -> [String] {
        let taken = Set(favorites.items.filter { $0.bundleID != favorite.bundleID }.map(\.letter))
        return FavoriteApps.letters.filter { !taken.contains($0) }
    }

    private func setLetter(_ letter: String, for favorite: FavoriteApp) {
        guard let index = favorites.items.firstIndex(where: { $0.bundleID == favorite.bundleID }) else { return }
        favorites.items[index].letter = letter
    }

    private func addFavorites() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        // The popover may have closed while the panel was up, so write straight to defaults.
        var updated = Preferences.favoriteApps
        panel.urls.forEach { updated.add(appAt: $0) }
        UserDefaults.standard.set(updated.rawValue, forKey: PrefKey.favoriteApps)
    }
}

// MARK: - Building blocks

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
            VStack(spacing: 0) { content }
                .padding(.vertical, 3)
                .glassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct RowDivider: View {
    var inset: CGFloat = 46

    var body: some View {
        Divider().padding(.leading, inset)
    }
}

private struct TipView: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.yellow)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? "Press keys…" : shortcut.displayString)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 72)
        }
        .glassButtonStyle(prominent: isRecording)
        .controlSize(.small)
        .onDisappear(perform: stopRecording)
        .help(isRecording ? "Press a shortcut, or Esc to cancel" : "Click to record a new shortcut")
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        HotKeyController.shared.isSuspended = true
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(Shortcut.relevantModifiers)
            if Int(event.keyCode) == kVK_Escape, modifiers.isEmpty {
                stopRecording()
                return nil
            }
            guard !modifiers.subtracting(.shift).isEmpty else {
                NSSound.beep()
                return nil
            }
            shortcut = Shortcut(event: event)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        HotKeyController.shared.isSuspended = false
    }
}
