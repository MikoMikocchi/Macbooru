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

        // Modern color palette
        static var glassmorphism: Color { .white.opacity(0.08) }
        static var glassBorder: Color { .white.opacity(0.15) }
        static var surfaceElevated: Color { .white.opacity(0.05) }
        static var surfaceSubtle: Color { .black.opacity(0.03) }

        // Enhanced semantic colors
        static var successGradient: [Color] { [Color.green.opacity(0.8), Color.mint] }
        static var warningGradient: [Color] { [Color.orange.opacity(0.8), Color.yellow] }
        static var dangerGradient: [Color] { [Color.red.opacity(0.8), Color.pink] }
        static var infoGradient: [Color] { [Color.blue.opacity(0.8), Color.cyan] }
    }

    // MARK: - Gradients
    struct Gradients {
        static var appBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.primaryBackground,
                    ColorPalette.secondaryBackground.opacity(0.85),
                    ColorPalette.primaryBackground.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var glassmorphismBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.glassmorphism,
                    ColorPalette.surfaceElevated,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var subtleBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.surfaceSubtle,
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static func tileOverlay(strength: Double = 0.55) -> LinearGradient {
            LinearGradient(
                colors: [
                    .black.opacity(0.0),
                    .black.opacity(strength * 0.7),
                    .black.opacity(strength),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static func modernOverlay(opacity: Double = 0.6) -> LinearGradient {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(opacity * 0.3),
                    .black.opacity(opacity),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.3),
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
        var cornerRadius: CGFloat = 16
        var showStroke: Bool = true
        var hoverElevates: Bool = true
        var style: CardStyle = .glassmorphism
        @State private var isHover = false

        enum CardStyle {
            case glassmorphism
            case elevated
            case subtle
        }

        func body(content: Content) -> some View {
            content
                .background(backgroundForStyle)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    Group {
                        if showStroke {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        }
                    }
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0, y: shadowY
                )
                .scaleEffect(isHover && hoverElevates ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHover)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHover = hovering
                    }
                }
        }

        private var backgroundForStyle: some View {
            Group {
                switch style {
                case .glassmorphism:
                    ColorPalette.glassmorphism
                        .background(.ultraThinMaterial)
                case .elevated:
                    ColorPalette.cardBackground.opacity(0.8)
                        .background(.thinMaterial)
                case .subtle:
                    ColorPalette.surfaceSubtle
                        .background(.regularMaterial)
                }
            }
        }

        private var strokeColor: Color {
            switch style {
            case .glassmorphism: return ColorPalette.glassBorder
            case .elevated: return .white.opacity(0.1)
            case .subtle: return .black.opacity(0.08)
            }
        }

        private var strokeWidth: CGFloat {
            style == .glassmorphism ? 1.5 : 1.0
        }

        private var shadowColor: Color {
            .black.opacity(isHover && hoverElevates ? 0.25 : 0.12)
        }

        private var shadowRadius: CGFloat {
            isHover && hoverElevates ? 20 : 12
        }

        private var shadowY: CGFloat {
            isHover && hoverElevates ? 8 : 4
        }
    }

    struct Chip: ViewModifier {
        var tint: Color = ColorPalette.muted
        var style: ChipStyle = .standard
        var size: ChipSize = .medium

        enum ChipStyle {
            case standard
            case filled
            case gradient
        }

        enum ChipSize {
            case small
            case medium
            case large

            var padding: (horizontal: CGFloat, vertical: CGFloat) {
                switch self {
                case .small: return (6, 3)
                case .medium: return (8, 4)
                case .large: return (12, 6)
                }
            }

            var fontSize: Font {
                switch self {
                case .small: return .caption2.weight(.semibold)
                case .medium: return .caption.weight(.semibold)
                case .large: return .footnote.weight(.semibold)
                }
            }
        }

        func body(content: Content) -> some View {
            content
                .font(size.fontSize)
                .padding(.horizontal, size.padding.horizontal)
                .padding(.vertical, size.padding.vertical)
                .background(backgroundForStyle)
                .overlay(overlayForStyle)
                .clipShape(Capsule())
        }

        @ViewBuilder
        private var backgroundForStyle: some View {
            switch style {
            case .standard:
                tint.opacity(0.18)
            case .filled:
                tint
            case .gradient:
                LinearGradient(
                    colors: [tint, tint.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        @ViewBuilder
        private var overlayForStyle: some View {
            switch style {
            case .standard:
                Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1)
            case .filled, .gradient:
                EmptyView()
            }
        }
    }
}

extension View {
    func themedCard(
        cornerRadius: CGFloat = 16,
        showStroke: Bool = true,
        hoverElevates: Bool = true,
        style: Theme.Card.CardStyle = .glassmorphism
    ) -> some View {
        modifier(
            Theme.Card(
                cornerRadius: cornerRadius,
                showStroke: showStroke,
                hoverElevates: hoverElevates,
                style: style
            )
        )
    }

    func themedTitle() -> some View {
        modifier(Theme.Typography.Title())
    }

    func themedSectionHeader() -> some View {
        modifier(Theme.Typography.SectionHeader())
    }

    func themedChip(
        tint: Color,
        style: Theme.Chip.ChipStyle = .standard,
        size: Theme.Chip.ChipSize = .medium
    ) -> some View {
        modifier(Theme.Chip(tint: tint, style: style, size: size))
    }
}

// MARK: - Utility chips for Post info
struct RatingChip: View {
    let rating: String
    var body: some View {
        let r = rating.lowercased()
        let (colors, icon): ([Color], String) = {
            switch r {
            case "g": return (Theme.ColorPalette.successGradient, "checkmark.seal.fill")
            case "s": return (Theme.ColorPalette.infoGradient, "hand.raised.fill")
            case "q": return (Theme.ColorPalette.warningGradient, "exclamationmark.triangle.fill")
            default: return (Theme.ColorPalette.dangerGradient, "nosign")
            }
        }()

        HStack(spacing: 5) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(r.uppercased())
        }
        .themedChip(tint: colors[0], style: .gradient)
        .foregroundStyle(.white)
    }
}

struct ScoreChip: View {
    let score: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill").imageScale(.small)
            Text("\(score)")
        }
        .themedChip(tint: .yellow, style: .filled)
        .foregroundStyle(.black)
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
        .themedChip(tint: .cyan, style: .gradient)
        .foregroundStyle(.white)
    }
}
