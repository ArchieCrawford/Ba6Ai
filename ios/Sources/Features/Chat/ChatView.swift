import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @State private var vm: ChatViewModel?

    var body: some View {
        Group {
            if let vm {
                ChatSurface(vm: vm)
            } else {
                Color.clear
            }
        }
        .task {
            guard vm == nil,
                  let engine = app.engine,
                  let memory = app.memory else { return }
            let new = ChatViewModel(engine: engine, memory: memory)
            vm = new
            await new.onAppear()
        }
    }
}

private struct ChatSurface: View {
    @Bindable var vm: ChatViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                backdrop

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.bubbles) { bubble in
                                MessageBubble(bubble: bubble)
                                    .id(bubble.id)
                            }
                            Color.clear.frame(height: 120).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.bubbles.last?.content) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                ComposerView(
                    draft: $vm.draft,
                    isGenerating: vm.isGenerating,
                    onSend: { vm.send() },
                    onStop: { vm.stop() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .navigationTitle("BA6 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ModelBadge(state: vm.modelState, selected: vm.selectedModel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(BA6Model.allCases) { m in
                            Button {
                                Task { await vm.loadModel(m) }
                            } label: {
                                Label(m.displayName, systemImage: m == vm.selectedModel ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "cpu")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [.black, Color(white: 0.05), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Model badge

private struct ModelBadge: View {
    let state: LLMEngine.State
    let selected: BA6Model

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    private var label: String {
        switch state {
        case .idle: "Idle"
        case .loading(_, let p): "Loading \(Int(p * 100))%"
        case .ready: selected.displayName
        case .failed: "Failed"
        }
    }

    private var color: Color {
        switch state {
        case .idle: .gray
        case .loading: .yellow
        case .ready: .green
        case .failed: .red
        }
    }
}
