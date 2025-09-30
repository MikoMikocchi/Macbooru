import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostTileView: View {
    let post: Post
    let height: CGFloat
    @State private var hover = false
    @EnvironmentObject private var search: SearchState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(
                candidates: [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 },
                height: height,
                contentMode: .fit,
                animateFirstAppearance: true,
                animateUpgrades: false,
                interpolation: .medium,
                decoratedBackground: false,
                cornerRadius: 10
            )
            // Усиленный блюр самого изображения для NSFW
            .blur(
                radius: {
                    guard search.blurSensitive, let r = post.rating?.lowercased() else { return 0 }
                    switch r {
                    case "e": return 10
                    case "q": return 6
                    default: return 0
                    }
                }()
            )
            .padding(0)
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
            // Градиентный оверлей снизу для читаемости бейджей
            LinearGradient(
                gradient: Gradient(colors: [
                    .black.opacity(0.0), .black.opacity(hover ? 0.65 : 0.45),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Инфо-строка
            HStack(spacing: 8) {
                if let r = post.rating { SolidRatingChip(rating: r) }
                if let w = post.width, let h = post.height { SizeBadge(width: w, height: h) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .opacity(hover ? 1 : 0.92)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        // Используются унифицированные компоненты RatingChip/ScoreChip/SizeChip из Theme.swift
        .fixedSize(horizontal: false, vertical: true)
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

// Используются единые компоненты RatingChip/ScoreChip/SizeChip из Theme.swift

private struct VisualBlurOverlay: View {
    var body: some View {
        Color.black.opacity(0.35)
            .overlay(
                Image(systemName: "eye.slash")
                    .font(.title3.weight(.semibold))
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .allowsHitTesting(false)
    }
}

// Более контрастный рейтинг-чип для плитки
private struct SolidRatingChip: View {
    let rating: String
    var body: some View {
        let r = rating.lowercased()
        let (bg, icon): (Color, String) = {
            switch r {
            case "g": return (.green, "checkmark.seal.fill")
            case "s": return (.blue, "hand.raised.fill")
            case "q": return (.orange, "exclamationmark.triangle.fill")
            default: return (.red, "nosign")
            }
        }()
        HStack(spacing: 6) {
            Image(systemName: icon).imageScale(.small)
            Text(r.uppercased()).fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(bg, in: Capsule())
        .foregroundStyle(Color.white)
        .shadow(color: bg.opacity(0.3), radius: 3, y: 1)
    }
}

// Локальный компактный бейдж размера, чтобы не зависеть от Theme
private struct SizeBadge: View {
    let width: Int
    let height: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "aspectratio").imageScale(.small)
            Text("\(width)x\(height)").fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.cyan.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1))
        .foregroundStyle(.cyan)
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
