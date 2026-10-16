//
//  SwitcherController.swift
//  Contexwitch
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Owns the switcher panel and drives its two modes:
/// - cycle: opened by a held shortcut; releasing the modifier switches.
/// - search: a sticky panel for typing a query.
final class SwitcherController {
    static let shared = SwitcherController()

    let model = SwitcherViewModel()
    private let indexer = WindowIndexer()
    private lazy var panel: SwitcherPanel = {
        let view = SwitcherView(
            model: model,
            onActivate: { [weak self] in self?.commit() },
            onOpenFavorite: { [weak self] favorite in self?.open(favorite) }
        )
        let panel = SwitcherPanel(contentView: NSHostingView(rootView: view))
        panel.onResignKey = { [weak self] in self?.hide() }
        return panel
    }()

    /// Non-nil while in cycle mode: the modifiers whose release commits the switch.
    private var holdModifiers: NSEvent.ModifierFlags?
    /// Opened by long-pressing a modifier: releasing without choosing anything just closes.
    private var openedByLongPress = false
    private var isRefreshing = false
    private var needsRefresh = false
    private var commitWhenReady = false
    private var monitors: [Any] = []

    var isVisible: Bool { panel.isVisible }

    func cycle(backward: Bool, holdModifiers: NSEvent.ModifierFlags) {
        ModifierLongPressMonitor.shared.cancel()
        if isVisible {
            model.moveSelection(by: backward ? -1 : 1)
            return
        }
        self.holdModifiers = holdModifiers
        show(mode: .cycle(backward: backward))

        // The shortcut was tapped and released before the panel appeared.
        if !NSEvent.modifierFlags.contains(holdModifiers) { commit() }
    }

    func openForLongPress(holdModifiers: NSEvent.ModifierFlags) {
        guard !isVisible else { return }
        self.holdModifiers = holdModifiers
        show(mode: .cycle(backward: false))
        openedByLongPress = true

        if !NSEvent.modifierFlags.contains(holdModifiers) { hide() }
    }

    func toggleSearch() {
        if isVisible, holdModifiers == nil {
            hide()
            return
        }
        holdModifiers = nil
        if isVisible {
            model.beginSearch(with: "")
        } else {
            show(mode: .search)
        }
    }

    /// Indexes windows ahead of time so the first open is instant.
    func prewarm() {
        refresh()
    }

    private func show(mode: SwitcherViewModel.Mode) {
        let frontWindowID = NSWorkspace.shared.frontmostApplication.flatMap {
            RecencyTracker.shared.focusedWindowID(of: $0.processIdentifier)
        }
        model.prepare(mode: mode, frontWindowID: frontWindowID)
        installMonitors()
        panel.present()
        refresh()
    }

    func hide() {
        holdModifiers = nil
        openedByLongPress = false
        commitWhenReady = false
        removeMonitors()
        if panel.isVisible { panel.orderOut(nil) }
    }

    /// Switches to the favorite's most recent window, or launches/reopens it
    /// (like clicking its Dock icon) when it isn't running or has no windows.
    func open(_ favorite: FavoriteApp) {
        hide()
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: favorite.bundleID).first
        if let running, let window = model.mostRecentWindow(pid: running.processIdentifier) {
            WindowActivator.activate(window)
            return
        }
        guard let url = favorite.applicationURL else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func commit() {
        guard let item = model.selectedItem else {
            if isRefreshing, model.isEmpty {
                commitWhenReady = true
            } else {
                hide()
            }
            return
        }
        hide()
        WindowActivator.activate(item)
    }

    private func refresh() {
        guard AX.isTrusted else { return }
        guard !isRefreshing else {
            needsRefresh = true
            return
        }
        isRefreshing = true
        let ownPID = getpid()
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated }
            .map { AppInfo(pid: $0.processIdentifier, name: $0.localizedName ?? "Unknown", bundleID: $0.bundleIdentifier) }

        indexer.refresh(apps: apps, includeTabs: Preferences.trackTabs) { entries in
            Task { @MainActor in
                let controller = SwitcherController.shared
                controller.isRefreshing = false
                controller.model.update(entries: entries, recency: RecencyTracker.shared.stamps)
                if controller.commitWhenReady {
                    controller.commitWhenReady = false
                    controller.commit()
                }
                if controller.needsRefresh {
                    controller.needsRefresh = false
                    controller.refresh()
                }
            }
        }
    }

    // MARK: - Keyboard

    private func installMonitors() {
        guard monitors.isEmpty else { return }
        if let keyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }) {
            monitors.append(keyDown)
        }
        if let localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event.modifierFlags)
            return event
        }) {
            monitors.append(localFlags)
        }
        // Fallback in case the panel didn't receive key status.
        if let globalFlags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event.modifierFlags)
        }) {
            monitors.append(globalFlags)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard let holdModifiers, !flags.contains(holdModifiers) else { return }
        if openedByLongPress, !model.hasUserNavigated {
            hide()
        } else {
            commit()
        }
    }

    private static let digitKeyIndices: [Int: Int] = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
        kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9, kVK_ANSI_0: 10,
        kVK_ANSI_Keypad1: 1, kVK_ANSI_Keypad2: 2, kVK_ANSI_Keypad3: 3, kVK_ANSI_Keypad4: 4, kVK_ANSI_Keypad5: 5,
        kVK_ANSI_Keypad6: 6, kVK_ANSI_Keypad7: 7, kVK_ANSI_Keypad8: 8, kVK_ANSI_Keypad9: 9, kVK_ANSI_Keypad0: 10,
    ]

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        // Digits jump straight to a numbered row: bare while holding the switcher's
        // modifier, or with ⌥/⌘/⌃ in search mode (so plain digits still type).
        if let index = Self.digitKeyIndices[Int(event.keyCode)],
           holdModifiers != nil || !event.modifierFlags.intersection([.option, .command, .control]).isEmpty {
            if model.select(shortcutIndex: index) {
                commit()
            } else {
                NSSound.beep()
            }
            return nil
        }

        // Favorite app letters: bare while holding the switcher's modifier, or with ⌥ in
        // search mode. Unassigned letters fall through and start a search as before.
        if let letter = event.charactersIgnoringModifiers?.uppercased(), FavoriteApps.letters.contains(letter),
           holdModifiers != nil || event.modifierFlags.contains(.option),
           let favorite = Preferences.favoriteApps.favorite(for: letter) {
            open(favorite)
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            if holdModifiers == nil, !model.query.isEmpty {
                model.query = ""
            } else {
                hide()
            }
            return nil
        case kVK_Return, kVK_ANSI_KeypadEnter:
            commit()
            return nil
        case kVK_DownArrow:
            model.moveSelection(by: 1)
            return nil
        case kVK_UpArrow:
            model.moveSelection(by: -1)
            return nil
        case kVK_Tab:
            model.moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
            return nil
        case kVK_RightArrow where model.query.isEmpty:
            return model.setSelectionExpanded(true) ? nil : event
        case kVK_LeftArrow where model.query.isEmpty:
            return model.setSelectionExpanded(false) ? nil : event
        default:
            break
        }

        // Typing while holding the cycle shortcut turns the panel into a search.
        if holdModifiers != nil {
            if let characters = event.charactersIgnoringModifiers, !characters.isEmpty,
               characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                holdModifiers = nil
                model.beginSearch(with: characters)
            }
            return nil
        }
        return event
    }
}
