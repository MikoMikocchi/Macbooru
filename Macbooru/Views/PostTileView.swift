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
    @Environment(\.colorScheme) private var scheme

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
                cornerRadius: 16
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
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    imageLoaded = true
                }
            }

            // Современный градиентный оверлей
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(hover ? 0.4 : 0.25),
                    .black.opacity(hover ? 0.7 : 0.5),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.4),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.25), value: hover)

            // Инфо-строка с улучшенным дизайном
            HStack(spacing: 10) {
                if let r = post.rating {
                    ModernRatingChip(rating: r)
                        .transition(.scale.combined(with: .opacity))
                }
                if let w = post.width, let h = post.height {
                    ModernSizeBadge(width: w, height: h)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .opacity(imageLoaded ? (hover ? 1 : 0.95) : 0)
            .animation(.easeInOut(duration: 0.2), value: hover)
            .animation(.easeInOut(duration: 0.3).delay(0.1), value: imageLoaded)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(hover ? 1.03 : 1.0)
        .shadow(
            color: .black.opacity(hover ? 0.3 : 0.15),
            radius: hover ? 20 : 8,
            x: 0,
            y: hover ? 10 : 4
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                hover = hovering
            }
        }
        .overlay(alignment: .topTrailing) {
            if post.isFavorited == true {
                Image(systemName: "heart.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.pink, .white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .scaleEffect(hover ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
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
}

// Используются единые компоненты RatingChip/ScoreChip/SizeChip из Theme.swift

private struct VisualBlurOverlay: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }
}

// Более контрастный рейтинг-чип для плитки
private struct ModernRatingChip: View {
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
            Text(r.uppercased()).fontWeight(.bold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [bg, bg.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .foregroundStyle(Color.white)
        .shadow(color: bg.opacity(0.4), radius: 4, x: 0, y: 2)
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// Современный компактный бейдж размера
private struct ModernSizeBadge: View {
    let width: Int
    let height: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "aspectratio").imageScale(.small)
            Text("\(width)x\(height)").fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .foregroundStyle(.primary)
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
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
