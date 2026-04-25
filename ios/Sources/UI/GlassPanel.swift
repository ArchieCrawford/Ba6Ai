import SwiftUI

/// Foundational Liquid Glass surface.
///
/// Wraps `glassEffect(.regular, in:)` with consistent corner radii, a
/// soft dual-layer shadow for depth, and an optional `.glow` state for
/// active / focused emphasis. Every panel-shaped surface in BA6 routes
/// through this view rather than calling `.glassEffect` directly so the
/// look stays cohesive when we evolve the system.
struct GlassPanel<Content: View>: View {
    enum Tint {
        case neutral
        case glow(Color)
    }

    var radius: CGFloat = Theme.Radius.panel
    var tint: Tint = .neutral
    var padding: CGFloat? = Theme.Spacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .modifier(_Padding(padding: padding))
            .glassEffect(.regular, in: .rect(cornerRadius: radius))
            .overlay(highlight)
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 16)
            .shadow(color: .black.opacity(0.25), radius: 4,  x: 0, y: 2)
            .modifier(_Glow(tint: tint, radius: radius))
    }

    private var highlight: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.6
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private struct _Padding: ViewModifier {
        let padding: CGFloat?
        func body(content: Content) -> some View {
            if let padding { content.padding(padding) } else { content }
        }
    }

    private struct _Glow: ViewModifier {
        let tint: Tint
        let radius: CGFloat
        func body(content: Content) -> some View {
            switch tint {
            case .neutral:
                content
            case .glow(let color):
                content
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(color.opacity(0.22))
                            .blur(radius: 22)
                            .scaleEffect(1.04)
                            .allowsHitTesting(false)
                    )
            }
        }
    }
}
