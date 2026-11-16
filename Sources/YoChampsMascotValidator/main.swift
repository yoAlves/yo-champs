import CoreGraphics
import Darwin
import Foundation
import ImageIO
import YoChampsCore

func localPackDirectories(fileManager: FileManager) -> [URL] {
    let support = fileManager.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/YoChamps/Mascots")
    guard let entries = try? fileManager.contentsOfDirectory(
        at: support,
        includingPropertiesForKeys: [.isDirectoryKey]
    ) else {
        return []
    }
    return entries.filter { url in
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

func pngSize(at url: URL) throws -> PixelSize {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw MascotPackError.invalidImage(url.path)
    }
    return PixelSize(width: image.width, height: image.height)
}

let fileManager = FileManager.default
let validator = MascotPackValidator(imageSize: pngSize)

var packs = Array(CommandLine.arguments.dropFirst())
if packs.isEmpty {
    let defaultPack = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .appending(path: "Resources/Mascots/Default")
    packs = [defaultPack.path] + localPackDirectories(fileManager: fileManager).map(\.path)
}

var failures = 0
for pack in packs {
    let url = URL(fileURLWithPath: pack)
    do {
        try validator.validate(packAt: url)
        print("ok  \(pack)")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("fail \(pack): \(error)\n".utf8))
    }
}

if failures > 0 {
    exit(EXIT_FAILURE)
}

print("validated \(packs.count) pack(s)")
