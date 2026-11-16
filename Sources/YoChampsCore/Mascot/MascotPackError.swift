import Foundation

/// Validation failures for mascot packs. Messages are user-facing because the
/// validator CLI prints them verbatim.
public enum MascotPackError: Error, Equatable, CustomStringConvertible {
    case invalidSchemaVersion(Int)
    case missingField(String)
    case invalidFrameSize(width: Int, height: Int)
    case invalidScale(Double)
    case invalidAnchor(x: Double, y: Double)
    case missingAnimation(String)
    case invalidAnimationFrames(name: String, frames: Int)
    case invalidAnimationFPS(name: String, fps: Double)
    case missingFile(String)
    case invalidJSON(String)
    case invalidImage(String)
    case spritesheetMismatch(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case fileTooLarge(path: String, bytes: Int, limit: Int)

    public var description: String {
        switch self {
        case let .invalidSchemaVersion(version):
            "schemaVersion must be at least 1 (got \(version))"
        case let .missingField(field):
            "manifest field '\(field)' is empty or missing"
        case let .invalidFrameSize(width, height):
            "frameSize must be between 1 and \(MascotManifest.maxFrameDimension) (got \(width)x\(height))"
        case let .invalidScale(scale):
            "scale must be a positive number (got \(scale))"
        case let .invalidAnchor(x, y):
            "anchor must be normalized to 0...1 (got x=\(x), y=\(y))"
        case let .missingAnimation(id):
            "required animation '\(id)' is missing"
        case let .invalidAnimationFrames(name, frames):
            "animation '\(name)' must have between 1 and \(MascotManifest.maxAnimationFrames) frames (got \(frames))"
        case let .invalidAnimationFPS(name, fps):
            "animation '\(name)' must have a positive fps (got \(fps))"
        case let .missingFile(path):
            "missing file: \(path)"
        case let .invalidJSON(path):
            "invalid manifest JSON: \(path)"
        case let .invalidImage(path):
            "unreadable PNG: \(path)"
        case let .spritesheetMismatch(expectedWidth, expectedHeight, actualWidth, actualHeight):
            "spritesheet is \(actualWidth)x\(actualHeight), expected \(expectedWidth)x\(expectedHeight)"
        case let .fileTooLarge(path, bytes, limit):
            "\(path) is \(bytes) bytes, over the \(limit) byte limit"
        }
    }
}
