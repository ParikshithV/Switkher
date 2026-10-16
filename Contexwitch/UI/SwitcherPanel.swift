//
//  SwitcherPanel.swift
//  Contexwitch
//

import AppKit

/// A borderless, non-activating floating panel: it takes keyboard input
/// without making Contexwitch the active app, so focus never flickers.
final class SwitcherPanel: NSPanel {
    static let size = NSSize(width: 640, height: 440)
    static let cornerRadius: CGFloat = 22

    var onResignKey: (() -> Void)?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none
        contentView.frame = NSRect(origin: .zero, size: Self.size)
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    func present() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = NSPoint(
                x: visible.midX - Self.size.width / 2,
                y: max(visible.minY, visible.minY + visible.height * 0.6 - Self.size.height / 2)
            )
            setFrameOrigin(origin)
        }
        makeKeyAndOrderFront(nil)
    }
}
