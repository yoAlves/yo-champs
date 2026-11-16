import AppKit
import SwiftUI

/// M0 shell: a menu bar item with the final Quit action. Ask, show/hide and
/// settings arrive in M1–M3 and stay disabled until then.
@main
struct YoChampsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Yo Champs", systemImage: "paperclip") {
            Text("Yo Champs 0.0.0 — foundation (M0)")

            Divider()

            Button("Ask… (M1)") {}
                .disabled(true)
            Button("Show Champ (M3)") {}
                .disabled(true)
            Button("Settings… (M2)") {}
                .disabled(true)

            Divider()

            Button("Quit Yo Champs") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; keep the process as an
        // accessory when launched from a terminal or a bare bundle.
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
