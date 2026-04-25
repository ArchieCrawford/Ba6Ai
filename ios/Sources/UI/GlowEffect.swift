import SwiftUI

/// Reusable focus / active glow. Fades in on `active`, fades out
/// otherwise. The duration is short on purpose — the glow should feel
/// like emphasis, not like an animation.
struct GlowModifier: ViewModifier {
    let active: Bool
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? color : .clear, radius: radius, x: 0, y: 0)
            .animation(Theme.Motion.standard, value: active)
    }
}

extension View {
    /// Apply a soft glow when `active` is true.
    func glow(_ active: Bool, color: Color = Theme.Glow.active, radius: CGFloat = 20) -> some View {
        modifier(GlowModifier(active: active, color: color, radius: radius))
    }

    /// Tint a view with a subtle highlight that mimics light catching
    /// the top of a glass surface. Use sparingly — once per panel.
    func liquidHighlight(radius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.20), .white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        )
    }
}
