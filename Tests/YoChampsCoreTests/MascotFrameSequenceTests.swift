import Foundation
import Testing
@testable import YoChampsCore

@Suite("MascotFrameSequence")
struct MascotFrameSequenceTests {
    private let frameSize = MascotManifest.Size(width: 64, height: 64)
    private let anchor = MascotManifest.Anchor(x: 0.5, y: 1.0)

    private func makeManifest(
        animations: [String: MascotManifest.Animation]? = nil
    ) -> MascotManifest {
        MascotManifest(
            id: "test",
            name: "Test",
            version: "1.0.0",
            author: "Test",
            license: "MIT",
            frameSize: frameSize,
            scale: 1,
            anchor: anchor,
            animations: animations ?? Self.task1Animations
        )
    }

    /// Frame counts from the Task 1 Champ pack: 1, 2, 3, 2, 2, 2 (12 total).
    private static let task1Animations: [String: MascotManifest.Animation] = [
        "idle": .init(frames: 1, fps: 6, loop: true),
        "thinking": .init(frames: 2, fps: 6, loop: true),
        "talking": .init(frames: 3, fps: 8, loop: true),
        "happy": .init(frames: 2, fps: 8, loop: false),
        "confused": .init(frames: 2, fps: 8, loop: false),
        "error": .init(frames: 2, fps: 8, loop: false),
    ]

    @Test("states map explicitly to the six required animation ids")
    func animationIDs() {
        let sequence = MascotFrameSequence(manifest: makeManifest())
        #expect(sequence.animationID(for: .idle) == "idle")
        #expect(sequence.animationID(for: .thinking) == "thinking")
        #expect(sequence.animationID(for: .streaming) == "talking")
        #expect(sequence.animationID(for: .happy) == "happy")
        #expect(sequence.animationID(for: .confused) == "confused")
        #expect(sequence.animationID(for: .error) == "error")
    }

    @Test("frame indices are absolute offsets from orderedAnimationIds")
    func frameIndices() {
        let sequence = MascotFrameSequence(manifest: makeManifest())
        #expect(sequence.frameIndices(for: .idle) == [0])
        #expect(sequence.frameIndices(for: .thinking) == [1, 2])
        #expect(sequence.frameIndices(for: .streaming) == [3, 4, 5])
        #expect(sequence.frameIndices(for: .happy) == [6, 7])
        #expect(sequence.frameIndices(for: .confused) == [8, 9])
        #expect(sequence.frameIndices(for: .error) == [10, 11])
    }

    @Test("loops and fps come from the mapped animation")
    func loopsAndFPS() {
        let sequence = MascotFrameSequence(manifest: makeManifest())
        #expect(sequence.loops(for: .idle) == true)
        #expect(sequence.loops(for: .happy) == false)
        #expect(sequence.fps(for: .idle) == 6)
        #expect(sequence.fps(for: .thinking) == 6)
        #expect(sequence.fps(for: .streaming) == 8)
        #expect(sequence.fps(for: .happy) == 8)
    }

    @Test("offsets follow the manifest, not a fixed pack")
    func offsetsAreDerivedFromManifest() {
        var animations = Self.task1Animations
        animations["idle"] = .init(frames: 2, fps: 4, loop: true)
        animations["thinking"] = .init(frames: 1, fps: 5, loop: true)
        let sequence = MascotFrameSequence(manifest: makeManifest(animations: animations))

        #expect(sequence.frameIndices(for: .idle) == [0, 1])
        #expect(sequence.frameIndices(for: .thinking) == [2])
        #expect(sequence.frameIndices(for: .streaming) == [3, 4, 5])
        #expect(sequence.fps(for: .idle) == 4)
        #expect(sequence.fps(for: .thinking) == 5)
    }

    @Test("extra animations do not shift required animation offsets")
    func extraAnimationsAreIgnored() {
        var animations = Self.task1Animations
        animations["celebrate"] = .init(frames: 4, fps: 10, loop: false)
        let sequence = MascotFrameSequence(manifest: makeManifest(animations: animations))

        #expect(sequence.frameIndices(for: .idle) == [0])
        #expect(sequence.frameIndices(for: .thinking) == [1, 2])
        #expect(sequence.frameIndices(for: .streaming) == [3, 4, 5])
        #expect(sequence.frameIndices(for: .error) == [10, 11])
    }

    @Test("frame size and anchor are exposed unchanged")
    func geometryPassthrough() {
        let sequence = MascotFrameSequence(manifest: makeManifest())
        #expect(sequence.frameSize == frameSize)
        #expect(sequence.anchor == anchor)
    }
}
