// Generates the placeholder "Champ" pack: a transparent paperclip silhouette
// in six semantic states on a horizontal strip. Original art, CC BY 4.0.
//
// Usage: swift scripts/gen-placeholder-pack.swift [outputDir]
import CoreGraphics
import Foundation
import ImageIO

let frameSize = 64
let stripFrames = 6
let outputDir = URL(
    fileURLWithPath: CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "Resources/Mascots/Default"
)

struct State {
    let id: String
    let color: CGColor
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, 1])!
}

let states: [State] = [
    State(id: "idle", color: color(0.45, 0.47, 0.52)),
    State(id: "thinking", color: color(0.25, 0.52, 0.90)),
    State(id: "talking", color: color(0.24, 0.68, 0.45)),
    State(id: "happy", color: color(0.92, 0.68, 0.16)),
    State(id: "confused", color: color(0.90, 0.48, 0.14)),
    State(id: "error", color: color(0.85, 0.26, 0.24)),
]

func paperclipPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 26, y: 14))
    path.addLine(to: CGPoint(x: 26, y: 46))
    path.addCurve(
        to: CGPoint(x: 40, y: 46),
        control1: CGPoint(x: 26, y: 55),
        control2: CGPoint(x: 40, y: 55)
    )
    path.addLine(to: CGPoint(x: 40, y: 22))
    path.addCurve(
        to: CGPoint(x: 31, y: 22),
        control1: CGPoint(x: 40, y: 15),
        control2: CGPoint(x: 31, y: 15)
    )
    path.addLine(to: CGPoint(x: 31, y: 40))
    return path
}

func drawFrame(in context: CGContext, originX: CGFloat, scale: CGFloat, color: CGColor) {
    context.saveGState()
    context.translateBy(x: originX, y: 0)
    context.scaleBy(x: scale, y: scale)

    context.setStrokeColor(color)
    context.setLineWidth(5)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(paperclipPath())
    context.strokePath()

    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: 28, y: 47, width: 2.6, height: 2.6))
    context.fillEllipse(in: CGRect(x: 35, y: 47, width: 2.6, height: 2.6))
    context.restoreGState()
}

func makeContext(width: Int, height: Int) -> CGContext {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("cannot create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("cannot write PNG at \(url.path)")
    }
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let strip = makeContext(width: frameSize * stripFrames, height: frameSize)
for (index, state) in states.enumerated() {
    drawFrame(in: strip, originX: CGFloat(index * frameSize), scale: 1, color: state.color)
}

writePNG(strip.makeImage()!, to: outputDir.appending(path: "spritesheet.png"))

let preview = makeContext(width: frameSize * 2, height: frameSize * 2)
drawFrame(in: preview, originX: 0, scale: 2, color: states[0].color)
writePNG(preview.makeImage()!, to: outputDir.appending(path: "preview.png"))

let animations = states.reduce(into: [String: [String: Any]]()) { result, state in
    result[state.id] = ["frames": 1, "fps": 8, "loop": state.id == "idle" || state.id == "thinking"]
}

let manifest: [String: Any] = [
    "schemaVersion": 1,
    "id": "champ",
    "name": "Champ",
    "version": "0.1.0",
    "author": "Yo Champs",
    "license": "CC-BY-4.0",
    "frameSize": ["width": frameSize, "height": frameSize],
    "scale": 2.0,
    "anchor": ["x": 0.5, "y": 1.0],
    "animations": animations,
]
let json = try JSONSerialization.data(
    withJSONObject: manifest,
    options: [.prettyPrinted, .sortedKeys]
)
try json.write(to: outputDir.appending(path: "manifest.json"))
print("wrote placeholder pack to \(outputDir.path)")
