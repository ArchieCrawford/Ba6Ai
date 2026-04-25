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
                  let memory = app.memory,
                  let context = app.memoryContext else { return }
            let new = ChatViewModel(engine: engine, memory: memory, memoryContext: context)
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
                Theme.backdrop

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(vm.bubbles) { bubble in
                                MessageBubble(bubble: bubble).id(bubble.id)
                            }
                            Color.clear.frame(height: 140).id("bottom")
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.bubbles.last?.content) { _, _ in
                        withAnimation(Theme.Motion.stream) {
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
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }
            .navigationTitle("BA6 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassChip(
                        label: vm.providerLabel,
                        icon: "cpu",
                        status: vm.providerStatus
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(InferencePreference.allCases, id: \.self) { pref in
                            Button {
                                vm.preference = pref
                            } label: {
                                Label(label(for: pref),
                                      systemImage: vm.preference == pref ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func label(for pref: InferencePreference) -> String {
        switch pref {
        case .auto:       "Auto (smart)"
        case .localOnly:  "On-device only"
        case .cloudBoost: "Cloud Boost"
        }
    }
}
