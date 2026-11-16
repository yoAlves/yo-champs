import Foundation
import Testing
@testable import YoChampsCore

@Suite("FileConversationStore")
struct FileConversationStoreTests {
    private func makeStore() -> (store: FileConversationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("yochamps-test-\(UUID().uuidString)", isDirectory: true)
        return (FileConversationStore(directory: directory), directory)
    }

    private func write(_ json: String, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("history.json"))
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
}
