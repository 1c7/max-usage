import AppKit
import SwiftUI

/// Renders the OpenUsage brand gauge mark into a template `NSImage` for the menu bar.
/// Reuses the same SVG→`ProviderIconShape` pipeline as the provider tiles, so there is no
/// asset catalog or second SVG parser to maintain.
@MainActor
enum MenuBarIcon {
    private static let side: CGFloat = 18

    static let image: NSImage? = render()

    private static func render() -> NSImage? {
        let renderer = ImageRenderer(
            content: Image(systemName: "hare.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
                .frame(width: 15, height: 15)
        )
        renderer.scale = 2
        guard let nsImage = renderer.nsImage else { return nil }
        nsImage.size = NSSize(width: side, height: side)
        nsImage.isTemplate = true
        return nsImage
    }
}
