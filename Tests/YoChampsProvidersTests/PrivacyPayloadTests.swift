import Foundation
import Testing
import YoChampsCore
@testable import YoChampsProviders

/// The provider is the last stage before the network, so these assertions pin
/// what can leave the machine: only the conversation the user sent, never
/// local config, file paths, Keychain values or telemetry.
@Suite("Privacy payload boundary")
struct PrivacyPayloadTests {
    private let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"ok\"}}]}\n\ndata: [DONE]\n\n"

    private func makeProvider(_ transport: FakeTransport) -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(
            configuration: .init(baseURL: URL(string: "https://example.test/v1")!),
            transport: transport
        )
    }

    @Test("body carries only model, messages, stream, max_tokens, temperature")
    func payloadKeys() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: sse)
        let request = LLMRequest(
            model: "privacy-model",
            messages: [
                LLMMessage(role: .system, content: "be brief"),
                LLMMessage(role: .user, content: "hello"),
            ],
            maxTokens: 256,
            temperature: 0.2,
            headers: ["X-Title": "YoChamps"]
        )

        for try await _ in makeProvider(transport).stream(request) {}

        let requests = await transport.requests
        let httpRequest = try #require(requests.first)
        let object = try #require(
            try JSONSerialization.jsonObject(with: httpRequest.body) as? [String: Any]
        )
        #expect(Set(object.keys) == ["model", "messages", "stream", "max_tokens", "temperature"])
        #expect(object["model"] as? String == "privacy-model")
        #expect(object["stream"] as? Bool == true)
        #expect(object["max_tokens"] as? Int == 256)
        #expect(object["temperature"] as? Double == 0.2)

        let messages = try #require(object["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user"])
        #expect(messages.map { $0["content"] as? String } == ["be brief", "hello"])
        for message in messages {
            #expect(Set(message.keys) == ["role", "content"])
        }
    }

    @Test("body has no secret, path or telemetry fields")
    func payloadHasNoLocalState() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: sse)
        let request = LLMRequest(
            model: "privacy-model",
            messages: [LLMMessage(role: .user, content: "hello")],
            maxTokens: 256,
            temperature: 0.2,
            headers: ["X-Title": "YoChamps"]
        )

        for try await _ in makeProvider(transport).stream(request) {}

        let requests = await transport.requests
        let body = try #require(requests.first).body
        // JSONEncoder escapes `/` as `\/`; normalize so path checks see `/`.
        let text = try #require(String(data: body, encoding: .utf8))
            .replacingOccurrences(of: "\\/", with: "/")
        let forbidden = [
            "api_key", "apiKey", "authorization", "secret", "secretRef",
            "keychain", "telemetry", "userAgent", "conversationId", "filePath",
            "/Users/",
        ]
        for key in forbidden {
            #expect(!text.lowercased().contains(key.lowercased()), "payload leaked \(key)")
        }
    }

    @Test("optional fields are omitted and no Authorization header is invented")
    func minimalPayload() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: sse)
        let request = LLMRequest(
            model: "privacy-model",
            messages: [LLMMessage(role: .user, content: "hello")],
            headers: ["X-Title": "YoChamps"]
        )

        for try await _ in makeProvider(transport).stream(request) {}

        let requests = await transport.requests
        let httpRequest = try #require(requests.first)
        let object = try #require(
            try JSONSerialization.jsonObject(with: httpRequest.body) as? [String: Any]
        )
        #expect(Set(object.keys) == ["model", "messages", "stream"])
        #expect(httpRequest.headers == [
            "Content-Type": "application/json",
            "X-Title": "YoChamps",
        ])
        #expect(httpRequest.headers["Authorization"] == nil)
    }

    @Test("a key supplied as a request header never lands in the body")
    func headerSecretStaysOutOfTheBody() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: sse)
        let request = LLMRequest(
            model: "privacy-model",
            messages: [LLMMessage(role: .user, content: "hello")],
            headers: ["Authorization": "Bearer request-scoped-key"]
        )

        for try await _ in makeProvider(transport).stream(request) {}

        let requests = await transport.requests
        let httpRequest = try #require(requests.first)
        #expect(httpRequest.headers["Authorization"] == "Bearer request-scoped-key")
        let text = try #require(String(data: httpRequest.body, encoding: .utf8))
        #expect(!text.contains("request-scoped-key"))
    }
}
