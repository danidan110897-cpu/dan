import SwiftUI

enum Theme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
    static let accent = Color(red: 0.78, green: 1.0, blue: 0.25)
    static let move = Color(red: 1.0, green: 0.30, blue: 0.40)
    static let train = Color(red: 0.78, green: 1.0, blue: 0.25)
    static let recover = Color(red: 0.35, green: 0.80, blue: 1.0)
    static let secondaryText = Color.white.opacity(0.55)
}

/// Shared springs so the whole app moves with one personality.
enum Motion {
    static let snappy = Animation.snappy(duration: 0.35)
    static let bouncy = Animation.bouncy(duration: 0.5, extraBounce: 0.15)
    static let smooth = Animation.smooth(duration: 0.7)
    static func stagger(_ index: Int, step: Double = 0.07) -> Animation {
        .smooth(duration: 0.6).delay(Double(index) * step)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.cardStroke))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }

    /// Fade + rise on first appearance, staggered by index. Respects Reduce Motion.
    func entrance(_ index: Int, shown: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .animation(reduceMotion ? .none : Motion.stagger(index), value: shown)
    }
}

/// Button style with a physical press: scales down, springs back.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}
