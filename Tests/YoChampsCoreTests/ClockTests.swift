import Foundation
import Testing
@testable import YoChampsCore

@Suite("Clock")
struct ClockTests {
    @Test("system clock returns for a zero duration")
    func zeroDurationReturns() async throws {
        try await SystemClock().sleep(for: .zero)
    }

    @Test("system clock sleep throws when its task is cancelled")
    func cancellation() async {
        let clock = SystemClock()
        let task = Task { try await clock.sleep(for: .seconds(10)) }
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}
