import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostTileView: View {
    let post: Post
    let height: CGFloat
    @State private var hover = false
    @State private var imageLoaded = false
    @EnvironmentObject private var search: SearchState

    private let cornerRadius = Theme.Constants.cornerRadius

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(
                candidates: [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 },
                height: height,
                contentMode: .fit,
                animateFirstAppearance: !search.lowPerformance,
                animateUpgrades: false,
                interpolation: search.lowPerformance ? .low : .medium,
                decoratedBackground: false,
                cornerRadius: cornerRadius
            )
            .blur(radius: blurRadius)
            .overlay(sensitiveOverlay)
            .onAppear {
                withAnimation(Theme.Animations.hover.delay(0.05)) {
                    imageLoaded = true
                }
            }

            Theme.Gradients.modernOverlay(opacity: hover ? 0.7 : 0.52)
                .allowsHitTesting(false)
                .animation(Theme.Animations.hover, value: hover)

            infoRow
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .opacity(imageLoaded ? (hover ? 1.0 : 0.94) : 0)
                .offset(y: imageLoaded ? 0 : 14)
                .animation(Theme.Animations.hover, value: hover)
                .animation(Theme.Animations.interactive.delay(0.12), value: imageLoaded)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(hover ? 0.35 : 0.18), lineWidth: 1.2)
                .blendMode(.overlay)
        )
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .hoverLift(scale: 1.035, shadow: 22, isHovering: $hover)
        .overlay(alignment: .topTrailing) {
            if post.isFavorited == true {
                favoriteBadge
            }
        }
        .contextMenu {
            if let url = post.fileURL { Link("Open original in Browser", destination: url) }
            if let url = post.largeURL { Link("Open large in Browser", destination: url) }
            if let url = post.previewURL { Link("Open preview in Browser", destination: url) }
            if let src = post.source, let u = URL(string: src) {
                Divider()
                Link("Open source", destination: u)
            }
            Divider()
            if let url = post.fileURL {
                Button("Copy original URL") { copyToClipboard(url.absoluteString) }
            }
            if let url = post.largeURL {
                Button("Copy large URL") { copyToClipboard(url.absoluteString) }
            }
            if let url = post.previewURL {
                Button("Copy preview URL") { copyToClipboard(url.absoluteString) }
            }
            Button("Copy tags") {
                let tags = post.allTags.joined(separator: " ")
                copyToClipboard(tags)
            }
        }
    }

    private var blurRadius: CGFloat {
        guard search.blurSensitive, let rating = post.rating?.lowercased() else { return 0 }
        switch rating {
        case "e": return 10
        case "q": return 6
        default: return 0
        }
    }

    @ViewBuilder
    private var sensitiveOverlay: some View {
        if search.blurSensitive, let rating = post.rating?.lowercased(), ["q", "e"].contains(rating) {
            VisualBlurOverlay(cornerRadius: cornerRadius)
        }
    }

    @ViewBuilder
    private var infoRow: some View {
        HStack(spacing: 10) {
            if let rating = post.rating {
                RatingChip(rating: rating)
                    .transition(.opacity.combined(with: .scale))
            }
            if let width = post.width, let height = post.height {
                SizeBadge(width: width, height: height)
                    .transition(.opacity.combined(with: .scale))
            }
            if let score = post.score {
                ScoreChip(score: score)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var favoriteBadge: some View {
        Image(systemName: "heart.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.pink, .white)
            .padding(12)
            .background(.ultraThinMaterial, in: Circle())
            .scaleEffect(hover ? 1.08 : 1.0)
            .animation(Theme.Animations.interactive, value: hover)
    }
}

private struct VisualBlurOverlay: View {
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)

            VStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.title2.weight(.semibold))
                Text("Sensitive")
                    .font(.caption.weight(.medium))
            }
            .padding(12)
            .background(
                .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Clipboard helpers
private func copyToClipboard(_ text: String) {
    #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    #else
        UIPasteboard.general.string = text
    #endif
}
