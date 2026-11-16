import Foundation
import Testing
@testable import YoChampsCore

@Suite("LLM contracts")
struct LLMContractsTests {
    @Test("message codable round-trip preserves role and content")
    func messageRoundTrip() throws {
        let message = LLMMessage(role: .assistant, content: "hi")
        let data = try JSONEncoder().encode(message)
        #expect(try JSONDecoder().decode(LLMMessage.self, from: data) == message)
    }

    @Test("request defaults leave optional sampling fields empty")
    func requestDefaults() {
        let request = LLMRequest(model: "test-model", messages: [.init(role: .user, content: "hello")])
        #expect(request.maxTokens == nil)
        #expect(request.temperature == nil)
        #expect(request.headers.isEmpty)
    }

    @Test("events compare by payload")
    func eventEquality() {
        #expect(LLMEvent.textDelta("a") == .textDelta("a"))
        #expect(LLMEvent.textDelta("a") != .textDelta("b"))
        #expect(LLMEvent.usage(.init(promptTokens: 1, completionTokens: 2)) == .usage(.init(
            promptTokens: 1,
            completionTokens: 2
        )))
        #expect(LLMEvent.done == .done)
    }

    @Test("errors are equatable and readable")
    func errors() {
        #expect(LLMError.provider("boom") == .provider("boom"))
        #expect(LLMError.emptyResponse.description.contains("empty"))
    }

    @Test("provider failures have distinct, display-safe cases")
    func actionableErrors() {
        #expect(LLMError.unauthorized.description.contains("key"))
        #expect(LLMError.invalidModel("tiny").description.contains("tiny"))
        #expect(LLMError.rateLimited.description.contains("rate"))
        #expect(LLMError.timedOut.description.contains("timed out"))
        #expect(LLMError.server(status: 503).description.contains("503"))
    }
}
