import AppKit
import SwiftUI

/// Floating ask panel. Borderless-ish chrome keeps it close to the final
/// bubble; placement and translucency arrive in M3. Champ is embedded in the
/// hosted `AskView`, not anchored to a separate window.
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
    private let panel: AskPanel
    private let model: CompanionViewModel
    private let closeHandler: PanelCloseHandler
    private let renderer: MascotRenderer

    init(model: CompanionViewModel, renderer: MascotRenderer) {
        self.model = model
        self.renderer = renderer
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
        // NSPanel defaults to true; a summoned panel must stay on screen while
        // the app is inactive (activation lands a beat after the hotkey).
        panel.hidesOnDeactivate = false

        // Kept alive by the controller: NSWindow.delegate is weak.
        panel.delegate = closeHandler

        let hidePanel: () -> Void = { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: AskView(model: model, onClose: hidePanel, renderer: renderer))
        panel.onEscape = hidePanel
        panel.center()
    }

    func show() {
        NSApplication.shared.activate()
        panel.center()
        renderer.setHidden(false)
        panel.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// `make demo`: open the panel with a fixture question, streamed slowly
    /// enough to watch.
    func showDemo() {
        show()
        model.ask("What can you do?")
    }

    private func hide() {
        model.stop()
        renderer.setHidden(true)
        panel.orderOut(nil)
    }
}
