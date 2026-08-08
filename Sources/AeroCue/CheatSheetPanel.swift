import Cocoa
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.hodgy.aerocue", category: "Panel")

/// A borderless, non-activating floating panel that hosts the SwiftUI cheat sheet.
/// Non-activating means showing it never steals focus or switches Spaces away
/// from whatever the user was doing while holding Option.
final class CheatSheetController {
    private var panel: NSPanel?

    func show() {
        let bindings = AerospaceConfig.loadBindings()
        let modes = CheatSheetBuilder.build(from: bindings)
        let path = AerospaceConfig.locate()?.path

        let screen = activeScreen()
        let size = panelSize(for: screen)

        let view = CheatSheetView(
            modes: modes,
            configPath: path,
            size: size,
            onDismiss: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = panel ?? makePanel()
        panel.contentView = hosting
        panel.setContentSize(size)
        center(panel, on: screen)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        logger.notice("""
            show: bindings=\(bindings.count, privacy: .public) \
            screenFrame=\(String(describing: screen?.frame), privacy: .public) \
            visibleFrame=\(String(describing: screen?.visibleFrame), privacy: .public) \
            size=\(String(describing: size), privacy: .public) \
            panelFrame=\(String(describing: panel.frame), privacy: .public) \
            visible=\(panel.isVisible, privacy: .public) \
            alpha=\(panel.alphaValue, privacy: .public) \
            level=\(panel.level.rawValue, privacy: .public)
            """)
    }

    /// Fills most of the current display rather than a fixed size, so wide
    /// monitors lay the categories out side by side instead of forcing a scroll.
    /// `visibleFrame` already excludes the menu bar and Dock.
    private func panelSize(for screen: NSScreen?) -> NSSize {
        guard let screen else { return NSSize(width: 900, height: 620) }
        let vf = screen.visibleFrame
        return NSSize(width: (vf.width * 0.92).rounded(), height: (vf.height * 0.90).rounded())
    }

    func hide() {
        logger.notice("hide: visible=\(self.panel?.isVisible ?? false, privacy: .public)")
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = false
        return p
    }

    private func activeScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    private func center(_ panel: NSPanel, on screen: NSScreen?) {
        guard let screen else { return }
        let vf = screen.visibleFrame
        let pf = panel.frame
        panel.setFrameOrigin(NSPoint(x: vf.midX - pf.width / 2, y: vf.midY - pf.height / 2))
    }
}
