import AppKit
import SwiftUI

/// The user-selected, adapted Red Card Codex mark. Its provenance is recorded
/// in ADR 0015 and docs/third-party/redcard-codex-mascot.md.
struct OffshiftBrandMarkView: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = OffshiftBrandMark.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
enum OffshiftBrandMark {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(
            forResource: "sleeping-codex-logo",
            withExtension: "png",
            subdirectory: "ThirdParty/RedCard/brand"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }()
}
