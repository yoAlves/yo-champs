# Contracts

These are the binding Swift-level contracts for V0. They are declared here
before implementation so Core, providers, shell and tests agree. M0–M3 shipped
the mascot manifest, state, LLM/agent/context contracts, engine, mock and real
providers, config/Keychain, JSON persistence, the Ask chat shell and the
embedded mascot. M4 hardening (evals, injection fixtures, performance, release
dry-run) is an open post-release backlog.

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
cases; Core never sees JSON envelopes or vendor names. The only transport
detail Core carries is `LLMError.server(status:)` for an unmapped 5xx.
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

M0–M1 use an in-memory store; M2 adds `FileConversationStore` (Core, injected
directory, `schemaVersion` 1 + migrator, atomic writes) and the Keychain
`SecretStore` in `YoChampsMac`. When a turn starts, the engine loads the stored
conversation and sends its recent turns as context; only the visible transcript
starts empty, and nothing replays it into the panel (see ADR 0013).

History is capped at 2 MB of encoded JSON by `ConversationRetention` (oldest
complete turns dropped, newest turn always kept) and written into a `0700`
directory with `0600` on the file.

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

Core names the compatibility protocol, never a vendor: the config layer maps
the on-disk `kind` value to `ProviderKind`, so `Sources/YoChampsCore` stays free
of vendor names. Core's synthesized `Codable` is not a persisted on-disk format;
only the config DTO is. `config.json` is `{schemaVersion: 1, defaultProfileID?,
profiles: [...]}`; `ProviderConfigDecoder` defaults omitted
`isDefault`/`headers`/`capabilities`, maps the wire `kind`, and rejects an
unsupported schema/kind, duplicate ids, an unknown or missing default, a malformed
`secretRef` and credential-bearing headers with typed `ProviderConfigError`s.
The loader also rejects empty `id`/`label`/`model`/`secretRef`, a baseURL without
an http(s) scheme and host, and competing `isDefault` flags when no id is set.
`defaultProfileID` is the single source of truth for the default; `isDefault` is
the fallback when it is absent and is normalized on the resolved profiles.
`ProviderRegistry` exposes the validated profiles and resolves them by id.
`secretRef` is a Keychain reference with grammar `keychain:<service>/<ref>` — the
service segment is lexical only; the store owns the fixed service and uses the
whole ref as the account. Config, logs and fixtures hold the reference only,
never the key. The Mac shell implements `SecretStore` with the Keychain service
`com.yurioliveira.yochamps`; tests must inject a fake, never the real Keychain.

`ProviderConfigEncoder` is the write path: it validates ids/default, normalizes
`isDefault`, sorts capabilities for stable bytes and writes only references.
`ProviderRegistry(profiles:defaultProfileID:)` is the public validated
constructor; the decoder and encoder both use the same invariants.

The shell keeps `config.json` under Application Support via
`ProviderConfigFileStore`: a missing file is onboarding, an unreadable or
malformed one is a typed error. Profiles are validated once by
`ProviderProfileValidation`, which requires an absolute `http(s)` base URL and
rejects `http` outside loopback (`ProviderTransportPolicy`: `localhost`,
`127.0.0.1`, `::1` only). Settings edits the selected profile in place
(preserving label, capabilities and the other profiles), validates the base URL
before reading any key, writes the key only to Keychain, and adds the
`Authorization` header at request time. Distinct user-facing errors come from
`LLMError`, `ProviderConfigError`, `SettingsError` and `KeychainError`
descriptions; cancellation renders as “Cancelled”.

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

M4 (open backlog). Fixtures live with `YoChampsEvals`; fixtures never contain
real secrets.
