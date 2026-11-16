import Testing
import YoChampsCore

/// The provider behaviour both the mock and the real client must satisfy.
enum ProviderContract {
    static func streamsAnswer(
        _ provider: any LLMProvider,
        request: LLMRequest,
        expectedDeltas: [String]
    ) async throws {
        var events: [LLMEvent] = []
        for try await event in provider.stream(request) {
            events.append(event)
        }

        let deltas = events.compactMap { event -> String? in
            guard case let .textDelta(delta) = event else { return nil }
            return delta
        }
        #expect(deltas == expectedDeltas)
        #expect(events.last == .done)
        #expect(events.filter { $0 == .done }.count == 1)
    }

    static func failure(
        _ provider: any LLMProvider,
        request: LLMRequest,
        expected: LLMError
    ) async {
        var events: [LLMEvent] = []
        var caught: LLMError?
        do {
            for try await event in provider.stream(request) {
                events.append(event)
            }
        } catch {
            caught = error as? LLMError
        }

        let deltas = events.compactMap { event -> String? in
            guard case let .textDelta(delta) = event else { return nil }
            return delta
        }
        #expect(caught == expected)
        #expect(deltas.isEmpty)
        #expect(!events.contains(.done))
    }

    static func emptyResponse(_ provider: any LLMProvider, request: LLMRequest) async {
        await failure(provider, request: request, expected: .emptyResponse)
    }
}
