import Foundation

public struct PixelSize: Sendable, Equatable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Validates a mascot pack directory: manifest schema, required animations,
/// spritesheet geometry, preview presence and size limits.
///
/// Image decoding is injected so Core stays Foundation-only and the file
/// contract is testable on Linux; the macOS CLI supplies an ImageIO decoder.
public struct MascotPackValidator: Sendable {
    public typealias ImageSizeProvider = @Sendable (URL) throws -> PixelSize

    public static let maxManifestBytes = 64 * 1024
    public static let maxSpritesheetBytes = 5 * 1024 * 1024
    public static let maxPreviewBytes = 2 * 1024 * 1024

    private let imageSize: ImageSizeProvider

    public init(imageSize: @escaping ImageSizeProvider) {
        self.imageSize = imageSize
    }

    public func validate(packAt directory: URL) throws {
        let manifestURL = directory.appending(path: "manifest.json")
        let spritesheetURL = directory.appending(path: "spritesheet.png")
        let previewURL = directory.appending(path: "preview.png")

        try requireFile(manifestURL, limit: Self.maxManifestBytes)
        try requireFile(spritesheetURL, limit: Self.maxSpritesheetBytes)
        try requireFile(previewURL, limit: Self.maxPreviewBytes)

        let manifest: MascotManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(MascotManifest.self, from: data)
        } catch {
            throw MascotPackError.invalidJSON(manifestURL.path)
        }
        try manifest.validate()

        let (expectedWidth, overflow) = manifest.totalFrames
            .multipliedReportingOverflow(by: manifest.frameSize.width)
        guard !overflow else {
            throw MascotPackError.invalidFrameSize(
                width: manifest.frameSize.width,
                height: manifest.frameSize.height
            )
        }

        let sheet = try imageSize(spritesheetURL)
        guard sheet.width == expectedWidth, sheet.height == manifest.frameSize.height else {
            throw MascotPackError.spritesheetMismatch(
                expectedWidth: expectedWidth,
                expectedHeight: manifest.frameSize.height,
                actualWidth: sheet.width,
                actualHeight: sheet.height
            )
        }

        _ = try imageSize(previewURL)
    }

    private func requireFile(_ url: URL, limit: Int) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MascotPackError.missingFile(url.path)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard bytes <= limit else {
            throw MascotPackError.fileTooLarge(path: url.path, bytes: bytes, limit: limit)
        }
    }
}
