import Foundation

/// Declarative mascot pack manifest (`manifest.json`).
///
/// The pack format is documented in `docs/architecture/mascot-pack.md`.
public struct MascotManifest: Codable, Sendable, Equatable {
    public struct Size: Codable, Sendable, Equatable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    public struct Anchor: Codable, Sendable, Equatable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Animation: Codable, Sendable, Equatable {
        public let frames: Int
        public let fps: Double
        public let loop: Bool

        public init(frames: Int, fps: Double, loop: Bool) {
            self.frames = frames
            self.fps = fps
            self.loop = loop
        }
    }

    /// Animation ids every pack must provide, mapped from `CompanionState`.
    public static let requiredAnimations: [String] = [
        "idle", "thinking", "talking", "happy", "confused", "error",
    ]

    /// Upper bounds keep a hostile manifest from overflowing sheet arithmetic.
    public static let maxFrameDimension = 4096
    public static let maxAnimationFrames = 512

    public let schemaVersion: Int
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let license: String
    public let frameSize: Size
    public let scale: Double
    public let anchor: Anchor
    public let animations: [String: Animation]

    public init(
        schemaVersion: Int = 1,
        id: String,
        name: String,
        version: String,
        author: String,
        license: String,
        frameSize: Size,
        scale: Double,
        anchor: Anchor,
        animations: [String: Animation]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.license = license
        self.frameSize = frameSize
        self.scale = scale
        self.anchor = anchor
        self.animations = animations
    }

    /// Number of frames in `spritesheet.png` given the canonical layout:
    /// required animations in `requiredAnimations` order, then extras sorted by id.
    public var orderedAnimationIds: [String] {
        Self.requiredAnimations + animations.keys
            .filter { !Self.requiredAnimations.contains($0) }
            .sorted()
    }

    public var totalFrames: Int {
        orderedAnimationIds.reduce(into: 0) { total, id in
            total += animations[id]?.frames ?? 0
        }
    }

    public func validate() throws {
        guard schemaVersion >= 1 else {
            throw MascotPackError.invalidSchemaVersion(schemaVersion)
        }

        try validateText(id, field: "id")
        try validateText(name, field: "name")
        try validateText(version, field: "version")
        try validateText(author, field: "author")
        try validateText(license, field: "license")

        guard (1 ... Self.maxFrameDimension).contains(frameSize.width),
              (1 ... Self.maxFrameDimension).contains(frameSize.height)
        else {
            throw MascotPackError.invalidFrameSize(width: frameSize.width, height: frameSize.height)
        }
        guard scale > 0, scale.isFinite else {
            throw MascotPackError.invalidScale(scale)
        }
        guard (0 ... 1).contains(anchor.x), (0 ... 1).contains(anchor.y) else {
            throw MascotPackError.invalidAnchor(x: anchor.x, y: anchor.y)
        }

        for required in Self.requiredAnimations where animations[required] == nil {
            throw MascotPackError.missingAnimation(required)
        }

        for (name, animation) in animations {
            guard (1 ... Self.maxAnimationFrames).contains(animation.frames) else {
                throw MascotPackError.invalidAnimationFrames(name: name, frames: animation.frames)
            }
            guard animation.fps > 0, animation.fps.isFinite else {
                throw MascotPackError.invalidAnimationFPS(name: name, fps: animation.fps)
            }
        }
    }

    private func validateText(_ value: String, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MascotPackError.missingField(field)
        }
    }
}
