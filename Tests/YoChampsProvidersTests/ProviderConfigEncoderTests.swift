import Foundation
import Testing
import YoChampsCore
@testable import YoChampsProviders

@Suite("Provider config encoder")
struct ProviderConfigEncoderTests {
    private func profile(id: String = "personal-go") -> ProviderProfile {
        ProviderProfile(
            id: id,
            label: "Personal Go",
            kind: .compatible,
            baseURL: URL(string: "https://example.test/v1")!,
            model: "test-model",
            headers: ["x-opencode-session": "{{conversationId}}"],
            secretRef: "keychain:provider/personal-go",
            capabilities: [.streaming, .maxContext],
            isDefault: id == "personal-go"
        )
    }

    @Test("encoded config round-trips through the decoder")
    func roundTrip() throws {
        let profiles = [profile(), profile(id: "secondary")]
        let data = try ProviderConfigEncoder.encode(profiles: profiles, defaultProfileID: "personal-go")

        let registry = try ProviderConfigDecoder.decode(data)
        #expect(registry.profiles.count == 2)
        #expect(registry.defaultProfile.id == "personal-go")
        let secondary = try #require(registry.profile(id: "secondary"))
        #expect(secondary.capabilities == [.streaming, .maxContext])
    }

    @Test("writes the documented wire kind and schema version")
    func wireValues() throws {
        let data = try ProviderConfigEncoder.encode(profiles: [profile()], defaultProfileID: "personal-go")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let profiles = object?["profiles"] as? [[String: Any]]

        #expect(object?["schemaVersion"] as? Int == 1)
        #expect(object?["defaultProfileID"] as? String == "personal-go")
        #expect(profiles?.first?["kind"] as? String == "openai-compatible")
    }

    @Test("refuses a default id that is not in the profiles")
    func unknownDefault() throws {
        #expect {
            try ProviderConfigEncoder.encode(profiles: [profile()], defaultProfileID: "missing")
        } throws: { error in
            error as? ProviderConfigError == .unknownDefaultProfile("missing")
        }
    }

    @Test("refuses duplicate ids before writing an unreadable file")
    func duplicateIDs() throws {
        #expect {
            try ProviderConfigEncoder.encode(profiles: [profile(), profile()], defaultProfileID: "personal-go")
        } throws: { error in
            error as? ProviderConfigError == .duplicateProfileID("personal-go")
        }
    }

    @Test("refuses a credential header before it can reach config.json")
    func credentialHeader() throws {
        var withKey = profile()
        withKey = ProviderProfile(
            id: withKey.id, label: withKey.label, kind: withKey.kind, baseURL: withKey.baseURL,
            model: withKey.model, headers: ["Authorization": "Bearer sk-live-123"],
            secretRef: withKey.secretRef, capabilities: withKey.capabilities, isDefault: true
        )
        #expect {
            try ProviderConfigEncoder.encode(profiles: [withKey], defaultProfileID: withKey.id)
        } throws: { error in
            error as? ProviderConfigError == .credentialHeader("Authorization")
        }
    }

    @Test("sorts capabilities and normalizes isDefault in the wire bytes")
    func deterministicOutput() throws {
        var other = profile(id: "other")
        other = ProviderProfile(
            id: other.id, label: other.label, kind: other.kind, baseURL: other.baseURL,
            model: other.model, headers: other.headers, secretRef: other.secretRef,
            capabilities: other.capabilities, isDefault: true
        )
        let data = try ProviderConfigEncoder.encode(
            profiles: [profile(), other],
            defaultProfileID: "personal-go"
        )
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let profiles = try #require(object?["profiles"] as? [[String: Any]])

        #expect(profiles[0]["capabilities"] as? [String] == ["maxContext", "streaming"])
        #expect(profiles[0]["isDefault"] as? Bool == true)
        #expect(profiles[1]["isDefault"] as? Bool == false)
    }
}
