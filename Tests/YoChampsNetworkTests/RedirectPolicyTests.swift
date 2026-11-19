import Foundation
import Testing
@testable import YoChampsNetwork

@Suite("Redirect policy")
struct RedirectPolicyTests {
    private let original = URL(string: "https://api.example.test/v1/chat/completions")!

    @Test("allows redirects that stay on the provider origin")
    func sameOrigin() throws {
        let policy = RedirectPolicy(url: original)

        #expect(try policy.allows(#require(URL(string: "https://api.example.test/v2/chat/completions"))))
        #expect(try policy.allows(#require(URL(string: "https://API.EXAMPLE.TEST/v2/chat/completions"))))
        #expect(try policy.allows(#require(URL(string: "https://api.example.test:443/v2/chat/completions"))))
    }

    @Test("rejects a redirect to another host")
    func crossHost() throws {
        let policy = RedirectPolicy(url: original)

        #expect(try !policy.allows(#require(URL(string: "https://collector.example.test/chat/completions"))))
    }

    @Test("rejects a redirect that downgrades the scheme or changes the port")
    func originChange() throws {
        let policy = RedirectPolicy(url: original)

        #expect(try !policy.allows(#require(URL(string: "http://api.example.test/v1/chat/completions"))))
        #expect(try !policy.allows(#require(URL(string: "https://api.example.test:8443/v1/chat/completions"))))
    }

    @Test("rejects a redirect without a host")
    func missingHost() {
        let policy = RedirectPolicy(url: original)

        #expect(!policy.allows(URL(fileURLWithPath: "/tmp/chat")))
    }
}
