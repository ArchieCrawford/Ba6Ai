import SwiftUI

struct MessageBubble: View {
    let bubble: ChatViewModel.Bubble

    var body: some View {
        HStack {
            if bubble.role == .user { Spacer(minLength: 48) }
            content
            if bubble.role == .assistant { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if bubble.role == .user {
            Text(bubble.content)
                .font(.body)
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: .rect(cornerRadius: 20))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(bubble.content.isEmpty ? " " : bubble.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                if bubble.isStreaming {
                    StreamingDots()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}

private struct StreamingDots: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .scaleEffect(1 + 0.3 * sin(phase + Double(i) * .pi / 2))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
