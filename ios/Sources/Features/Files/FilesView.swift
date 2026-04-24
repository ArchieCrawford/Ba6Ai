import SwiftUI

/// Phase 4 placeholder. PDF + text + transcript ingestion into the memory
/// store. Kept as a clearly-marked stub so the tab exists and the
/// navigation model is correct from day one.
struct FilesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 14) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48, weight: .light))
                    Text("Drop in PDFs, notes, transcripts")
                        .font(.headline)
                    Text("BA6 will index them locally and cite them when you ask.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Coming in Phase 4")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                }
                .padding(32)
                .frame(maxWidth: 420)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .padding()
            }
            .navigationTitle("Files")
        }
    }
}
