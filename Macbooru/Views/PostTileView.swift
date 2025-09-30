import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostTileView: View {
    let post: Post
    let height: CGFloat
    @State private var hover = false
    @EnvironmentObject private var search: SearchState

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(
                candidates: [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 },
                height: height,
                contentMode: .fit,
                animateFirstAppearance: true,
                animateUpgrades: false
            )
            // Усиленный блюр самого изображения для NSFW
            .blur(
                radius: {
                    guard search.blurSensitive, let r = post.rating?.lowercased() else { return 0 }
                    switch r {
                    case "e": return 16
                    case "q": return 12
                    default: return 0
                    }
                }()
            )
            .padding(6)
            .overlay(
                // Накладываем блюр/материал поверх для NSFW, если включено в настройках
                Group {
                    if search.blurSensitive, let r = post.rating?.lowercased(),
                        ["q", "e"].contains(r)
                    {
                        VisualBlurOverlay()
                    }
                }
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
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hover = $0 }
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

#if os(macOS)
    private struct VisualBlurOverlay: View {
        var body: some View {
            ZStack {
                VisualMaterialView(
                    material: .hudWindow, blendingMode: .withinWindow, state: .active
                )
                .opacity(0.95)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Color.black.opacity(0.25)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Image(systemName: "eye.slash")
                    .font(.title3.weight(.semibold))
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
            }
            .allowsHitTesting(false)
        }
    }
    // Local NSVisualEffectView wrapper for blur/material overlays
    private struct VisualMaterialView: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
        var state: NSVisualEffectView.State = .active

        func makeNSView(context: Context) -> NSVisualEffectView {
            let v = NSVisualEffectView()
            v.material = material
            v.blendingMode = blendingMode
            v.state = state
            v.isEmphasized = true
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }

        func updateNSView(_ v: NSVisualEffectView, context: Context) {
            v.material = material
            v.blendingMode = blendingMode
            v.state = state
        }
    }
#else
    private struct VisualBlurOverlay: View {
        var body: some View {
            Color.black.opacity(0.4)
                .overlay(
                    Image(systemName: "eye.slash")
                        .font(.title3.weight(.semibold))
                        .padding(6)
                        .background(.thinMaterial, in: Capsule())
                )
                .allowsHitTesting(false)
        }
    }
#endif

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
