import SwiftUI

/// Floating Liquid Glass tab bar.
///
/// Sits above content rather than docking to the safe area edge, with
/// inertial selection animation and a soft glow on the selected pill.
/// Used as the root navigation surface in `RootView`.
struct GlassTabBar<Tab: Hashable & Identifiable>: View {
    @Binding var selection: Tab
    let items: [Item]

    struct Item: Identifiable {
        let id: Tab
        let title: String
        let icon: String
    }

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                tab(for: item)
            }
        }
        .padding(6)
        .glassEffect(.regular, in: .capsule)
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 14)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tab(for item: Item) -> some View {
        let isSelected = selection == item.id
        Button {
            withAnimation(Theme.Motion.snappy) { selection = item.id }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                if isSelected {
                    Text(item.title)
                        .font(.footnote.weight(.semibold))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))
            .padding(.horizontal, isSelected ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(.white)
                            .matchedGeometryEffect(id: "selected.pill", in: pill)
                            .shadow(color: .white.opacity(0.4), radius: 14, x: 0, y: 0)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}
