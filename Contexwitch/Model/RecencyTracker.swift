//
//  RecencyTracker.swift
//  Contexwitch
//

import AppKit

/// Tracks the most-recently-used order of windows by watching focus changes.
final class RecencyTracker {
    static let shared = RecencyTracker()

    private(set) var stamps: [CGWindowID: Int] = [:]
    private var counter = 0
    private var observers: [pid_t: AXObserver] = [:]
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        for id in WindowIndexer.frontToBackWindowIDs().reversed() { bump(id) }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated {
                RecencyTracker.shared.attach(pid)
                RecencyTracker.shared.bumpFocusedWindow(of: pid)
            }
        }
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { RecencyTracker.shared.attach(pid) }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { RecencyTracker.shared.detach(pid) }
        }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            attach(app.processIdentifier)
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            bumpFocusedWindow(of: front.processIdentifier)
        }
    }

    func bump(_ windowID: CGWindowID?) {
        guard let windowID else { return }
        counter += 1
        stamps[windowID] = counter
    }

    func focusedWindowID(of pid: pid_t) -> CGWindowID? {
        let app = AXUIElementCreateApplication(pid)
        return AX.element(app, kAXFocusedWindowAttribute).flatMap(PrivateAPI.windowID(of:))
    }

    private func bumpFocusedWindow(of pid: pid_t) {
        bump(focusedWindowID(of: pid))
    }

    private func attach(_ pid: pid_t) {
        guard observers[pid] == nil, pid != getpid() else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, recencyObserverCallback, &observer) == .success, let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        let added = [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification].map {
            AXObserverAddNotification(observer, app, $0 as CFString, nil) == .success
        }
        // The app may not be ready yet right after launch; retry on next activation.
        guard added.contains(true) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func detach(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
}

private nonisolated func recencyObserverCallback(
    _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
    let windowID = PrivateAPI.windowID(of: element)
    MainActor.assumeIsolated { RecencyTracker.shared.bump(windowID) }
}
