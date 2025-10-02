import SwiftUI

/// Управление глобальными анимациями и переходами
enum AppAnimations {

    // MARK: - Spring Animations
    static let gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let bouncySpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.9)

    // MARK: - Easing Animations
    static let quickEase = Animation.easeInOut(duration: 0.2)
    static let smoothEase = Animation.easeInOut(duration: 0.3)
    static let slowEase = Animation.easeInOut(duration: 0.5)

    // MARK: - Custom Timing Curves
    static let customEase = Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.4)
    static let materialEase = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.3)

    // MARK: - Transition Animations
    static let slideTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    static let scaleTransition = AnyTransition.scale(scale: 0.8)
        .combined(with: .opacity)
        .animation(gentleSpring)

    static let popTransition = AnyTransition.scale(scale: 0.6)
        .combined(with: .opacity)
        .animation(bouncySpring)

    // MARK: - List Item Animations
    static func listItemInsertAnimation(index: Int) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
            .delay(Double(index) * 0.05)
    }

    static func staggeredReveal(index: Int, delay: Double = 0.05) -> Animation {
        .easeOut(duration: 0.3)
            .delay(Double(index) * delay)
    }
}

// MARK: - View Extensions for Animations
extension View {
    /// Добавляет анимированное появление с задержкой
    func animatedAppearance(delay: Double = 0) -> some View {
        self.modifier(AnimatedAppearanceModifier(delay: delay))
    }

    /// Добавляет анимацию hover с масштабированием
    func hoverScale(scale: CGFloat = 1.02) -> some View {
        self.modifier(HoverScaleModifier(scale: scale))
    }

    /// Добавляет плавный переход opacity при смене состояния
    func smoothOpacity(_ opacity: Double) -> some View {
        self
            .opacity(opacity)
            .animation(AppAnimations.quickEase, value: opacity)
    }

    /// Добавляет анимированные тени
    func animatedShadow(
        isActive: Bool,
        color: Color = .black,
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 5
    ) -> some View {
        self
            .shadow(
                color: color.opacity(isActive ? 0.2 : 0.1),
                radius: isActive ? radius : radius * 0.5,
                x: x,
                y: isActive ? y : y * 0.5
            )
            .animation(AppAnimations.gentleSpring, value: isActive)
    }
}

// MARK: - Animated Appearance Modifier
private struct AnimatedAppearanceModifier: ViewModifier {
    let delay: Double
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .onAppear {
                withAnimation(AppAnimations.smoothEase.delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

// MARK: - Hover Scale Modifier
private struct HoverScaleModifier: ViewModifier {
    let scale: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(AppAnimations.bouncySpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Staggered Animation Helper
struct StaggeredVStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
    }
}

// MARK: - Loading Animation
struct LoadingSpinner: View {
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isSpinning
            )
            .onAppear {
                isSpinning = true
            }
    }
}

// MARK: - Pulse Animation
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let scale: CGFloat
    let opacity: Double

    init(scale: CGFloat = 1.1, opacity: Double = 0.7) {
        self.scale = scale
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .opacity(isPulsing ? opacity : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseEffect(scale: CGFloat = 1.1, opacity: Double = 0.7) -> some View {
        self.modifier(PulseEffect(scale: scale, opacity: opacity))
    }
}
