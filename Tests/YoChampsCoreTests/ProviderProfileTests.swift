import Foundation
import Testing
@testable import YoChampsCore

@Suite("Provider profiles")
struct ProviderProfileTests {
    @Test("profile survives a Codable round-trip with every field")
    func profileRoundTrip() throws {
        let profile = try ProviderProfile(
            id: "local",
            label: "Local stub",
            kind: .compatible,
            baseURL: #require(URL(string: "http://127.0.0.1:8080/v1")),
            model: "test-model",
            headers: ["X-App-Version": "{{appVersion}}"],
            secretRef: "keychain:com.yurioliveira.yochamps/local.key",
            capabilities: [.streaming, .maxContext],
            isDefault: true
        )

        let data = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(ProviderProfile.self, from: data) == profile)
    }

    @Test("kind is vendor-neutral in Core")
    func kindWireValue() {
        #expect(ProviderKind.compatible.rawValue == "compatible")
        #expect(ProviderKind.allCases == [.compatible])
    }

    @Test("capabilities use the documented wire values")
    func capabilityWireValues() throws {
        let json = Data(#"["streaming","reasoningEffort","tools","maxContext"]"#.utf8)
        let decoded = try JSONDecoder().decode(Set<Capability>.self, from: json)
        #expect(decoded == Set(Capability.allCases))
    }

    @Test("encoded config holds a reference, never a key value")
    func configHasReferenceOnly() throws {
        let profile = try ProviderProfile(
            id: "local",
            label: "Local stub",
            kind: .compatible,
            baseURL: #require(URL(string: "http://127.0.0.1:8080/v1")),
            model: "test-model",
            headers: [:],
            secretRef: "keychain:com.yurioliveira.yochamps/local.key",
            capabilities: [.streaming],
            isDefault: true
        )

        let data = try JSONEncoder().encode(profile)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["secretRef"] as? String == "keychain:com.yurioliveira.yochamps/local.key")
        #expect(object?["apiKey"] == nil)
        #expect(object?["secret"] == nil)
    }
}
