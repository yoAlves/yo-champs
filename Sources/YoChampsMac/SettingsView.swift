import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.isOnboarding ? "Set up Champ" : "Provider Settings")
                .font(.headline)

            if model.isOnboarding {
                Text("No provider is configured. Add an OpenAI-compatible endpoint to start asking.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let mascotStatus = model.mascotStatus {
                Text(mascotStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Form {
                TextField("Base URL (https://…/v1)", text: $model.baseURL)
                TextField("Model", text: $model.model)
                SecureField("API key (stored in Keychain)", text: $model.apiKey)
                if model.hasStoredKey, model.apiKey.isEmpty {
                    Text("A key is already stored — leave blank to keep it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Key reference", text: $model.secretRef)
                    .disabled(true)
                TextEditor(text: $model.headers)
                    .frame(height: 64)
                Text("Extra headers, one per line: Name: value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = model.message {
                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(message.isError ? .red : .green)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Test Connection") {
                    model.testConnection()
                }
                .disabled(model.isWorking)
                Spacer()
                Button("Cancel", action: onClose)
                Button("Save") {
                    model.save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking)
            }
        }
        .padding(16)
        .frame(width: 440)
        .onAppear {
            Task { await model.load() }
        }
        .onExitCommand(perform: onClose)
    }
}
