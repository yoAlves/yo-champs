import AppKit
import ImageIO
import OSLog
import YoChampsCore

/// Draws semantic companion states as frames from the mascot sprite sheet.
///
/// The renderer owns every timing decision: one timer per animated state,
/// none for a single-frame resting state, and none while hidden. It never
/// touches AppKit windows — the panel controller hosts `currentImage`.
@MainActor
final class MascotRenderer {
    private let sequence: MascotFrameSequence
    private let sheet: CGImage?
    private let scale: CGFloat
    private let logger = Logger(subsystem: "com.yurioliveira.yochamps", category: "mascot")

    private var state: CompanionState = .idle
    private var isHidden = false
    private var frameIndices: [Int] = []
    private var framePosition = 0
    private var timer: Timer?
    private var image: NSImage?

    /// Frame size in points after applying the manifest scale.
    var frameDisplaySize: NSSize {
        let size = sequence.frameSize
        return NSSize(
            width: CGFloat(size.width) * scale,
            height: CGFloat(size.height) * scale
        )
    }

    /// Invoked on the main actor whenever the displayed frame changes. The
    /// panel controller uses it to push new frames into its image view.
    var onFrameChange: ((NSImage?) -> Void)?

    var currentImage: NSImage? {
        image
    }

    init(pack: MascotPack) {
        sequence = MascotFrameSequence(manifest: pack.manifest)
        scale = CGFloat(pack.manifest.scale)
        sheet = Self.loadSheet(from: pack.spritesheetURL)
        rebuildAnimation()
    }

    isolated deinit {
        timer?.invalidate()
    }

    func setState(_ newState: CompanionState) {
        guard state != newState else { return }
        state = newState
        rebuildAnimation()
    }

    func setHidden(_ hidden: Bool) {
        guard isHidden != hidden else { return }
        isHidden = hidden
        if hidden {
            stopTimer()
        } else {
            startTimer()
        }
    }

    // MARK: - Animation

    /// Reset to the first frame of `state` and rebuild its timer. Called on
    /// init and on state changes; the window itself is never re-created.
    private func rebuildAnimation() {
        stopTimer()
        frameIndices = sequence.frameIndices(for: state)
        framePosition = 0
        updateImage()
        startTimer()
    }

    /// A timer exists only for a multi-frame animation while visible. A
    /// one-frame idle state deliberately has no repeating work.
    private func startTimer() {
        guard !isHidden, frameIndices.count > 1, timer == nil else { return }
        let fps = sequence.fps(for: state)
        guard fps > 0, fps.isFinite else { return }
        let timer = Timer(
            timeInterval: 1.0 / fps,
            repeats: true
        ) { [weak self] _ in
            // The timer is installed on the main run loop, so this is safe.
            MainActor.assumeIsolated {
                self?.advance()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        guard frameIndices.count > 1 else {
            stopTimer()
            return
        }
        if framePosition + 1 < frameIndices.count {
            framePosition += 1
            updateImage()
        } else if sequence.loops(for: state) {
            framePosition = 0
            updateImage()
        } else {
            // Non-looping animations rest on their last frame.
            stopTimer()
        }
    }

    // MARK: - Drawing

    private func updateImage() {
        guard let sheet, frameIndices.indices.contains(framePosition) else {
            image = nil
            onFrameChange?(nil)
            return
        }
        let size = sequence.frameSize
        let rect = CGRect(
            x: frameIndices[framePosition] * size.width,
            y: 0,
            width: size.width,
            height: size.height
        )
        guard let cropped = sheet.cropping(to: rect) else {
            let position = framePosition
            logger.error("mascot frame \(position, privacy: .public) outside sprite sheet")
            image = nil
            onFrameChange?(nil)
            return
        }
        image = NSImage(cgImage: cropped, size: frameDisplaySize)
        onFrameChange?(image)
    }

    private static func loadSheet(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
