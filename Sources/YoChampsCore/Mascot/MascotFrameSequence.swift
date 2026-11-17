import Foundation

/// Pure mapping from a semantic `CompanionState` to sprite-sheet frame decisions.
///
/// The renderer owns all image work; this type only decides which frames to draw.
/// Offsets come from the manifest's canonical animation order, so extra packs
/// and different frame counts need no code changes. Manifest validation stays
/// with the caller: a manifest missing a required animation yields no frames.
public struct MascotFrameSequence: Sendable {
    private let manifest: MascotManifest
    private let frameStarts: [String: Int]

    public init(manifest: MascotManifest) {
        self.manifest = manifest

        var starts: [String: Int] = [:]
        var start = 0
        for id in manifest.orderedAnimationIds {
            starts[id] = start
            start += max(0, manifest.animations[id]?.frames ?? 0)
        }
        frameStarts = starts
    }

    /// Explicit state-to-animation table; the model never names an animation.
    public func animationID(for state: CompanionState) -> String {
        switch state {
        case .idle: "idle"
        case .thinking: "thinking"
        case .streaming: "talking"
        case .happy: "happy"
        case .confused: "confused"
        case .error: "error"
        }
    }

    /// Absolute frame indices into the canonical sprite sheet for `state`.
    public func frameIndices(for state: CompanionState) -> [Int] {
        let id = animationID(for: state)
        guard let start = frameStarts[id], let frames = manifest.animations[id]?.frames else {
            return []
        }
        return Array(start ..< (start + frames))
    }

    public func fps(for state: CompanionState) -> Double {
        manifest.animations[animationID(for: state)]?.fps ?? 0
    }

    public func loops(for state: CompanionState) -> Bool {
        manifest.animations[animationID(for: state)]?.loop ?? false
    }

    public var frameSize: MascotManifest.Size {
        manifest.frameSize
    }

    public var anchor: MascotManifest.Anchor {
        manifest.anchor
    }
}
