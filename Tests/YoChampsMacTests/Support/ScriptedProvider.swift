import Foundation
import YoChampsCore

/// Provider double whose replies are chosen per test. Each `stream` call
/// plays the next mode in order. `block` yields one chunk, then sleeps far
/// past any test so cancellation has a deterministic window.
final class ScriptedProvider: LLMProvider, @unchecked Sendable {
    enum Mode: Sendable {
        case reply([String])
        case block(chunk: String)
    }

    private let modes: [Mode]
    private let lock = NSLock()
    private var index = 0

    init(_ modes: [Mode]) {
        self.modes = modes
    }

    convenience init(_ mode: Mode) {
        self.init([mode])
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        lock.lock()
        let mode = modes[min(index, modes.count - 1)]
        index += 1
        lock.unlock()

        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    switch mode {
                    case let .reply(chunks):
                        for chunk in chunks {
                            continuation.yield(.textDelta(chunk))
                        }
                        continuation.yield(.done)
                        continuation.finish()
                    case let .block(chunk):
                        continuation.yield(.textDelta(chunk))
                        try await Task.sleep(for: .seconds(600))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }
}
