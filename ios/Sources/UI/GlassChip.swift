import SwiftUI

/// Small status / tag pill rendered in glass. Used for model badges,
/// memory pin status, network indicators, etc.
struct GlassChip: View {
    enum Status { case neutral, active, success, warning, error }

    let label: String
    var icon: String? = nil
    var status: Status = .neutral

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .modifier(StatusGlow(color: statusColor, on: status != .neutral))
            if let icon {
                Image(systemName: icon).font(.caption2.weight(.semibold))
            }
            Text(label).font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch status {
        case .neutral: .gray
        case .active:  .accentColor
        case .success: .green
        case .warning: .yellow
        case .error:   .red
        }
    }

    private struct StatusGlow: ViewModifier {
        let color: Color
        let on: Bool
        @State private var pulse = false
        func body(content: Content) -> some View {
            content
                .background(
                    Circle()
                        .fill(color.opacity(on ? 0.6 : 0))
                        .blur(radius: 4)
                        .scaleEffect(pulse ? 1.6 : 1)
                        .opacity(pulse ? 0 : 0.8)
                )
                .onAppear {
                    guard on else { return }
                    withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }
        }
    }
}
