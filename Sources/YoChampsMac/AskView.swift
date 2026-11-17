import SwiftUI

struct AskView: View {
    @ObservedObject var model: CompanionViewModel
    let onClose: () -> Void
    @ObservedObject var renderer: MascotRenderer
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

            HStack(spacing: 6) {
                Button {
                    model.newChat()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .frame(width: 24, height: 24)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .help("New Chat")
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.isBusy)
                .accessibilityIdentifier("newChatButton")
            }

            if let image = renderer.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("mascotPanel")
                    .padding(.trailing, 4)
            }
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
                            Text(turn.question)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isWaitingForFirstToken(turn) {
                                ThinkingIndicator()
                            } else {
                                Text("• \(turn.answer)")
                                    .font(.callout)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
            // Stays enabled while a turn runs so keyboard focus never leaves
            // the field; sending mid-turn stays blocked by `canAsk`/`ask()`.
            TextField("Ask Champ…", text: $model.question)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { model.ask() }
                .accessibilityIdentifier("askTextField")
            Button("Ask") {
                model.ask()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canAsk)
            .accessibilityIdentifier("askSendButton")

            if model.isBusy {
                Button {
                    model.cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 24, height: 24)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .help("Cancel")
                .accessibilityLabel("Cancel")
                .accessibilityIdentifier("cancelButton")
                .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            }
        }
        // The cancel button only exists while a turn runs, so both its
        // insertion and removal must slide the field and Ask out of the way.
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.isBusy)
    }

    /// The pulsing dot stands in for the answer line from `ask()` until the
    /// first token streams; only the newest turn can be waiting. Pending is
    /// set synchronously by `ask()`, so the row never flashes the bare bullet
    /// while the engine's async `.thinking` event is still in flight.
    private func isWaitingForFirstToken(_ turn: CompanionViewModel.ChatTurn) -> Bool {
        turn.isPending && turn.answer.isEmpty && turn.id == model.turns.last?.id
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        if let id = model.turns.last?.id {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}

/// Pulsing dot + waiting line shown where the answer will stream, replacing
/// the old "Thinking…" caption. The line is drawn once per view lifetime, so
/// streaming re-renders never swap it mid-wait.
private struct ThinkingIndicator: View {
    @State private var phrase = WaitingLines.draw()
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(.secondary)
                .frame(width: 7, height: 7)
                .scaleEffect(pulsing ? 1.35 : 1)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: pulsing
                )
            Text(phrase)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .onAppear { pulsing = true }
        // Re-arm so the pulse restarts if the row was recycled or the
        // animation was cancelled while off-screen.
        .onDisappear { pulsing = false }
    }
}

/// Short waiting lines shown next to the thinking dot; one is drawn at
/// random per appearance.
private enum WaitingLines {
    static let all = [
        "Consulting the paperclip council…",
        "Untangling my thoughts…",
        "Sharpening my best point…",
        "Folding ideas like paper…",
        "Warming up the mimeograph…",
        "Straightening out my wire…",
        "Fishing through the desk drawer…",
        "Untwisting a stray thought…",
        "Asking the sticky notes…",
        "Leafing through the manual…",
        "Bending into thinking shape…",
        "Reading between the staples…",
        "Shuffling mental index cards…",
        "Dusting off the dictionary…",
        "Cross-referencing folder tabs…",
        "Pinning down the answer…",
        "Skimming the fine print…",
        "Warming up the typewriter…",
        "Loading from the floppy disk…",
        "Thinking in lowercase…",
        "Herding loose thoughts…",
        "Stretching my wire a little…",
        "Bouncing ideas off the desk…",
        "Flipping through mental stickies…",
        "Rattling the pen cup…",
        "Marinating on it…",
        "Squinting at the question…",
        "Turning it over twice…",
        "Quietly panicking (politely)…",
        "Asking the rubber band…",
        "Consulting the manila folder…",
        "Rewinding the cassette…",
        "Blowing dust off the archive…",
        "Ironing out the kinks…",
        "Connecting dots and loops…",
        "Following the dotted line…",
        "Holding it all together…",
        "Running the numbers, slowly…",
        "Combing the margins…",
        "Double-checking the drawer…",
        "Winding up the spring…",
        "Recruiting binder clips…",
        "Proofreading the silence…",
        "Whispering to the stapler…",
        "Counting to ten in binary…",
        "Brewing a fresh thought…",
        "Sharpening a pencil for scale…",
        "Squaring the paper stack…",
        "Reading the label upside down…",
        "Following the paper trail…",
        "Poking the cosmos, gently…",
        "Doodling in the margins…",
        "Unfolding the question…",
        "Refolding for a better grip…",
        "Listening to the office hum…",
        "Rolling the idea downhill…",
        "Looking under the keyboard…",
        "Checking the lost-and-found…",
        "Flexing some context…",
        "Weighing words on a ruler…",
        "Bringing in the big paperclips…",
        "Fluorescent-light thinking…",
        "Hm. Hm hm. Hmmm…",
        "Opening the mental cabinet…",
        "Digging through the outbox…",
        "Peeling a fresh sticky note…",
        "Sniffing out the answer…",
        "Aligning to the grid…",
        "Jiggling the mouse for luck…",
        "Aiming for conciseness…",
        "Dodging the paper shredder…",
        "Reading the toner leaves…",
        "Counting paperclips twice…",
        "Double-looping the logic…",
        "Sorting thoughts A to Z…",
        "Marking the thought urgent…",
        "Keeping the pages in order…",
        "Nearly there, probably…",
        "Borrowing the stapler's wisdom…",
        "Tracing the fold lines…",
        "Warming up the carriage return…",
        "Squaring up the question…",
        "One wire, many ideas…",
        "Margin notes, mostly doodles…",
        "Taping thoughts to the wall…",
        "Erasing twice, writing once…",
        "Grinding the gears of thought…",
        "Checking twice, clipping once…",
        "Rolling out the thinking carpet…",
        "Sifting the paper scraps…",
        "Stretching the band of logic…",
        "Removing a staple of doubt…",
        "Flattening the creases…",
        "Opening a fresh ream of ideas…",
        "Waving at the cursor…",
        "Taking the scenic route…",
        "Sharpening the obvious…",
        "Threading the needle, hopefully…",
        "Warming my wires for the answer…",
        "Rounding up loose wires…",
    ]

    static func draw() -> String {
        all.randomElement() ?? "Thinking…"
    }
}
