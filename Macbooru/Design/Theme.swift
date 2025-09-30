import SwiftUI

enum Theme {
    // MARK: - Palette
    struct ColorPalette {
        static var primaryBackground: Color { Color("PrimaryBackground") }
        static var secondaryBackground: Color { Color("SecondaryBackground") }
        static var cardBackground: Color { Color("CardBackground") }

        static var accent: Color { .accentColor }
        static var success: Color { Color.green }
        static var warning: Color { Color.orange }
        static var info: Color { Color.blue }
        static var danger: Color { Color.red }
        static var muted: Color { Color.secondary }
    }

    // MARK: - Gradients
    struct Gradients {
        static var appBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.primaryBackground,
                    ColorPalette.secondaryBackground.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func tileOverlay(strength: Double = 0.55) -> LinearGradient {
            LinearGradient(
                colors: [
                    .black.opacity(0.0),
                    .black.opacity(strength),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Typography
    struct Typography {
        struct Title: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }

        struct SectionHeader: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Surfaces
    struct Card: ViewModifier {
        var cornerRadius: CGFloat = 12
        var showStroke: Bool = true
        var hoverElevates: Bool = true
        @State private var isHover = false

        func body(content: Content) -> some View {
            content
                .background(
                    ColorPalette.cardBackground.opacity(0.6)
                        .blendMode(.plusLighter)
                        .background(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    Group {
                        if showStroke {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                )
                .shadow(
                    color: .black.opacity(isHover && hoverElevates ? 0.18 : 0.10),
                    radius: isHover && hoverElevates ? 14 : 8, y: isHover && hoverElevates ? 6 : 3
                )
                .onHover { isHover = $0 }
        }
    }

    struct Chip: ViewModifier {
        var tint: Color = ColorPalette.muted
        func body(content: Content) -> some View {
            content
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.18), in: Capsule())
                .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
        }
    }
}

extension View {
    func themedCard(cornerRadius: CGFloat = 12, showStroke: Bool = true, hoverElevates: Bool = true)
        -> some View
    {
        modifier(
            Theme.Card(
                cornerRadius: cornerRadius, showStroke: showStroke, hoverElevates: hoverElevates))
    }
    func themedTitle() -> some View { modifier(Theme.Typography.Title()) }
    func themedSectionHeader() -> some View { modifier(Theme.Typography.SectionHeader()) }
    func themedChip(tint: Color) -> some View { modifier(Theme.Chip(tint: tint)) }
}

// MARK: - Utility chips for Post info
struct RatingChip: View {
    let rating: String
    var body: some View {
        let r = rating.lowercased()
        let color: Color =
            (r == "g")
            ? Theme.ColorPalette.success
            : (r == "s")
                ? Theme.ColorPalette.info
                : (r == "q") ? Theme.ColorPalette.warning : Theme.ColorPalette.danger
        HStack(spacing: 5) {
            Image(
                systemName: r == "g"
                    ? "checkmark.seal.fill"
                    : r == "s"
                        ? "hand.raised.fill" : r == "q" ? "exclamationmark.triangle.fill" : "nosign"
            )
            .imageScale(.small)
            Text(r.uppercased())
        }
        .themedChip(tint: color)
        .foregroundStyle(color)
    }
}

struct ScoreChip: View {
    let score: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill").imageScale(.small)
            Text("\(score)")
        }
        .themedChip(tint: .yellow)
        .foregroundStyle(.yellow)
    }
}

struct SizeChip: View {
    let width: Int
    let height: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "aspectratio").imageScale(.small)
            Text("\(width)x\(height)")
        }
        .themedChip(tint: .cyan)
        .foregroundStyle(.cyan)
    }
}
