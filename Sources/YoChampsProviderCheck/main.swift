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
