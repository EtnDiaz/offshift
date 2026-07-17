import AppKit
import SwiftUI

/// Uses adapted, provenance-preserved Red Card Codex sleeping frames. See
/// Resources/ThirdParty/RedCard/NOTICE and ADR 0015 before changing this view.
struct RedCardCodexSleepMascotView: View {
    var size: CGFloat = 150

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.32)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / 0.32) % 6 + 1
            mascot(frame: index)
                .frame(width: size, height: size * 1.375)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mascot(frame: Int) -> some View {
        if let image = RedCardSleepingFrames.image(frame: frame) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .clipped()
        } else {
            // The care surface remains understandable from its text and actions
            // even if a bundled third-party resource is unavailable.
            Color.clear
        }
    }
}

private enum RedCardSleepingFrames {
    static func image(frame: Int) -> NSImage? {
        let name = String(format: "sleeping-%02d", frame)
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "ThirdParty/RedCard/sprites/sleeping"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }
}
