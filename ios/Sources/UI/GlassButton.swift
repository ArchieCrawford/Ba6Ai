import SwiftUI

/// Consistent button surfaces over `.glass` and `.glassProminent`.
///
/// Use `GlassButton` for the standard frosted action; `GlassButton(.prominent)`
/// for the primary call-to-action in a view (only one per surface).
struct GlassButton<Label: View>: View {
    enum Kind { case regular, prominent, destructive }

    let kind: Kind
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    init(
        _ kind: Kind = .regular,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.kind = kind
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(stylized)
        .tint(tint)
    }

    private var tint: Color {
        switch kind {
        case .regular: .white
        case .prominent: .white
        case .destructive: .red
        }
    }

    @ViewBuilder
    private var stylized: some PrimitiveButtonStyle {
        switch kind {
        case .regular:     GlassButtonStyleAdapter(prominent: false)
        case .prominent:   GlassButtonStyleAdapter(prominent: true)
        case .destructive: GlassButtonStyleAdapter(prominent: false)
        }
    }
}

/// Adapter so we can return a single `some PrimitiveButtonStyle` from
/// the switch above. Internally calls into iOS 26's `.glass` /
/// `.glassProminent` styles.
private struct GlassButtonStyleAdapter: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if prominent {
                Button(role: configuration.role, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(.glassProminent)
            } else {
                Button(role: configuration.role, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(.glass)
            }
        }
    }
}
