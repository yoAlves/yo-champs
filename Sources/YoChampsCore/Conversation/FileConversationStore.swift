import Foundation

public enum ConversationFileError: Error, Sendable, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case malformed(String)

    public var description: String {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "unsupported history schemaVersion \(version); expected \(ConversationFileMigrator.currentVersion)"
        case let .malformed(reason):
            "history file is malformed: \(reason)"
        }
    }
}

/// Reads the stored version before decoding, so an unknown version is refused
/// with a clear error instead of being silently misread. V0 ships only v1;
/// future versions add a case here and write the current one back.
public enum ConversationFileMigrator {
    public static let currentVersion = 1

    public static func migrate(_ data: Data) throws -> Conversation {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConversationFileError.malformed("not a JSON object")
        }
        guard let version = object["schemaVersion"] as? Int else {
            throw ConversationFileError.malformed("missing or non-integer schemaVersion")
        }
        guard version == currentVersion else {
            throw ConversationFileError.unsupportedSchemaVersion(version)
        }
        do {
            return try JSONDecoder().decode(Conversation.self, from: data)
        } catch {
            throw ConversationFileError.malformed("unreadable messages")
        }
    }
}

/// JSON-backed conversation history. The directory is injected so tests use a
/// temporary path; the Mac shell passes Application Support.
public actor FileConversationStore: ConversationStore {
    private let directory: URL
    private let fileName: String
    private let retention: ConversationRetention

    public init(
        directory: URL,
        fileName: String = "history.json",
        retention: ConversationRetention = .init()
    ) {
        self.directory = directory
        self.fileName = fileName
        self.retention = retention
    }

    private var fileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    public func load() async throws -> Conversation {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Conversation()
        } catch {
            throw ConversationFileError.malformed("unreadable file")
        }
        return try ConversationFileMigrator.migrate(data)
    }

    public func save(_ conversation: Conversation) async throws {
        guard conversation.schemaVersion == ConversationFileMigrator.currentVersion else {
            throw ConversationFileError.unsupportedSchemaVersion(conversation.schemaVersion)
        }
        let retained = retention.trim(conversation)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(retained)
        try createPrivateDirectory()
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func createPrivateDirectory() throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // createDirectory only applies its attributes to a directory it creates,
        // so an existing directory keeps whatever mode it already had.
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    public func clear() async throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}
