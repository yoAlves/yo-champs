import Foundation
@testable import YoChampsCore

final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [LLMRequest] = []

    var requests: [LLMRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ request: LLMRequest) {
        lock.lock()
        recorded.append(request)
        lock.unlock()
    }
}

/// Provider double whose reply, failure and blocking modes are chosen per test.
/// `blockingReply` yields the first chunk and then sleeps far past any test, so
/// engine cancellation has a deterministic window to interrupt.
struct SpyProvider: LLMProvider {
    enum Behavior: Sendable {
        case reply([String])
        case failure(LLMError)
        case blockingReply([String])
    }

    let recorder: RequestRecorder
    let behavior: Behavior
    let termination: TerminationRecorder?

    init(
        recorder: RequestRecorder = RequestRecorder(),
        behavior: Behavior,
        termination: TerminationRecorder? = nil
    ) {
        self.recorder = recorder
        self.behavior = behavior
        self.termination = termination
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        recorder.record(request)
        let behavior = behavior

        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    switch behavior {
                    case let .failure(error):
                        throw error
                    case let .reply(chunks):
                        for chunk in chunks {
                            continuation.yield(.textDelta(chunk))
                        }
                        continuation.yield(.done)
                        continuation.finish()
                    case let .blockingReply(chunks):
                        for (index, chunk) in chunks.enumerated() {
                            if index > 0 {
                                try await Task.sleep(for: .seconds(600))
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
            continuation.onTermination = { _ in
                producer.cancel()
                if let termination {
                    Task { await termination.record() }
                }
            }
        }
    }
}

actor TerminationRecorder {
    private var count = 0
    private var waiter: CheckedContinuation<Void, Never>?

    func record() {
        count += 1
        waiter?.resume()
        waiter = nil
    }

    func wait() async {
        if count > 0 {
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }
}

actor EventRecorder {
    private(set) var events: [CompanionEvent] = []

    func append(_ event: CompanionEvent) {
        events.append(event)
    }
}

actor TextDeltaSignal {
    private var fired = false
    private var waiter: CheckedContinuation<Void, Never>?

    func fire() {
        guard !fired else {
            return
        }
        fired = true
        waiter?.resume()
        waiter = nil
    }

    func wait() async {
        if fired {
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }
}
