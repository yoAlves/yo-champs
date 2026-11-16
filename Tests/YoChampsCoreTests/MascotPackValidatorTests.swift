import Foundation
import Testing
@testable import YoChampsCore

@Suite("MascotPackValidator")
struct MascotPackValidatorTests {
    private let manifestJSON = """
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
        "error": { "frames": 1, "fps": 8, "loop": false }
      }
    }
    """

    private func makePack(
        manifest: String? = nil,
        spritesheetBytes: Int = 64,
        previewBytes: Int = 64
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "yo-champs-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data((manifest ?? manifestJSON).utf8).write(to: directory.appending(path: "manifest.json"))
        try Data(repeating: 0, count: spritesheetBytes)
            .write(to: directory.appending(path: "spritesheet.png"))
        try Data(repeating: 0, count: previewBytes).write(to: directory.appending(path: "preview.png"))
        return directory
    }

    private func validator(sheet: PixelSize = PixelSize(width: 448, height: 64)) -> MascotPackValidator {
        MascotPackValidator { url in
            url.lastPathComponent == "spritesheet.png" ? sheet : PixelSize(width: 128, height: 128)
        }
    }

    @Test("valid pack passes")
    func validPack() throws {
        let pack = try makePack()
        defer { try? FileManager.default.removeItem(at: pack) }
        try validator().validate(packAt: pack)
    }

    @Test("missing file is reported")
    func missingFile() throws {
        let pack = try makePack()
        defer { try? FileManager.default.removeItem(at: pack) }
        try FileManager.default.removeItem(at: pack.appending(path: "preview.png"))

        #expect(throws: MascotPackError.missingFile(pack.appending(path: "preview.png").path)) {
            try validator().validate(packAt: pack)
        }
    }

    @Test("oversize file is reported")
    func oversizePreview() throws {
        let pack = try makePack(previewBytes: MascotPackValidator.maxPreviewBytes + 1)
        defer { try? FileManager.default.removeItem(at: pack) }

        #expect(throws: MascotPackError.fileTooLarge(
            path: pack.appending(path: "preview.png").path,
            bytes: MascotPackValidator.maxPreviewBytes + 1,
            limit: MascotPackValidator.maxPreviewBytes
        )) {
            try validator().validate(packAt: pack)
        }
    }

    @Test("spritesheet geometry must match the manifest")
    func spritesheetMismatch() throws {
        let pack = try makePack()
        defer { try? FileManager.default.removeItem(at: pack) }

        #expect(throws: MascotPackError.spritesheetMismatch(
            expectedWidth: 448,
            expectedHeight: 64,
            actualWidth: 64,
            actualHeight: 64
        )) {
            try validator(sheet: PixelSize(width: 64, height: 64)).validate(packAt: pack)
        }
    }

    @Test("unreadable image is reported")
    func unreadableImage() throws {
        let pack = try makePack()
        defer { try? FileManager.default.removeItem(at: pack) }
        let validator = MascotPackValidator { url in
            throw MascotPackError.invalidImage(url.path)
        }

        #expect(throws: MascotPackError.invalidImage(pack.appending(path: "spritesheet.png").path)) {
            try validator.validate(packAt: pack)
        }
    }

    @Test("invalid manifest JSON is reported")
    func invalidJSON() throws {
        let pack = try makePack(manifest: "{not json")
        defer { try? FileManager.default.removeItem(at: pack) }

        #expect(throws: MascotPackError.invalidJSON(pack.appending(path: "manifest.json").path)) {
            try validator().validate(packAt: pack)
        }
    }
}
