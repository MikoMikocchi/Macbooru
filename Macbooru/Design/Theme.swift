import SwiftUI

enum Theme {
    enum Constants {
        static let cornerRadius: CGFloat = 16
        static let compactCornerRadius: CGFloat = 12
        static let chipCornerRadius: CGFloat = 18
        static let controlSize: CGFloat = 36
        static let cardPadding: CGFloat = 22
    }

    // MARK: - Palette
    struct ColorPalette {
        static var primaryBackground: Color { Color("PrimaryBackground") }
        static var secondaryBackground: Color { Color("SecondaryBackground") }
        static var cardBackground: Color { Color("CardBackground") }

        static var accent: Color { .accentColor }
        static var accentSoft: Color { .accentColor.opacity(0.7) }
        static var success: Color { Color.green }
        static var warning: Color { Color.orange }
        static var info: Color { Color.blue }
        static var danger: Color { Color.red }
        static var muted: Color { Color.secondary }

        static var textPrimary: Color { Color.primary }
        static var textSecondary: Color { Color.secondary }
        static var textMuted: Color { Color.secondary.opacity(0.65) }

        static var glassBase: Color { Color.white.opacity(0.08) }
        static var glassHighlight: Color { Color.white.opacity(0.22) }
        static var glassBorder: Color { Color.white.opacity(0.16) }

        static var controlBackground: Color { Color.white.opacity(0.06) }
        static var controlHover: Color { Color.white.opacity(0.12) }
        static var controlActive: Color { Color.white.opacity(0.18) }

        static var shadowSoft: Color { Color.black.opacity(0.12) }
        static var shadowStrong: Color { Color.black.opacity(0.28) }

        static var successGradient: [Color] { [Color.green.opacity(0.85), Color.mint] }
        static var warningGradient: [Color] { [Color.orange.opacity(0.85), Color.yellow] }
        static var dangerGradient: [Color] { [Color.red.opacity(0.85), Color.pink] }
        static var infoGradient: [Color] { [Color.blue.opacity(0.85), Color.cyan] }
    }

    // MARK: - Gradients
    struct Gradients {
        static var appBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.primaryBackground,
                    ColorPalette.secondaryBackground.opacity(0.9),
                    ColorPalette.primaryBackground.opacity(0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var glassmorphismBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.glassBase,
                    ColorPalette.cardBackground.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var subtleBackground: LinearGradient {
            LinearGradient(
                colors: [
                    ColorPalette.glassBase.opacity(0.6),
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
                    .black.opacity(opacity * 0.35),
                    .black.opacity(opacity),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.3),
                endPoint: .bottom
            )
        }
    }

    // MARK: - Animations
    struct Animations {
        static let interactive = Animation.spring(response: 0.32, dampingFraction: 0.74, blendDuration: 0.18)
        static let hover = Animation.easeInOut(duration: 0.18)
        static func stagger(index: Int, baseDelay: Double = 0.045) -> Animation {
            interactive.delay(Double(index) * baseDelay)
        }
    }

    // MARK: - Typography
    struct Typography {
        struct Title: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorPalette.textPrimary)
            }
        }

        struct SectionHeader: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ColorPalette.textSecondary)
            }
        }

        struct Caption: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.footnote)
                    .foregroundStyle(ColorPalette.textMuted)
            }
        }
    }

    // MARK: - Surfaces & Effects
    struct Card: ViewModifier {
        var cornerRadius: CGFloat = Constants.cornerRadius
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
                .padding(.all, 0)
                .background(backgroundForStyle)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    Group {
                        if showStroke {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(strokeColor, lineWidth: strokeWidth)
                                .blendMode(style == .glassmorphism ? .overlay : .normal)
                        }
                    }
                )
                .shadow(
                    color: Theme.ColorPalette.shadowSoft.opacity(isHover && hoverElevates ? 1 : 0.8),
                    radius: isHover && hoverElevates ? 22 : 14,
                    x: 0,
                    y: isHover && hoverElevates ? 10 : 6
                )
                .scaleEffect(isHover && hoverElevates ? 1.015 : 1.0)
                .animation(Animations.interactive, value: isHover)
                .onHover { hovering in
                    withAnimation(Animations.hover) {
                        isHover = hovering
                    }
                }
        }

        @ViewBuilder
        private var backgroundForStyle: some View {
            switch style {
            case .glassmorphism:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ColorPalette.glassBase)
                    .background(.ultraThinMaterial)
            case .elevated:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ColorPalette.cardBackground.opacity(0.9))
                    .background(.thinMaterial)
            case .subtle:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ColorPalette.cardBackground.opacity(0.7))
                    .background(.regularMaterial)
            }
        }

        private var strokeColor: Color {
            switch style {
            case .glassmorphism: return ColorPalette.glassBorder
            case .elevated: return Color.white.opacity(0.1)
            case .subtle: return Color.black.opacity(0.08)
            }
        }

        private var strokeWidth: CGFloat {
            style == .glassmorphism ? 1.5 : 1
        }
    }

    struct HoverLift: ViewModifier {
        var scale: CGFloat = 1.03
        var shadow: CGFloat = 18
        var hoverBinding: Binding<Bool>? = nil
        @State private var hovering = false

        func body(content: Content) -> some View {
            content
                .scaleEffect(hovering ? scale : 1.0)
                .shadow(
                    color: Theme.ColorPalette.shadowSoft.opacity(hovering ? 1 : 0.6),
                    radius: hovering ? shadow : 10,
                    x: 0,
                    y: hovering ? 10 : 4
                )
                .animation(Animations.interactive, value: hovering)
                .onHover { value in
                    withAnimation(Animations.hover) {
                        hovering = value
                        hoverBinding?.wrappedValue = value
                    }
                }
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
                case .small: return (8, 4)
                case .medium: return (10, 6)
                case .large: return (12, 8)
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
                .clipShape(Capsule(style: .continuous))
        }

        @ViewBuilder
        private var backgroundForStyle: some View {
            switch style {
            case .standard:
                tint.opacity(0.16)
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
                Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)
            case .filled, .gradient:
                EmptyView()
            }
        }
    }

    struct IconButton: View {
        let systemName: String
        var size: CGFloat = Constants.controlSize
        var isDisabled: Bool = false
        var showsProgress: Bool = false
        var tint: Color = ColorPalette.textPrimary
        var background: Color = ColorPalette.controlBackground
        var hoverBackground: Color = ColorPalette.controlHover
        var action: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                ZStack {
                    if showsProgress {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tint)
                    } else {
                        Image(systemName: systemName)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(width: size, height: size)
                .foregroundStyle(tint)
                .background(
                    RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                        .fill(hovering && !isDisabled ? hoverBackground : background)
                        .background(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                        .strokeBorder(ColorPalette.glassBorder.opacity(hovering && !isDisabled ? 0.8 : 0.5), lineWidth: 1)
                )
                .scaleEffect(hovering && !isDisabled ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || showsProgress)
            .opacity(isDisabled && !showsProgress ? 0.55 : 1.0)
            .animation(Animations.interactive, value: hovering)
            .onHover { value in
                withAnimation(Animations.hover) {
                    hovering = value
                }
            }
        }
    }

    struct PageButton: View {
        let number: Int
        var isCurrent: Bool
        var isDisabled: Bool
        var action: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                Text("\(number)")
                    .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                    .frame(width: Constants.controlSize, height: Constants.controlSize)
                    .foregroundStyle(isCurrent ? Theme.ColorPalette.textPrimary : Theme.ColorPalette.textSecondary)
                    .background(
                        Group {
                            if isCurrent {
                                RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                                    .fill(ColorPalette.glassBase)
                                    .background(.ultraThinMaterial)
                            } else if hovering && !isDisabled {
                                RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                                    .fill(ColorPalette.controlHover)
                                    .background(.ultraThinMaterial)
                            } else {
                                RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                                    .fill(Color.clear)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.compactCornerRadius, style: .continuous)
                            .strokeBorder(
                                isCurrent
                                    ? ColorPalette.glassHighlight
                                    : ColorPalette.glassBorder.opacity(hovering ? 0.6 : 0.3),
                                lineWidth: isCurrent ? 1.6 : 1
                            )
                    )
                    .scaleEffect(hovering && !isDisabled ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.45 : 1.0)
            .animation(Animations.interactive, value: hovering)
            .onHover { value in
                withAnimation(Animations.hover) {
                    hovering = value
                }
            }
        }
    }

    struct InputFieldStyle: ViewModifier {
        var systemImage: String?
        var iconTint: Color = ColorPalette.accent
        var trailingSystemImage: String? = nil
        var onTrailingTap: (() -> Void)? = nil

        func body(content: Content) -> some View {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconTint)
                        .frame(width: 16)
                }
                content
                    .textFieldStyle(.plain)
                    .foregroundStyle(ColorPalette.textPrimary)
                if let trailingSystemImage, let onTrailingTap {
                    Button(action: onTrailingTap) {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorPalette.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                    .fill(ColorPalette.controlBackground)
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                    .strokeBorder(ColorPalette.glassBorder, lineWidth: 1)
            )
        }
    }

    struct GlassButtonStyle: ButtonStyle {
        enum Kind {
            case primary
            case secondary
            case destructive
        }

        var kind: Kind = .primary

        func makeBody(configuration: Configuration) -> some View {
            let isPressed = configuration.isPressed
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

            let background: AnyView = {
                switch kind {
                case .primary:
                    let gradient = LinearGradient(
                        colors: [ColorPalette.accent, ColorPalette.accentSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    return AnyView(shape.fill(gradient))
                case .secondary:
                    return AnyView(
                        ZStack {
                            shape.fill(ColorPalette.controlBackground)
                            shape.fill(.ultraThinMaterial)
                        }
                    )
                case .destructive:
                    let gradient = LinearGradient(
                        colors: [ColorPalette.danger, ColorPalette.danger.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    return AnyView(shape.fill(gradient))
                }
            }()

            let strokeColor: Color = {
                switch kind {
                case .primary, .destructive:
                    return Color.white.opacity(0.28)
                case .secondary:
                    return ColorPalette.glassBorder
                }
            }()

            let foreground: Color = {
                switch kind {
                case .primary, .destructive:
                    return Color.white
                case .secondary:
                    return ColorPalette.textPrimary
                }
            }()

            return configuration.label
                .font(.callout.weight(.semibold))
                .foregroundStyle(foreground.opacity(isPressed ? 0.8 : 1.0))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(background)
                .overlay(
                    shape.strokeBorder(
                        strokeColor.opacity(isPressed ? 0.6 : 1.0),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: ColorPalette.shadowSoft.opacity(kind == .secondary ? 0.4 : 0.6),
                    radius: 8,
                    x: 0,
                    y: 3
                )
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(Animations.interactive, value: isPressed)
        }
    }
}

// MARK: - View extensions
extension View {
    func themedCard(
        cornerRadius: CGFloat = Theme.Constants.cornerRadius,
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

    func glassCard(
        cornerRadius: CGFloat = Theme.Constants.cornerRadius,
        hoverElevates: Bool = true
    ) -> some View {
        themedCard(
            cornerRadius: cornerRadius,
            showStroke: true,
            hoverElevates: hoverElevates,
            style: .glassmorphism
        )
    }

    func themedTitle() -> some View {
        modifier(Theme.Typography.Title())
    }

    func themedSectionHeader() -> some View {
        modifier(Theme.Typography.SectionHeader())
    }

    func themedCaption() -> some View {
        modifier(Theme.Typography.Caption())
    }

    func themedChip(
        tint: Color,
        style: Theme.Chip.ChipStyle = .standard,
        size: Theme.Chip.ChipSize = .medium
    ) -> some View {
        modifier(Theme.Chip(tint: tint, style: style, size: size))
    }

    func hoverLift(
        scale: CGFloat = 1.03,
        shadow: CGFloat = 18,
        isHovering: Binding<Bool>? = nil
    ) -> some View {
        modifier(Theme.HoverLift(scale: scale, shadow: shadow, hoverBinding: isHovering))
    }

    func themedInputField(
        systemImage: String? = nil,
        iconTint: Color = Theme.ColorPalette.accent,
        trailingSystemImage: String? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) -> some View {
        modifier(
            Theme.InputFieldStyle(
                systemImage: systemImage,
                iconTint: iconTint,
                trailingSystemImage: trailingSystemImage,
                onTrailingTap: onTrailingTap
            )
        )
    }
}

// MARK: - Shared components
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

        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(r.uppercased())
        }
        .themedChip(tint: colors[0], style: .gradient)
        .foregroundStyle(Color.white)
    }
}

struct ScoreChip: View {
    let score: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill").imageScale(.small)
            Text("\(score)")
        }
        .themedChip(tint: .yellow, style: .filled)
        .foregroundStyle(.black)
    }
}

struct SizeBadge: View {
    let width: Int
    let height: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "aspectratio").imageScale(.small)
            Text("\(width)x\(height)")
        }
        .themedChip(tint: .cyan, style: .standard)
        .foregroundStyle(.cyan)
    }
}
