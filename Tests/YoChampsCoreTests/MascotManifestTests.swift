import Foundation
import Testing
@testable import YoChampsCore

@Suite("MascotManifest")
struct MascotManifestTests {
    static let validJSON = """
    {
      "schemaVersion": 1,
      "id": "champ",
      "name": "Champ",
      "version": "0.1.0",
      "author": "Yo Champs",
      "license": "CC-BY-4.0",
      "frameSize": { "width": 64, "height": 64 },
      "scale": 2.0,
      "anchor": { "x": 0.5, "y": 1.0 },
      "animations": {
        "idle": { "frames": 2, "fps": 8, "loop": true },
        "thinking": { "frames": 1, "fps": 8, "loop": true },
        "talking": { "frames": 1, "fps": 8, "loop": true },
        "happy": { "frames": 1, "fps": 8, "loop": false },
        "confused": { "frames": 1, "fps": 8, "loop": false },
        "error": { "frames": 1, "fps": 8, "loop": false },
        "celebrate": { "frames": 1, "fps": 8, "loop": false }
      }
    }
    """

    private func decode(_ json: String) throws -> MascotManifest {
        try JSONDecoder().decode(MascotManifest.self, from: Data(json.utf8))
    }

    @Test("decodes a valid manifest")
    func decodesValidManifest() throws {
        let manifest = try decode(Self.validJSON)
        #expect(manifest.id == "champ")
        #expect(manifest.frameSize == MascotManifest.Size(width: 64, height: 64))
        #expect(manifest.animations["idle"]?.frames == 2)
    }

    @Test("valid manifest passes validation")
    func validManifestPassesValidation() throws {
        try decode(Self.validJSON).validate()
    }

    @Test("frame order puts required animations first, then extras sorted")
    func frameOrder() throws {
        let manifest = try decode(Self.validJSON)
        #expect(manifest.orderedAnimationIds == [
            "idle", "thinking", "talking", "happy", "confused", "error", "celebrate",
        ])
        #expect(manifest.totalFrames == 8)
    }

    @Test("missing required animation is rejected")
    func missingRequiredAnimation() throws {
        let json = Self.validJSON.replacingOccurrences(
            of: "\"confused\": { \"frames\": 1, \"fps\": 8, \"loop\": false },",
            with: ""
        )
        let manifest = try decode(json)
        #expect(throws: MascotPackError.missingAnimation("confused")) {
            try manifest.validate()
        }
    }

    @Test("non-positive frame size is rejected")
    func invalidFrameSize() throws {
        let json = Self.validJSON.replacingOccurrences(of: "\"width\": 64", with: "\"width\": 0")
        let manifest = try decode(json)
        #expect(throws: MascotPackError.invalidFrameSize(width: 0, height: 64)) {
            try manifest.validate()
        }
    }

    @Test("blank identity field is rejected")
    func blankField() throws {
        let json = Self.validJSON.replacingOccurrences(of: "\"Champ\"", with: "\"  \"")
        let manifest = try decode(json)
        #expect(throws: MascotPackError.missingField("name")) {
            try manifest.validate()
        }
    }

    @Test("empty animations are rejected")
    func invalidAnimationFrames() throws {
        let json = Self.validJSON.replacingOccurrences(of: "\"frames\": 2", with: "\"frames\": 0")
        let manifest = try decode(json)
        #expect(throws: MascotPackError.invalidAnimationFrames(name: "idle", frames: 0)) {
            try manifest.validate()
        }
    }

    @Test("manifest without schemaVersion is rejected at decode")
    func missingSchemaVersion() {
        let json = Self.validJSON.replacingOccurrences(of: "\"schemaVersion\": 1,", with: "")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MascotManifest.self, from: Data(json.utf8))
        }
    }

    @Test("schemaVersion must be at least 1")
    func invalidSchemaVersion() throws {
        let json = Self.validJSON.replacingOccurrences(
            of: "\"schemaVersion\": 1",
            with: "\"schemaVersion\": 0"
        )
        let manifest = try decode(json)
        #expect(throws: MascotPackError.invalidSchemaVersion(0)) {
            try manifest.validate()
        }
    }

    @Test("oversized frames and frame sizes are rejected")
    func oversizedGeometry() throws {
        let json = Self.validJSON.replacingOccurrences(of: "\"width\": 64", with: "\"width\": 8192")
        let manifest = try decode(json)
        #expect(throws: MascotPackError.invalidFrameSize(width: 8192, height: 64)) {
            try manifest.validate()
        }
    }
}
