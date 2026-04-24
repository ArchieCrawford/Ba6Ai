import SwiftUI

struct ComposerView: View {
    @Binding var draft: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask BA6…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))

                Button(action: primaryAction) {
                    Image(systemName: primaryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .disabled(primaryDisabled)
            }
        }
    }

    private var primaryIcon: String {
        isGenerating ? "stop.fill" : "arrow.up"
    }

    private var primaryDisabled: Bool {
        !isGenerating && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func primaryAction() {
        if isGenerating { onStop() } else { onSend() }
    }
}
