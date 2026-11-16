import Foundation
@testable import YoChampsCore

/// Records requested sleeps without waiting, so pacing is asserted without
/// real time passing.
actor RecordingClock: Clock {
    private(set) var sleeps: [Duration] = []

    func sleep(for duration: Duration) async throws {
        sleeps.append(duration)
    }
}

/// Blocks every sleep for far longer than any test, and reports when a sleep
/// was interrupted by cancellation. That report is how tests prove the
/// producer task was actually cancelled instead of leaking.
actor BlockingClock: Clock {
    private var cancelObserved = false
    private var waiter: CheckedContinuation<Void, Never>?

    func sleep(for duration: Duration) async throws {
        do {
            try await Task.sleep(for: .seconds(600))
        } catch {
            cancelObserved = true
            waiter?.resume()
            waiter = nil
            throw error
        }
    }

    func waitForCancellation() async {
        if cancelObserved {
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }
}

actor DeltaRecorder {
    private(set) var deltas: [String] = []

    func append(_ delta: String) {
        deltas.append(delta)
    }
}

actor FirstDeltaSignal {
    private var fired = false
    private var waiter: CheckedContinuation<Void, Never>?

    func fire() {
        guard !fired else { return }
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
