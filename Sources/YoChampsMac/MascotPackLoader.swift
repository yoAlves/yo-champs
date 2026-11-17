import CoreGraphics
import Foundation
import ImageIO
import OSLog
import YoChampsCore

public struct MascotPack: Sendable {
    public let manifest: MascotManifest
    public let spritesheetURL: URL
}

public enum MascotPackLoadResult: Sendable {
    case selected(MascotPack)
    case fallback(MascotPack, message: String)
}

/// A directory-listing failure is reported to the caller rather than thrown:
/// the default pack is still available and must keep Champ on screen.
private enum LocalCandidatesResult {
    case found([MascotPackCandidate])
    case unreadable
}

/// Discovers packs on disk and hands the pure selector a stable list of
/// validated candidates. The fallback is always the bundled default, so a
/// broken or ambiguous local pack can never leave the app without a mascot.
public struct MascotPackLoader {
    private let supportDirectory: URL
    private let logger = Logger(subsystem: "com.yurioliveira.yochamps", category: "mascot")

    public init(supportDirectory: URL = AppPaths.supportDirectory) {
        self.supportDirectory = supportDirectory
    }

    public func load() throws -> MascotPackLoadResult {
        let validator = MascotPackValidator(imageSize: Self.pngSize)
        let defaultPack = try loadDefaultPack(validator: validator)
        let candidates: [MascotPackCandidate]
        switch localCandidates(validator: validator) {
        case let .found(found):
            candidates = found
        case .unreadable:
            return .fallback(
                defaultPack,
                message: "Local mascot packs could not be read; using default Champ."
            )
        }

        switch MascotPackSelector.select(localPacks: candidates) {
        case .default:
            return .fallback(defaultPack, message: "")
        case let .local(candidate):
            let loaded = try manifest(at: candidate.directory)
            return .selected(pack(manifest: loaded, at: candidate.directory))
        case let .invalidLocal(reason):
            return .fallback(defaultPack, message: reason)
        case let .ambiguous(count):
            let message = "Multiple local mascot packs found (\(count)); using the default Champ."
            return .fallback(defaultPack, message: message)
        }
    }

    // MARK: - Default pack

    private func loadDefaultPack(validator: MascotPackValidator) throws -> MascotPack {
        guard let directory = defaultPackDirectory() else {
            logger.error("default mascot pack not found")
            throw MascotPackError.missingFile("Mascots/Default/manifest.json")
        }
        try validator.validate(packAt: directory)
        let loaded = try manifest(at: directory)
        return pack(manifest: loaded, at: directory)
    }

    /// The bundle is the shipping location; the source-tree path covers debug
    /// runs launched without the resource-copy step.
    private func defaultPackDirectory() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Mascots/Default", isDirectory: true),
            URL(fileURLWithPath: "Resources/Mascots/Default", isDirectory: true),
        ]
        return candidates.compactMap(\.self).first { url in
            FileManager.default.fileExists(
                atPath: url.appendingPathComponent("manifest.json").path
            )
        }
    }

    // MARK: - Local packs

    private func localCandidates(validator: MascotPackValidator) -> LocalCandidatesResult {
        let mascots = supportDirectory.appendingPathComponent("Mascots", isDirectory: true)
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: mascots,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
                return .found([])
            }
            logger.error("local mascot packs could not be listed: \(String(describing: error), privacy: .private)")
            return .unreadable
        }

        var candidates: [MascotPackCandidate] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDirectory else { continue }

            let id = entry.lastPathComponent
            do {
                try validator.validate(packAt: entry)
                let loaded = try manifest(at: entry)
                candidates.append(MascotPackCandidate(
                    id: id,
                    name: loaded.name,
                    directory: entry,
                    validationError: nil
                ))
            } catch {
                let detail = String(describing: error)
                logger.error("local pack '\(id, privacy: .private)' invalid: \(detail, privacy: .private)")
                candidates.append(MascotPackCandidate(
                    id: id,
                    name: id,
                    directory: entry,
                    validationError: detail
                ))
            }
        }
        return .found(candidates)
    }

    // MARK: - Helpers

    private func manifest(at directory: URL) throws -> MascotManifest {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        return try JSONDecoder().decode(MascotManifest.self, from: data)
    }

    private func pack(manifest: MascotManifest, at directory: URL) -> MascotPack {
        MascotPack(
            manifest: manifest,
            spritesheetURL: directory.appendingPathComponent("spritesheet.png")
        )
    }

    private static func pngSize(at url: URL) throws -> PixelSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw MascotPackError.invalidImage(url.path)
        }
        return PixelSize(width: image.width, height: image.height)
    }
}
