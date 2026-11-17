import AppKit
import SwiftUI

/// The single Ask window: one floating `NSPanel` hosts the chat transcript,
/// the input row and the embedded Champ avatar (ADR 0012). There is no
/// separate mascot window.
final class AskPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onBecomeKey: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    /// Key status lands a beat after summon (the app activates asynchronously),
    /// so focus must be driven from this event, not from `show()`.
    override func becomeKey() {
        super.becomeKey()
        onBecomeKey?()
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Carried by the panel controller into `AskView`; each `show()` bumps the
/// token so the view can re-focus the field. A counter, not a flag: the red
/// close button bypasses `hide()`, so a boolean could stay `true`.
@MainActor
final class PanelState: ObservableObject {
    @Published var showToken = 0
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
    private let panelState = PanelState()
    /// Var (not `let`): the init captures `self` in closures before the
    /// observer is registered at the end, and Swift definite initialization
    /// forbids capturing `self` before every stored property is initialized.
    /// Optionals are nil by default, which satisfies that rule.
    /// Lives for the controller's lifetime (the AppDelegate retains the
    /// controller for the app's lifetime).
    private var activationObserver: (any NSObjectProtocol)?

    init(model: CompanionViewModel, renderer: MascotRenderer) {
        self.model = model
        self.renderer = renderer
        closeHandler = PanelCloseHandler { model.stop() }

        panel = AskPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
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

        // Resizable with the persisted frame as the lower bound: the request
        // is to grow the panel, not to shrink it below today's default.
        panel.contentMinSize = NSSize(width: 380, height: 300)
        // AppKit saves the frame (size and position) on every move/resize and
        // restores it here, across launches; `show()` only re-centers when the
        // saved frame is not on any connected screen.
        panel.setFrameAutosaveName("AskPanel")

        let hidePanel: () -> Void = { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: AskView(
            model: model,
            onClose: hidePanel,
            renderer: renderer,
            panelState: panelState
        ))
        panel.onEscape = hidePanel
        // Covers the first summon, when the app is still inactive at `show()`:
        // the bump from `show()` lands while the panel is not key yet and the
        // focus set is a no-op; this one fires when the window actually
        // becomes key, after activation completes.
        panel.onBecomeKey = { [weak self] in
            self?.panelState.showToken += 1
        }

        // Activation refused at summon time (accessory app, macOS focus-steal
        // prevention) can complete a beat later; the key request made in
        // `show()` does not survive that gap. Re-order the visible panel once
        // the app actually becomes active so it can become key.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.raisePanelIfVisible()
            }
        }
    }

    func show() {
        // The plain activate() is refused for an inactive accessory app under
        // macOS focus-steal prevention; this variant is the supported path
        // for menu-bar apps summoned by hotkey (deprecated but functional).
        NSApplication.shared.activate(ignoringOtherApps: true)
        // The restored frame can live on a screen that is no longer connected;
        // re-center once so the panel is never summoned off-screen.
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            panel.center()
        }
        renderer.setHidden(false)
        panel.makeKeyAndOrderFront(nil)
        panelState.showToken += 1
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

    private func raisePanelIfVisible() {
        guard panel.isVisible, !panel.isKeyWindow else { return }
        panel.makeKeyAndOrderFront(nil)
    }
}
