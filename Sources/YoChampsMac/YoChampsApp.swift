import AppKit
import OSLog
import SwiftUI
import YoChampsCore
import YoChampsProviders

/// M1 shell: menu bar item, floating ask panel, mock conversation loop.
/// Settings (M2) and the character renderer (M3) stay disabled until then.
@main
struct YoChampsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Yo Champs", systemImage: "paperclip") {
            Text("Yo Champs 0.0.0 — conversation loop (M1)")

            Divider()

            Button("Ask…") {
                appDelegate.showPanel()
            }
            Button("Show Champ (M3)") {}
                .disabled(true)
            Button("Settings…") {
                appDelegate.showSettings()
            }

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
    private let logger = Logger(subsystem: "com.yurioliveira.yochamps", category: "app")
    private var panelController: AskPanelController?
    private var settingsController: SettingsPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; keep the process as an
        // accessory when launched from a terminal or a bare bundle.
        NSApplication.shared.setActivationPolicy(.accessory)

        let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        logger.info("launch demo=\(isDemo, privacy: .public)")

        let model = CompanionViewModel(engine: Self.makeEngine())
        panelController = AskPanelController(model: model)

        let configStore = ProviderConfigFileStore()
        settingsController = SettingsPanelController(
            store: configStore,
            secrets: KeychainSecretStore(),
            transport: URLSessionLLMTransport()
        )
        if isDemo {
            panelController?.showDemo()
        } else {
            panelController?.show()
            // No profile yet: onboarding is the first thing the user sees.
            // An unreadable config is reported, never mistaken for onboarding.
            Task { [weak self] in
                guard let self else { return }
                do {
                    if try await configStore.load() == nil {
                        settingsController?.show()
                    }
                } catch {
                    logger.error("config load failed: \(String(describing: error), privacy: .private)")
                    settingsController?.show()
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.info("reopen")
        showPanel()
        return true
    }

    /// `yochamps://open` from Spotlight, Raycast, Alfred or a shortcut.
    func application(_ application: NSApplication, open urls: [URL]) {
        let schemes = urls.map { $0.scheme ?? "none" }.joined(separator: ",")
        logger.info("url open schemes=\(schemes, privacy: .public)")
        guard urls.contains(where: { $0.scheme == "yochamps" }) else {
            return
        }
        showPanel()
    }

    func showPanel() {
        panelController?.show()
    }

    func showSettings() {
        settingsController?.show()
    }

    private static func makeEngine() -> CompanionEngine {
        let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        let systemPrompt = "You are Champ, a concise desktop companion. "
            + "Answer in one or two sentences, in the user's language."
        return CompanionEngine(
            provider: MockProvider(chunkDelay: isDemo ? .milliseconds(40) : .zero),
            agent: AgentDefinition(
                id: "champ",
                name: "Champ",
                systemPrompt: systemPrompt,
                model: "mock-model"
            )
        )
    }
}
