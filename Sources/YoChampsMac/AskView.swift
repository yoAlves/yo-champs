import SwiftUI

struct AskView: View {
    @ObservedObject var model: CompanionViewModel
    let onClose: () -> Void
    let renderer: MascotRenderer
    @ObservedObject var panelState: PanelState

    @FocusState private var isFocused: Bool

    private let placeholder = "The answer streams here. Champ keeps the last turns in this chat."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            transcript

            if let message = model.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            inputRow

            statusRow
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 300)
        .onAppear {
            isFocused = true
        }
        .onChange(of: panelState.showToken) { _, _ in
            isFocused = true
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("CHAMP")
                .font(.caption)
                .fontWeight(.semibold)
                .kerning(1.2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            Spacer()

            Button("New Chat") {
                model.newChat()
            }
            .buttonStyle(.link)
            .disabled(model.isBusy)

            MascotImageView(renderer: renderer, avatarSize: CGSize(width: 36, height: 36))
                .frame(width: 36, height: 36)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.turns.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(model.turns) { turn in
                        // One view per turn: the id used by scrollTo must
                        // belong to the whole block, or long answers stream
                        // below the fold while the question line is pinned.
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USR: \(turn.question)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(turn.answer.isEmpty ? "RESPONSE: …" : "RESPONSE: \(turn.answer)")
                                .font(.callout)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: model.turns.last?.answer) { _, _ in
                scrollToLatest(proxy)
            }
            .onChange(of: model.turns.count) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Ask Champ…", text: $model.question)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { model.ask() }
                .disabled(model.isBusy)
                .accessibilityIdentifier("askTextField")
            Button("Ask") {
                model.ask()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canAsk)
            .accessibilityIdentifier("askSendButton")
        }
    }

    private var statusRow: some View {
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

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        if let id = model.turns.last?.id {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}
