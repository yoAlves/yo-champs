import Foundation
import YoChampsCore
import YoChampsProviders

/// Reads and writes `config.json` under Application Support. A missing file is
/// onboarding, not an error; a malformed one is surfaced with a typed error.
public struct ProviderConfigFileStore: Sendable {
    private let fileURL: URL

    public init(directory: URL? = nil) {
        let base: URL
        if let directory {
            base = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            base = support.appendingPathComponent("YoChamps", isDirectory: true)
        }
        fileURL = base.appendingPathComponent("config.json")
    }

    public func load() async throws -> ProviderRegistry? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        return try ProviderConfigDecoder.decode(data)
    }

    public func save(_ registry: ProviderRegistry) async throws {
        let data = try ProviderConfigEncoder.encode(
            profiles: registry.profiles,
            defaultProfileID: registry.defaultProfile.id
        )
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() async throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}
