import Foundation
import Testing
import YoChampsCore
@testable import YoChampsProviders

private func configJSON(
    schemaVersion: Int = 1,
    defaultProfileID: String? = "personal-go",
    profiles: String
) -> Data {
    let defaultLine = defaultProfileID.map { ",\"defaultProfileID\":\"\($0)\"" } ?? ""
    return Data("""
    {"schemaVersion":\(schemaVersion)\(defaultLine),"profiles":[\(profiles)]}
    """.utf8)
}

private func profileJSON(
    id: String = "personal-go",
    kind: String = "openai-compatible",
    baseURL: String = "https://example.test/v1",
    secretRef: String = "keychain:provider/personal-go",
    headers: String = "\"headers\":{\"x-opencode-session\":\"{{conversationId}}\"},",
    capabilities: String = "\"capabilities\":[\"streaming\"],",
    effort: String? = nil,
    isDefault: String = ""
) -> String {
    let effortLine = effort.map { "\"reasoningEffort\":\"\($0)\"," } ?? ""
    return """
    {"id":"\(id)","label":"Personal Go","kind":"\(kind)",\
    "baseURL":"\(baseURL)","model":"test-model",\
    \(headers)"secretRef":"\(secretRef)",\
    \(capabilities)\(effortLine)\(isDefault)}
    """
}

@Suite("Provider config")
struct ProviderConfigTests {
    @Test("decodes the documented personal profile verbatim")
    func documentedProfile() throws {
        let registry = try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON()))

        #expect(registry.profiles.count == 1)
        let profile = try #require(registry.profile(id: "personal-go"))
        #expect(profile.kind == .compatible)
        #expect(profile.baseURL.absoluteString == "https://example.test/v1")
        #expect(profile.headers["x-opencode-session"] == "{{conversationId}}")
        #expect(profile.capabilities == [.streaming])
        #expect(profile.secretRef == "keychain:provider/personal-go")
        #expect(profile.isDefault)
        #expect(registry.defaultProfile == profile)
    }

    @Test("omitted optional fields get documented defaults")
    func optionalDefaults() throws {
        let profile = profileJSON(headers: "", capabilities: "", isDefault: "")
        let registry = try ProviderConfigDecoder.decode(configJSON(profiles: profile))

        let decoded = try #require(registry.profile(id: "personal-go"))
        #expect(decoded.headers.isEmpty)
        #expect(decoded.capabilities.isEmpty)
        #expect(decoded.isDefault)
    }

    @Test("resolves profiles by id")
    func registryLookup() throws {
        let first = profileJSON(id: "one")
        let second = profileJSON(id: "two")
        let registry = try ProviderConfigDecoder.decode(configJSON(
            defaultProfileID: "two",
            profiles: "\(first),\(second)"
        ))

        #expect(registry.profile(id: "one")?.id == "one")
        #expect(registry.profile(id: "two")?.id == "two")
        #expect(registry.profile(id: "missing") == nil)
        #expect(registry.defaultProfile.id == "two")
    }

    @Test("rejects an unsupported schema version")
    func unsupportedSchema() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(schemaVersion: 2, profiles: profileJSON()))
        } throws: { error in
            error as? ProviderConfigError == .unsupportedSchemaVersion(2)
        }
    }

    @Test("rejects an unsupported kind")
    func unsupportedKind() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON(kind: "other")))
        } throws: { error in
            error as? ProviderConfigError == .unsupportedKind("other")
        }
    }

    @Test("rejects duplicate profile ids")
    func duplicateIDs() throws {
        let profile = profileJSON()
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: "\(profile),\(profile)"))
        } throws: { error in
            error as? ProviderConfigError == .duplicateProfileID("personal-go")
        }
    }

    @Test("rejects an unknown default profile id")
    func unknownDefault() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(defaultProfileID: "missing", profiles: profileJSON()))
        } throws: { error in
            error as? ProviderConfigError == .unknownDefaultProfile("missing")
        }
    }

    @Test("rejects competing defaults when no default id is configured")
    func multipleDefaults() throws {
        let first = profileJSON(id: "one", isDefault: "\"isDefault\":true")
        let second = profileJSON(id: "two", isDefault: "\"isDefault\":true")
        let json = configJSON(defaultProfileID: nil, profiles: "\(first),\(second)")
        #expect {
            try ProviderConfigDecoder.decode(json)
        } throws: { error in
            error as? ProviderConfigError == .multipleDefaultProfiles
        }
    }

    @Test("rejects credential-bearing headers")
    func credentialHeaders() throws {
        let profile = profileJSON(headers: "\"headers\":{\"Authorization\":\"Bearer secret\"},")
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: profile))
        } throws: { error in
            error as? ProviderConfigError == .credentialHeader("Authorization")
        }
    }

    @Test("rejects a secret value in the secretRef field")
    func secretValueAsReference() throws {
        let profile = profileJSON(secretRef: "sk-live-123")
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: profile))
        } throws: { error in
            error as? ProviderConfigError == .invalidSecretRef("personal-go")
        }
    }

    @Test("rejects common credential header aliases")
    func credentialHeaderAliases() throws {
        for name in ["X-Auth-Token", "X-Goog-Api-Key", "client-secret"] {
            let profile = profileJSON(headers: "\"headers\":{\"\(name)\":\"value\"},")
            #expect {
                try ProviderConfigDecoder.decode(configJSON(profiles: profile))
            } throws: { error in
                error as? ProviderConfigError == .credentialHeader(name)
            }
        }
    }

    @Test("rejects obvious secret values in headers")
    func credentialHeaderValues() throws {
        for value in ["Bearer abc", "sk-live-123"] {
            let profile = profileJSON(headers: "\"headers\":{\"X-Custom\":\"\(value)\"},")
            #expect {
                try ProviderConfigDecoder.decode(configJSON(profiles: profile))
            } throws: { error in
                error as? ProviderConfigError == .credentialHeader("X-Custom")
            }
        }
    }

    @Test("defaultProfileID wins over isDefault flags and normalizes them")
    func defaultIDWinsOverFlags() throws {
        let first = profileJSON(id: "one", isDefault: "\"isDefault\":true")
        let second = profileJSON(id: "two", isDefault: "\"isDefault\":true")
        let registry = try ProviderConfigDecoder.decode(
            configJSON(defaultProfileID: "two", profiles: "\(first),\(second)")
        )

        #expect(registry.defaultProfile.id == "two")
        #expect(registry.defaultProfile.isDefault)
        #expect(registry.profile(id: "one")?.isDefault == false)
    }

    @Test("uses the flagged default when no id is configured")
    func flaggedDefaultFallback() throws {
        let first = profileJSON(id: "one", isDefault: "\"isDefault\":true")
        let second = profileJSON(id: "two")
        let registry = try ProviderConfigDecoder.decode(
            configJSON(defaultProfileID: nil, profiles: "\(first),\(second)")
        )

        #expect(registry.defaultProfile.id == "one")
        #expect(registry.defaultProfile.isDefault)
    }

    @Test("rejects a config with no default at all")
    func missingDefault() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(defaultProfileID: nil, profiles: profileJSON()))
        } throws: { error in
            error as? ProviderConfigError == .missingDefaultProfile
        }
    }

    @Test("rejects malformed secretRef boundaries")
    func secretRefBoundaries() throws {
        for ref in ["keychain:", "keychain:/ref", "keychain:svc/"] {
            let profile = profileJSON(secretRef: ref)
            #expect {
                try ProviderConfigDecoder.decode(configJSON(profiles: profile))
            } throws: { error in
                error as? ProviderConfigError == .invalidSecretRef("personal-go")
            }
        }
    }

    @Test("rejects empty fields and non-http URLs")
    func invalidFields() throws {
        let emptyModel = profileJSON().replacingOccurrences(of: "\"model\":\"test-model\"", with: "\"model\":\"\"")
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: emptyModel))
        } throws: { error in
            error as? ProviderConfigError == .emptyField(profileID: "personal-go", field: "model")
        }

        let ftp = profileJSON(baseURL: "ftp://example.test/v1")
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: ftp))
        } throws: { error in
            error as? ProviderConfigError == .invalidBaseURL(profileID: "personal-go")
        }
    }

    @Test("accepts https base URLs on any host")
    func acceptsHTTPSOutsideLoopback() throws {
        let registry = try ProviderConfigDecoder.decode(
            configJSON(profiles: profileJSON(baseURL: "https://example.com/v1"))
        )

        #expect(registry.defaultProfile.baseURL.absoluteString == "https://example.com/v1")
    }

    @Test("rejects http base URLs outside loopback")
    func rejectsHTTPOutsideLoopback() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON(baseURL: "http://example.com/v1")))
        } throws: { error in
            error as? ProviderConfigError == .insecureBaseURL(profileID: "personal-go", host: "example.com")
        }
    }

    @Test("accepts http base URLs on loopback hosts")
    func acceptsHTTPLoopback() throws {
        for baseURL in [
            "http://localhost:11434/v1",
            "http://127.0.0.1:11434/v1",
            "http://[::1]:11434/v1",
        ] {
            let registry = try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON(baseURL: baseURL)))
            #expect(registry.defaultProfile.baseURL.absoluteString == baseURL)
        }
    }

    @Test("insecure base URL error explains the HTTPS rule")
    func insecureBaseURLDescription() {
        let error = ProviderConfigError.insecureBaseURL(profileID: "personal-go", host: "example.com")

        #expect(error.description.localizedCaseInsensitiveContains("https"))
        #expect(error.description.localizedCaseInsensitiveContains("loopback"))
    }

    @Test("reports malformed config with a coding path, not raw JSON errors")
    func malformedConfig() throws {
        let json = Data(#"{"schemaVersion":1,"profiles":[{"id":"p"}]}"#.utf8)
        #expect {
            try ProviderConfigDecoder.decode(json)
        } throws: { error in
            guard let configError = error as? ProviderConfigError,
                  case let .malformedConfig(path) = configError else { return false }
            return path.contains("profiles")
        }
    }
}

@Suite("Provider config reasoning effort")
struct ProviderConfigReasoningEffortTests {
    @Test("decodes an optional reasoning effort")
    func decodesReasoningEffort() throws {
        let registry = try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON(effort: "low")))

        #expect(registry.defaultProfile.reasoningEffort == "low")
    }

    @Test("defaults a missing reasoning effort to nil")
    func defaultsMissingReasoningEffort() throws {
        let registry = try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON()))

        #expect(registry.defaultProfile.reasoningEffort == nil)
    }

    @Test("rejects an empty reasoning effort")
    func rejectsEmptyReasoningEffort() throws {
        #expect {
            try ProviderConfigDecoder.decode(configJSON(profiles: profileJSON(effort: "   ")))
        } throws: { error in
            error as? ProviderConfigError == .emptyField(
                profileID: "personal-go",
                field: "reasoningEffort"
            )
        }
    }
}

@Suite("Provider transport policy")
struct ProviderTransportPolicyTests {
    private func target(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test("accepts https on any host")
    func acceptsHTTPS() throws {
        try ProviderTransportPolicy.requireSecure(
            target("https://example.com/v1"),
            profileID: "personal"
        )
    }

    @Test("rejects http outside loopback")
    func rejectsRemoteHTTP() throws {
        #expect {
            try ProviderTransportPolicy.requireSecure(
                target("http://example.com/v1"),
                profileID: "personal"
            )
        } throws: { error in
            error as? ProviderConfigError == .insecureBaseURL(profileID: "personal", host: "example.com")
        }
    }

    @Test("accepts http on loopback hosts")
    func acceptsLoopbackHTTP() throws {
        for baseURL in [
            "http://localhost:11434/v1",
            "http://127.0.0.1:11434/v1",
            "http://[::1]:11434/v1",
        ] {
            try ProviderTransportPolicy.requireSecure(target(baseURL), profileID: "personal")
        }
    }

    @Test("normalizes loopback hosts across whitespace, case and brackets")
    func loopbackNormalization() {
        for host in ["localhost", " LocalHost ", "127.0.0.1", "::1", "[::1]", "[::1] "] {
            #expect(ProviderTransportPolicy.isLoopback(host: host), "expected \(host) to be loopback")
        }
        for host in ["example.com", "10.0.0.1", "127.0.0.2", "", "::2"] {
            #expect(!ProviderTransportPolicy.isLoopback(host: host), "expected \(host) not to be loopback")
        }
    }
}
