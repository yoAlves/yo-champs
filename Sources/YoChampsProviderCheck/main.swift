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
    print("provider-check: OK")
} catch {
    fail("provider request failed: \(String(describing: error))")
}
