//
//  FloatingWindowController.swift
//  Aumeno
//
//  Created by Claude Code
//

import Cocoa
import SwiftUI

final class FloatingWindowController: NSWindowController {
    convenience init<Content: View>(
        rootView: Content,
        size: NSSize = NSSize(width: 500, height: 600)
    ) {
        let window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        // Center window
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - size.width / 2
            let y = screenRect.midY - size.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Set SwiftUI content
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView

        self.init(window: window)
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }
}

// Custom NSPanel subclass for floating behavior
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Enable window dragging
        self.performDrag(with: event)
    }
}
