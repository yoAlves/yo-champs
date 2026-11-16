import SwiftUI

struct AskView: View {
    @ObservedObject var model: CompanionViewModel
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    private let placeholder = "The answer streams here. Champ keeps the last turns in this chat."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Champ")
                    .font(.headline)
                Spacer()
                Button("New Chat") {
                    model.newChat()
                }
                .buttonStyle(.link)
                .disabled(model.isBusy)
            }

            HStack(spacing: 8) {
                TextField("Ask Champ…", text: $model.question)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { model.ask() }
                    .disabled(model.isBusy)
                Button("Ask") {
                    model.ask()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canAsk)
            }

            Divider()

            ScrollView {
                Text(model.answer.isEmpty ? placeholder : model.answer)
                    .foregroundStyle(model.answer.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            if let message = model.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Text(model.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isBusy {
                    Button("Cancel") {
                        model.cancel()
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 360, minHeight: 260)
        .onAppear {
            isFocused = true
        }
        .onExitCommand(perform: onClose)
    }
}
