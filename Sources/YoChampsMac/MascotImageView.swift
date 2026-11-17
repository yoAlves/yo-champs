import AppKit
import SwiftUI

/// Draws the renderer's current frame in a fixed, non-editable image view.
/// Published frame changes from `MascotRenderer` flow through `updateNSView`.
/// With `avatarSize` set, the view scales proportionally into that fixed
/// frame (SwiftUI sizes the NSView) instead of drawing at `frameDisplaySize`.
struct MascotImageView: NSViewRepresentable {
    @ObservedObject var renderer: MascotRenderer
    var avatarSize: CGSize?

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.isEditable = false
        imageView.imageScaling = avatarSize == nil
            ? .scaleNone
            : .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.setAccessibilityIdentifier("mascotPanel")
        updateNSView(imageView, context: context)
        return imageView
    }

    func updateNSView(_ uiView: NSImageView, context: Context) {
        uiView.image = renderer.currentImage
        if avatarSize == nil {
            uiView.setFrameSize(renderer.frameDisplaySize)
        }
    }
}
