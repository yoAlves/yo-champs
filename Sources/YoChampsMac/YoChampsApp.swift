import AppKit
import Combine
import KeyboardShortcuts
import OSLog
import SwiftUI
import YoChampsCore
import YoChampsNetwork
import YoChampsProviders

/// Name registration touches UserDefaults and AppKit state: main actor only.
@MainActor extension KeyboardShortcuts.Name {
    static let ask = Self("ask", default: .init(.y, modifiers: [.command, .option]))
}

/// M2 shell: menu bar item, floating ask panel, real provider conversation,
/// settings/onboarding and JSON history. The character renderer arrives in M3.
@main
struct YoChampsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Yo Champs", systemImage: "paperclip") {
            Text("Yo Champs 0.0.0")

            Divider()

            Button("Ask…") {
                appDelegate.showPanel()
            }
            Button("Show/Hide Champ") {
                appDelegate.toggleMascot()
            }
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

/// Holds the current engine so the view model can resolve it per action.
@MainActor
final class EngineBox {
    var engine: CompanionEngine

    init(engine: CompanionEngine) {
        self.engine = engine
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.yurioliveira.yochamps", category: "app")
    private var panelController: AskPanelController?
    private var settingsController: SettingsPanelController?
    private var mascotController: MascotPanelController?
    private var mascotRenderer: MascotRenderer?
    private var mascotStateCancellable: AnyCancellable?
    private var engineBox: EngineBox?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; keep the process as an
        // accessory when launched from a terminal or a bare bundle.
        NSApplication.shared.setActivationPolicy(.accessory)

        let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        logger.info("launch demo=\(isDemo, privacy: .public)")

        let box = EngineBox(engine: Self.makeEngine())
        engineBox = box
        let model = CompanionViewModel(engineProvider: { box.engine })
        panelController = AskPanelController(
            model: model,
            anchorProvider: { [weak self] in self?.mascotController?.frame }
        )
        setupMascot(model: model)

        // The hotkey opens the Ask bubble through the same path as the menu
        // item, so Esc dismissal and mascot anchoring behave identically.
        KeyboardShortcuts.onKeyDown(for: .ask) { [weak self] in
            Task { @MainActor in
                self?.showPanel()
            }
        }

        let configStore = ProviderConfigFileStore()
        settingsController = SettingsPanelController(
            store: configStore,
            secrets: KeychainSecretStore(),
            transport: URLSessionLLMTransport(),
            onSaved: { [weak self] in
                self?.reloadEngine()
            }
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

    func toggleMascot() {
        mascotController?.toggle()
    }

    /// A missing or invalid pack leaves Champ hidden; the rest of the app keeps
    /// working and Settings reports why the default pack was not loaded.
    private func setupMascot(model: CompanionViewModel) {
        do {
            let pack: MascotPack
            switch try MascotPackLoader().load() {
            case let .selected(selected):
                pack = selected
            case let .fallback(fallback, message):
                if !message.isEmpty {
                    logger.info("using default mascot: \(message, privacy: .private)")
                }
                pack = fallback
            }
            let renderer = MascotRenderer(pack: pack)
            mascotRenderer = renderer
            let controller = MascotPanelController(renderer: renderer) {
                // Every hide path — menu or ⌘W — abandons the turn.
                model.stop()
            }
            mascotController = controller

            renderer.setState(model.state)
            mascotStateCancellable = model.$state.sink { [weak self] state in
                Task { @MainActor in
                    self?.mascotRenderer?.setState(state)
                }
            }

            controller.show()
        } catch {
            logger.error("mascot panel unavailable: \(String(describing: error), privacy: .private)")
        }
    }

    /// Settings saved a profile: the next ask must use it, not the engine that
    /// was composed before onboarding.
    private func reloadEngine() {
        guard let engineBox else { return }
        Task { await engineBox.engine.cancel() }
        engineBox.engine = Self.makeEngine()
    }

    private static func makeEngine() -> CompanionEngine {
        let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        let systemPrompt = "You are Champ, a concise desktop companion. "
            + "Answer in one or two sentences, in the user's language."
        let mockAgent = AgentDefinition(
            id: "champ",
            name: "Champ",
            systemPrompt: systemPrompt,
            model: "mock-model"
        )
        if isDemo {
            return CompanionEngine(
                provider: MockProvider(chunkDelay: .milliseconds(40)),
                agent: mockAgent,
                store: InMemoryConversationStore()
            )
        }
        guard let registry = try? ProviderConfigFileStore().loadSync() else {
            return CompanionEngine(
                provider: UnconfiguredProvider(),
                agent: mockAgent,
                store: InMemoryConversationStore()
            )
        }

        let profile = registry.defaultProfile
        let configuration = OpenAICompatibleProvider.Configuration(
            baseURL: profile.baseURL,
            maxRetries: 2,
            retryDelay: .milliseconds(250),
            timeout: .seconds(30)
        )
        let transport = KeychainAuthTransport(
            secrets: KeychainSecretStore(),
            secretRef: profile.secretRef,
            extraHeaders: profile.headers,
            base: URLSessionLLMTransport()
        )
        let provider = OpenAICompatibleProvider(configuration: configuration, transport: transport)
        let agent = AgentDefinition(
            id: profile.id,
            name: profile.label,
            systemPrompt: systemPrompt,
            model: profile.model
        )
        return CompanionEngine(
            provider: provider,
            agent: agent,
            store: FileConversationStore(directory: AppPaths.supportDirectory)
        )
    }
}
