import SwiftUI

struct PostTileView: View {
    let post: Post
    let height: CGFloat
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(
                candidates: [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 },
                height: height,
                contentMode: .fill,
                animateFirstAppearance: true,
                animateUpgrades: false
            )
            if hover {
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.0), .black.opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
                HStack(spacing: 8) {
                    if let rating = post.rating { Badge(text: rating.uppercased()) }
                    if let w = post.width, let h = post.height { Badge(text: "\(w)x\(h)") }
                    if let score = post.score { Badge(text: "★ \(score)") }
                }
                .padding(8)
            }
        }
        .onHover { hover = $0 }
        .contextMenu {
            if let url = post.fileURL { Link("Open original in Browser", destination: url) }
            if let url = post.largeURL { Link("Open large in Browser", destination: url) }
            if let url = post.previewURL { Link("Open preview in Browser", destination: url) }
        }
    }
}

private struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
