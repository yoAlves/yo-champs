import Foundation
import Testing
@testable import YoChampsCore

@Suite("FileConversationStore")
struct FileConversationStoreTests {
    private func makeStore(
        retention: ConversationRetention = .init()
    ) -> (store: FileConversationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("yochamps-test-\(UUID().uuidString)", isDirectory: true)
        return (
            FileConversationStore(directory: directory, retention: retention),
            directory
        )
    }

    private func write(_ json: String, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("history.json"))
    }

    private func makeConversation(_ turns: [(user: String, assistant: String)]) -> Conversation {
        Conversation(messages: turns.flatMap { turn in
            [
                LLMMessage(role: .user, content: turn.user),
                LLMMessage(role: .assistant, content: turn.assistant),
            ]
        })
    }

    private func permissions(of url: URL) throws -> Int? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue
    }

    @Test("starts with an empty conversation when no file exists")
    func startsEmpty() async throws {
        let (store, _) = makeStore()
        let conversation = try await store.load()

        #expect(conversation.schemaVersion == 1)
        #expect(conversation.messages.isEmpty)
    }

    @Test("a new store instance keeps history across a restart")
    func restartKeepsHistory() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation(messages: [
            .init(role: .user, content: "hello"),
            .init(role: .assistant, content: "hi"),
        ])
        try await store.save(conversation)

        let restarted = FileConversationStore(directory: directory)
        #expect(try await restarted.load() == conversation)
    }

    @Test("clear removes the file and returns an empty conversation")
    func clearHistory() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.save(Conversation(messages: [.init(role: .user, content: "x")]))
        try await store.clear()

        #expect(try await store.load().messages.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path))
    }

    @Test("writes schema version 1 and leaves only the history file")
    func atomicWrite() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.save(Conversation(messages: [.init(role: .user, content: "x")]))

        let file = directory.appendingPathComponent("history.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(object?["schemaVersion"] as? Int == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["history.json"])
    }

    @Test("refuses a newer schema version with a clear error")
    func rejectsNewerSchema() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write(#"{"schemaVersion":2,"messages":[]}"#, to: directory)

        var caught: ConversationFileError?
        do {
            _ = try await store.load()
        } catch let error as ConversationFileError {
            caught = error
        }
        #expect(caught == .unsupportedSchemaVersion(2))
    }

    @Test("distinguishes corrupt JSON from a missing schemaVersion")
    func rejectsCorruptFiles() async throws {
        let cases: [(String, String)] = [
            (#"{"schemaVersion":1,"#, "not a JSON object"),
            (#"{"messages":[]}"#, "missing or non-integer schemaVersion"),
        ]
        for (json, reason) in cases {
            let (store, directory) = makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }
            try write(json, to: directory)

            var caught: ConversationFileError?
            do {
                _ = try await store.load()
            } catch let error as ConversationFileError {
                caught = error
            }
            #expect(caught == .malformed(reason))
        }
    }

    @Test("refuses to write a version it cannot read back")
    func rejectsUnwritableVersion() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation(schemaVersion: 2, messages: [])

        var caught: ConversationFileError?
        do {
            try await store.save(conversation)
        } catch let error as ConversationFileError {
            caught = error
        }
        #expect(caught == .unsupportedSchemaVersion(2))
    }

    @Test("loads a hand-written current-version file")
    func loadsCurrentVersion() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = #"{"schemaVersion":1,"messages":[{"role":"user","content":"hi"}]}"#
        try write(json, to: directory)

        let conversation = try await store.load()
        #expect(conversation.messages == [.init(role: .user, content: "hi")])
    }

    @Test("caps the stored history and drops the oldest turns")
    func capsHistory() async throws {
        let (store, directory) = makeStore(retention: ConversationRetention(maxBytes: 512))
        defer { try? FileManager.default.removeItem(at: directory) }
        let filler = String(repeating: "a", count: 200)
        let conversation = makeConversation([
            (filler, filler),
            (filler, filler),
            (filler, filler),
            ("newest question", "newest answer"),
        ])

        try await store.save(conversation)

        let loaded = try await store.load()
        let file = directory.appendingPathComponent("history.json")
        #expect(loaded.messages == [
            LLMMessage(role: .user, content: "newest question"),
            LLMMessage(role: .assistant, content: "newest answer"),
        ])
        #expect(try Data(contentsOf: file).count <= 512)
    }

    @Test("creates the directory private and the history file owner-only")
    func privatePermissions() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.save(makeConversation([("hello", "hi")]))

        let file = directory.appendingPathComponent("history.json")
        #expect(try permissions(of: directory) == 0o700)
        #expect(try permissions(of: file) == 0o600)
    }

    @Test("tightens an existing directory and keeps later writes private")
    func tightensExistingDirectory() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        #expect(try permissions(of: directory) == 0o755)

        try await store.save(makeConversation([("hello", "hi")]))
        #expect(try permissions(of: directory) == 0o700)

        try await store.save(makeConversation([("hello", "hi"), ("again", "sure")]))
        let file = directory.appendingPathComponent("history.json")
        #expect(try permissions(of: directory) == 0o700)
        #expect(try permissions(of: file) == 0o600)
    }
}
