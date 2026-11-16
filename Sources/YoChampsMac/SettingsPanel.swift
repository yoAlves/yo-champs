import AppKit
import SwiftUI
import YoChampsCore
import YoChampsProviders

@MainActor
final class SettingsPanelController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: SettingsViewModel

    init(
        store: ProviderConfigFileStore,
        secrets: any SecretStore,
        transport: any LLMHTTPTransport
    ) {
        model = SettingsViewModel(store: store, secrets: secrets, transport: transport)
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(model: model) { [weak self] in
            self?.close()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Yo Champs Settings"
        window.delegate = self
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    func close() {
        model.stop()
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.stop()
        window = nil
    }
}
