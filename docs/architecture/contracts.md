# Contracts

These are the binding Swift-level contracts for V0. They are declared here
before implementation so Core, providers, shell and tests agree. M0–M1 shipped
the mascot manifest, state, LLM/agent/context contracts, engine, mock provider
and app shell; M2 adds profiles, a real provider, config and persistence.

## LLM provider

```swift
public protocol LLMProvider: Sendable {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error>
}

public struct LLMRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [LLMMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let headers: [String: String]
}

public struct LLMMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case system, developer, user, assistant
    }
    public let role: Role
    public let content: String
}

public enum LLMEvent: Sendable, Equatable {
    case textDelta(String)
    case usage(LLMUsage)
    case done
}

public struct LLMUsage: Codable, Sendable, Equatable {
    public let promptTokens: Int?
    public let completionTokens: Int?
}

public enum LLMError: Error, Sendable, Equatable, CustomStringConvertible {
    case provider(String)
    case emptyResponse
    case invalidRequest(String)
    case unauthorized
    case invalidModel(String)
    case rateLimited
    case timedOut
    case server(status: Int)
}
```

Rules: providers map transport errors and HTTP status codes to these domain
cases; Core never sees HTTP status codes, JSON envelopes or vendor names.
`YoChampsProviders` keeps protocol logic pure — an injected `LLMHTTPTransport`
owns the network boundary — and the retry delay/timeouts are configured data.
Descriptions are display-safe: provider payload text is never echoed.

```swift
public struct LLMHTTPRequest: Sendable, Equatable {
    public let url: URL
    public let headers: [String: String]
    public let body: Data
    public let timeout: Duration
}

public struct LLMHTTPResponse: Sendable {
    public let statusCode: Int
    public let body: AsyncThrowingStream<UInt8, Error>
}

public enum LLMTransportError: Error, Sendable, Equatable {
    case timedOut
    case connection(String)
}

public protocol LLMHTTPTransport: Sendable {
    func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse
}
```

The transport applies `timeout`, its `body` is single-consumer and must cancel
its underlying task when iteration stops; `connection` messages are shown to
users and must never include request or response payloads. Retries apply only
to 5xx responses and transport errors, paced by the injected clock; 429, 401,
404 and cancellation are never retried. `.done` is emitted only after the
response has been fully validated and contained text.

## Agent

```swift
public struct AgentDefinition: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let systemPrompt: String
    public let model: String
    public let style: String?
}

public protocol AgentRegistry: Sendable {
    func agent(id: String) -> AgentDefinition?
    func defaultAgent() -> AgentDefinition
}
```

V0 ships one generalist agent; the registry is the extension point.
`StaticAgentRegistry(agents:defaultID:)` is failable: it rejects duplicate ids
and a default id that is not registered. V0 has no tool list: `Capability.tools`
is a forward-declared flag, not implemented behaviour.

## Engine and state

```swift
public enum CompanionState: String, Codable, Sendable, CaseIterable {
    case idle, thinking, streaming, happy, confused, error
}
```

`CompanionEngine` accepts a question, builds context, calls the provider and
emits text deltas plus state changes through an `AsyncStream`. The model never
chooses animation keywords.

## Context

```swift
public struct ContextBudget: Sendable, Equatable {
    public static let `default` = ContextBudget(maxTurns: 12, maxCharacters: 6000)
    public let maxTurns: Int
    public let maxCharacters: Int
}

public protocol ContextBuilder: Sendable {
    func build(
        systemPrompt: String,
        history: [LLMMessage],
        question: String,
        budget: ContextBudget
    ) -> [LLMMessage]
}
```

`ContextBudget.init(maxTurns:maxCharacters:)` requires positive values.
V0 keeps the last complete turns that fit the turn/character budget;
summarization/RAG is post-V0.

## Storage

```swift
public protocol ConversationStore: Sendable {
    func load() async throws -> Conversation
    func save(_ conversation: Conversation) async throws
    func clear() async throws
}

public protocol SecretStore: Sendable {
    func secret(for ref: String) async throws -> String?
    func setSecret(_ value: String?, for ref: String) async throws
}
```

M0–M1 use an in-memory store; M2 adds JSON + Keychain implementations in
`YoChampsMac`.

## Provider profiles

```swift
public struct ProviderProfile: Codable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let kind: ProviderKind        // .compatible in V0
    public let baseURL: URL
    public let model: String
    public let headers: [String: String]
    public let secretRef: String
    public let capabilities: Set<Capability>
    public let isDefault: Bool
}

public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case compatible
}

public enum Capability: String, Codable, Sendable, CaseIterable {
    case streaming, reasoningEffort, tools, maxContext
}
```

Core names the compatibility protocol, never a vendor: M2's config layer maps
the on-disk `kind` value to `ProviderKind`, so `Sources/YoChampsCore` stays free
of vendor names. Core's synthesized `Codable` is not a persisted on-disk format;
only the config DTO is. `config.json` has its own versioned DTO (M2 task 3), not
this struct: the loader defaults omitted `isDefault`/`headers`/`capabilities`, maps
the wire `kind`, and rejects duplicate or missing default profiles with a clear
error. `secretRef` is a Keychain reference with grammar `keychain:<service>/<ref>`;
config, logs and fixtures hold the reference only, never the key.

Header placeholders: `{{conversationId}}`, `{{appVersion}}`, `{{userAgent}}`.
No real provider ships as default.

## Mascot pack

Implemented in M0 (`MascotManifest` + `MascotPackError`). See
`mascot-pack.md` for the on-disk format. `CompanionState` maps to the required
animation ids; extra animations are allowed and ordered after the required ones.

## Commands (V0.1)

```swift
public protocol CommandRouter: Sendable {
    func handles(_ input: String) -> Bool
    func execute(_ input: String) async throws -> CommandResult
}
```

Not implemented in V0; listed so the loop does not need redesign later.

## Diagnostics

```swift
public protocol Logger: Sendable {
    func log(_ level: Level, _ message: String, metadata: [String: String])
}
```

Shell implementation wraps `os.Logger` with `privacy: .private` for user data.

## Evals

```swift
public struct EvalFixture: Codable, Sendable {
    public let id: String
    public let input: String
    public let expectations: [String]
    public let schemaVersion: Int
}

public protocol EvalRunner: Sendable {
    func run(_ fixtures: [EvalFixture]) async throws -> EvalReport
}
```

M4. Fixtures live with `YoChampsEvals`; fixtures never contain real secrets.
