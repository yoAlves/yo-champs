import AppKit
import SwiftUI

/// Draws the renderer's current frame in a fixed, non-editable image view.
/// Published frame changes from `MascotRenderer` flow through `updateNSView`.
struct MascotImageView: NSViewRepresentable {
    @ObservedObject var renderer: MascotRenderer

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.isEditable = false
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.setAccessibilityIdentifier("mascotPanel")
        updateNSView(imageView, context: context)
        return imageView
    }

    func updateNSView(_ uiView: NSImageView, context: Context) {
        uiView.image = renderer.currentImage
        uiView.setFrameSize(renderer.frameDisplaySize)
    }
}
