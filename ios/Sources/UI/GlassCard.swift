import SwiftUI

/// Interactive Liquid Glass card. Supports tap, optional press
/// animation, and an expandable detail region.
///
/// Used by Memory cards, conversation rows, and any list item that
/// needs to feel tactile rather than flat.
struct GlassCard<Content: View, Detail: View>: View {
    var radius: CGFloat = Theme.Radius.card
    var isExpanded: Bool = false
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var detail: () -> Detail

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                content()
                if isExpanded {
                    detail()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .glassEffect(.regular, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
            .scaleEffect(isPressed ? 0.985 : 1)
            .animation(Theme.Motion.snappy, value: isPressed)
            .animation(Theme.Motion.standard, value: isExpanded)
        }
        .buttonStyle(.plain)
        .pressEvents { isPressed = true } onRelease: { isPressed = false }
    }
}

extension GlassCard where Detail == EmptyView {
    init(
        radius: CGFloat = Theme.Radius.card,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.radius = radius
        self.isExpanded = false
        self.onTap = onTap
        self.content = content
        self.detail = { EmptyView() }
    }
}

/// Captures press / release events without losing tap behaviour.
private struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}
