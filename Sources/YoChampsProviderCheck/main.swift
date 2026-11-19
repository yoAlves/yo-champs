import Foundation
import YoChampsCore
import YoChampsNetwork
import YoChampsProviders

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("provider-check: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard let urlFlag = arguments.firstIndex(of: "--url"), arguments.count > urlFlag + 1,
      let baseURL = URL(string: arguments[urlFlag + 1])
else {
    fail("usage: YoChampsProviderCheck --url <baseURL>")
}

let configuration = OpenAICompatibleProvider.Configuration(
    baseURL: baseURL,
    maxRetries: 0,
    retryDelay: .zero,
    timeout: .seconds(5)
)
let provider = OpenAICompatibleProvider(
    configuration: configuration,
    transport: URLSessionLLMTransport()
)
let request = LLMRequest(
    model: "stub-model",
    messages: [LLMMessage(role: .user, content: "hello")]
)

let requestTask = Task {
    var answer = ""
    for try await event in provider.stream(request) {
        if case let .textDelta(delta) = event {
            answer += delta
        }
    }
    return answer
}

do {
    let answer = try await requestTask.value
    guard answer == "Hello from stub" else {
        fail("unexpected answer: \(answer)")
    }
} catch {
    fail("provider request failed: \(String(describing: error))")
}

/// The stub records the last streaming payload; an effort must be sent only
/// when the request configures one.
func lastEffort(at baseURL: URL) async -> String? {
    let url = URL(string: "/last-effort", relativeTo: baseURL)!.absoluteURL
    guard let (data, _) = try? await URLSession.shared.data(from: url) else {
        return nil
    }
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

guard await lastEffort(at: baseURL) == "" else {
    fail("a request without an effort still sent reasoning_effort")
}

let effortRequest = LLMRequest(
    model: "stub-model",
    messages: [LLMMessage(role: .user, content: "hello")],
    reasoningEffort: "low"
)

do {
    for try await _ in provider.stream(effortRequest) {}
} catch {
    fail("effort request failed: \(String(describing: error))")
}

guard await lastEffort(at: baseURL) == "low" else {
    fail("the request did not send reasoning_effort=low")
}

print("provider-check: reasoning effort")

/// A redirect that leaves the provider origin must not be followed: request
/// headers carry the Keychain-backed key. The stub redirects to `localhost`
/// and records any hit on the target.
let redirectProvider = OpenAICompatibleProvider(
    configuration: OpenAICompatibleProvider.Configuration(
        baseURL: baseURL.appendingPathComponent("redirect"),
        maxRetries: 0,
        retryDelay: .zero,
        timeout: .seconds(5)
    ),
    transport: URLSessionLLMTransport()
)

var redirectError: Error?
do {
    for try await _ in redirectProvider.stream(request) {}
} catch {
    redirectError = error
}

guard let redirectError, String(describing: redirectError).contains("302") else {
    fail("cross-host redirect was followed: \(String(describing: redirectError))")
}

let leakCountURL = URL(string: "/leak-count", relativeTo: baseURL)!.absoluteURL
guard let (leakCountData, _) = try? await URLSession.shared.data(from: leakCountURL) else {
    fail("leak-count endpoint unreachable at \(leakCountURL.absoluteString)")
}

guard String(data: leakCountData, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) == "0"
else {
    fail("cross-host redirect reached the redirect target")
}

print("provider-check: redirect blocked")
print("provider-check: OK")
