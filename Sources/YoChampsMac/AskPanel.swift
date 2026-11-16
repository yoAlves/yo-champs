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

@MainActor
final class AskPanelController {
    private let panel: AskPanel
    private let model: CompanionViewModel

    init(model: CompanionViewModel) {
        self.model = model
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
        panel.contentView = NSHostingView(
            rootView: AskView(model: model, onClose: { [weak self] in self?.hide() })
        )
        panel.onEscape = { [weak self] in self?.hide() }
        panel.center()
    }

    func show() {
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// `make demo`: open the panel with a fixture question, streamed slowly
    /// enough to watch.
    func showDemo() {
        show()
        model.ask("What can you do?")
    }

    func hide() {
        model.stop()
        panel.orderOut(nil)
    }
}
