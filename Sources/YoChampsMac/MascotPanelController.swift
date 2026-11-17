import AppKit

/// NSImageView returns false for `mouseDownCanMoveWindow`, which would make the
/// panel's `isMovableByWindowBackground` setting ineffective.
private final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

/// Hosts the mascot renderer in a floating, borderless window and remembers
/// where the user dragged it. The panel itself is created once; state changes
/// only swap the image view's contents through `MascotRenderer.onFrameChange`.
@MainActor
final class MascotPanelController: NSObject, NSWindowDelegate {
    private static let originKey = "mascotPanelOrigin"
    private static let margin: CGFloat = 24

    private let renderer: MascotRenderer
    private let defaults: UserDefaults?
    private let onHide: () -> Void

    // Exposed so the later hotkey/accessibility task can configure the window
    // and image view without rebuilding them.
    let panel: NSPanel
    let imageView: NSImageView

    init(renderer: MascotRenderer, onHide: @escaping () -> Void = {}) {
        self.renderer = renderer
        self.onHide = onHide
        // Standard is this app's `com.yurioliveira.yochamps` domain. Passing
        // that bundle ID as a suite name is rejected by Foundation.
        defaults = UserDefaults.standard

        let size = renderer.currentImage?.size ?? renderer.frameDisplaySize
        let imageView = DraggableImageView(frame: NSRect(origin: .zero, size: size))
        imageView.image = renderer.currentImage
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.isEditable = false
        imageView.setAccessibilityIdentifier("mascotPanel")
        self.imageView = imageView

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.ignoresMouseEvents = true // hidden until show()
        panel.setAccessibilityIdentifier("mascotPanel")
        panel.contentView = imageView
        self.panel = panel

        super.init()

        panel.delegate = self
        renderer.onFrameChange = { [weak self] image in
            self?.imageView.image = image
        }
        renderer.setHidden(true)
    }

    func show() {
        let origin = Self.storedOrigin(in: defaults) ?? defaultOrigin()
        panel.setFrameOrigin(clampedOrigin(origin))
        panel.ignoresMouseEvents = false
        renderer.setHidden(false)
        panel.orderFront(nil)
    }

    func hide() {
        renderer.setHidden(true)
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
        onHide()
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    var frame: NSRect {
        panel.frame
    }

    // MARK: - Placement

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        let clamped = clampedOrigin(origin)
        if clamped != origin {
            panel.setFrameOrigin(clamped)
        }
        Self.saveOrigin(panel.frame.origin, in: defaults)
    }

    /// ⌘W (and any other close path) hides Champ without ending the process.
    /// `hide()` stops the in-flight turn, so nothing streams while invisible.
    func windowWillClose(_ notification: Notification) {
        hide()
    }

    /// Keep the panel's top-left inside the bounding box of all visible screen
    /// frames. This pulls a saved position back on screen after a display is
    /// removed or the window is dragged beyond every screen.
    private func clampedOrigin(_ origin: NSPoint) -> NSPoint {
        let screens = NSScreen.screens
        guard let first = screens.first else { return origin }
        let visible = screens.dropFirst().reduce(first.visibleFrame) { $0.union($1.visibleFrame) }
        let size = panel.frame.size
        let maxX = visible.maxX - min(size.width, visible.width)
        let maxY = visible.maxY - min(size.height, visible.height)
        return NSPoint(
            x: min(max(origin.x, visible.minX), maxX),
            y: min(max(origin.y, visible.minY), maxY)
        )
    }

    private func defaultOrigin() -> NSPoint {
        let visible = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        return NSPoint(
            x: visible.maxX - panel.frame.width - Self.margin,
            y: visible.minY + Self.margin
        )
    }

    // MARK: - Persistence

    private static func storedOrigin(in defaults: UserDefaults?) -> NSPoint? {
        guard let values = defaults?.array(forKey: originKey) as? [NSNumber], values.count == 2 else {
            return nil
        }
        return NSPoint(x: values[0].doubleValue, y: values[1].doubleValue)
    }

    private static func saveOrigin(_ origin: NSPoint, in defaults: UserDefaults?) {
        defaults?.set([origin.x, origin.y], forKey: originKey)
    }
}
