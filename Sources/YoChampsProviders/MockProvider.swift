import Foundation
import YoChampsCore

/// Deterministic provider for tests, the offline fallback and `make demo`.
/// It never touches the network and streams the reply one word at a time.
public struct MockProvider: LLMProvider {
    public enum Behavior: Sendable, Equatable {
        /// Streams the answer one word at a time.
        case reply(String)
        /// Fails before emitting any event.
        case failure(LLMError)
    }

    public static let defaultAnswer = "Champ here. This is a mock reply, streamed one word at a time."

    private let behavior: Behavior
    private let chunkDelay: Duration
    private let clock: any Clock

    public init(
        behavior: Behavior = .reply(MockProvider.defaultAnswer),
        chunkDelay: Duration = .zero,
        clock: any Clock = SystemClock()
    ) {
        self.behavior = behavior
        self.chunkDelay = chunkDelay
        self.clock = clock
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        let behavior = behavior
        let chunkDelay = chunkDelay
        let clock = clock

        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    switch behavior {
                    case let .failure(error):
                        throw error
                    case let .reply(answer):
                        let chunks = Self.chunks(of: answer)
                        guard !chunks.isEmpty else {
                            throw LLMError.emptyResponse
                        }
                        for (index, chunk) in chunks.enumerated() {
                            if index > 0 {
                                try await clock.sleep(for: chunkDelay)
                            }
                            continuation.yield(.textDelta(chunk))
                        }
                        continuation.yield(.done)
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    /// Splits on spaces while keeping them, so the deltas rebuild the answer
    /// byte for byte.
    static func chunks(of text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
