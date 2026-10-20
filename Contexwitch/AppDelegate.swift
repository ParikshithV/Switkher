//
//  AppDelegate.swift
//  Contexwitch
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var trustTimer: Timer?
    private var servicesStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        Preferences.enableLaunchAtLoginOnFirstRun()
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.3)
        HotKeyController.shared.apply()

        // Capture self directly: with @NSApplicationDelegateAdaptor, NSApp.delegate is
        // SwiftUI's proxy, not this class.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }

        if AX.isTrusted {
            startServices()
        } else {
            showOnboarding()
        }
    }

    private func startServices() {
        guard !servicesStarted else { return }
        servicesStarted = true
        RecencyTracker.shared.start()
        applyPreferences()
        SwitcherController.shared.prewarm()
    }

    private func applyPreferences() {
        HotKeyController.shared.apply()
        if servicesStarted {
            ModifierLongPressMonitor.shared.apply()
            let replace = Preferences.replaceCommandTab
            if replace != CommandTabInterceptor.shared.isEnabled {
                CommandTabInterceptor.shared.setEnabled(replace)
            }
        }
    }

    // MARK: - Windows

    private func showOnboarding() {
        let window = makeWindow(title: "Switkher", content: OnboardingView())
        onboardingWindow = window
        present(window)

        // Keeps polling even if the window is closed, so services start whenever access is granted.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkTrust() }
        }
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer
    }

    private func checkTrust() {
        guard AX.isTrusted else { return }
        trustTimer?.invalidate()
        trustTimer = nil
        onboardingWindow?.close()
        onboardingWindow = nil
        startServices()
    }

    private func makeWindow(title: String, content: some View) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private static var hasPromptedForTrust = false

    /// The first time, shows the system prompt, which adds Switkher to the Accessibility
    /// list and offers to open System Settings. After that, opens the pane directly so the
    /// prompt doesn't stack on top of System Settings.
    static func openAccessibilitySettings() {
        if !hasPromptedForTrust {
            hasPromptedForTrust = true
            AX.requestTrust()
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
