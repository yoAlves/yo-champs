import Foundation
import Testing
@testable import YoChampsCore

@Suite("CompanionState")
struct CompanionStateTests {
    @Test("raw values are the stable wire format")
    func rawValues() {
        #expect(CompanionState.allCases.map(\.rawValue) == [
            "idle", "thinking", "streaming", "happy", "confused", "error",
        ])
    }

    @Test("codable round-trip keeps the state")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(CompanionState.streaming)
        #expect(try JSONDecoder().decode(CompanionState.self, from: data) == .streaming)
    }
}
