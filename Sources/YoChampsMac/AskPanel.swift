import AppKit
import SwiftUI

/// Floating ask panel. Borderless-ish chrome keeps it close to the final
/// bubble; placement, translucency and the mascot anchor arrive in M3.
final class AskPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Single dismissal hook for the close button and ⌘W. Esc goes through
/// `AskPanel.cancelOperation`, which calls `hide()` directly; every path must
/// reach the view model so a dismissed turn cannot keep streaming.
@MainActor
final class PanelCloseHandler: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
final class AskPanelController {
    private static let gap: CGFloat = 12

    private let panel: AskPanel
    private let model: CompanionViewModel
    private let closeHandler: PanelCloseHandler
    private let anchorProvider: () -> NSRect?

    init(model: CompanionViewModel, anchorProvider: @escaping () -> NSRect?) {
        self.model = model
        self.anchorProvider = anchorProvider
        closeHandler = PanelCloseHandler { model.stop() }

        panel = AskPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Ask Champ"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Kept alive by the controller: NSWindow.delegate is weak.
        panel.delegate = closeHandler

        let hidePanel: () -> Void = { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: AskView(model: model, onClose: hidePanel))
        panel.onEscape = hidePanel
        panel.center()
    }

    func show() {
        NSApplication.shared.activate()
        positionNearMascot()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Open beside Champ's trailing edge, vertically centred on the screen the
    /// mascot occupies. A nil anchor keeps the bubble in its centred position.
    private func positionNearMascot() {
        guard let anchor = anchorProvider() else {
            panel.center()
            return
        }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let size = panel.frame.size
        let maxX = visible.maxX - min(size.width, visible.width)
        let maxY = visible.maxY - min(size.height, visible.height)
        let origin = NSPoint(
            x: min(max(anchor.maxX + Self.gap, visible.minX), maxX),
            y: min(max(anchor.midY - size.height / 2, visible.minY), maxY)
        )
        panel.setFrameOrigin(origin)
    }

    /// `make demo`: open the panel with a fixture question, streamed slowly
    /// enough to watch.
    func showDemo() {
        show()
        model.ask("What can you do?")
    }

    private func hide() {
        model.stop()
        panel.orderOut(nil)
    }
}
