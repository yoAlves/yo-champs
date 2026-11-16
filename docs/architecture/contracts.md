# Contracts

These are the binding Swift-level contracts for V0. They are declared here
before implementation so Core, providers, shell and tests agree. M0 implements
only `CompanionState` and the mascot manifest; the rest lands in M1–M2.

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
    public enum Role: String, Codable, Sendable { case system, developer, user, assistant }
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
```

Rules: providers map transport errors to domain errors; Core never sees HTTP
status codes, JSON envelopes or vendor names.

## Agent

```swift
public struct AgentDefinition: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let systemPrompt: String
    public let model: String?
    public let allowedTools: [String]
    public let style: String?
}

public protocol AgentRegistry: Sendable {
    func agent(id: String) -> AgentDefinition?
    func defaultAgent() -> AgentDefinition
}
```

V0 ships one generalist agent; the registry is the extension point.

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
public protocol ContextBuilder: Sendable {
    func build(history: [LLMMessage], budget: Int) -> [LLMMessage]
}
```

V0 keeps the last turns that fit the budget; summarization/RAG is post-V0.

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
    public let kind: ProviderKind        // .openAICompatible in V0
    public let baseURL: URL
    public let model: String
    public let headers: [String: String]
    public let secretRef: String
    public let capabilities: Set<Capability>
    public let isDefault: Bool
}

public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case openAICompatible = "openai-compatible"
}

public enum Capability: String, Codable, Sendable, CaseIterable {
    case streaming, reasoningEffort, tools, maxContext
}
```

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
