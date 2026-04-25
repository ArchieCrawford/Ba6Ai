import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if let error = app.bootError {
                BootErrorView(message: error)
            } else if app.isReady {
                MainShell()
            } else {
                BootingView()
            }
        }
        .animation(Theme.Motion.standard, value: app.isReady)
    }
}

// MARK: - Main shell with floating Liquid Glass tab bar

private struct MainShell: View {
    enum Tab: Hashable, Identifiable {
        case chat, memory, video, settings
        var id: Tab { self }
    }

    @State private var selection: Tab = .chat

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backdrop

            content
                .padding(.bottom, 88)             // make room for the floating tab bar

            GlassTabBar(
                selection: $selection,
                items: [
                    .init(id: .chat,     title: "Chat",     icon: "bubble.left.and.bubble.right"),
                    .init(id: .memory,   title: "Memory",   icon: "brain"),
                    .init(id: .video,    title: "Video",    icon: "film"),
                    .init(id: .settings, title: "Settings", icon: "gearshape")
                ]
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch selection {
            case .chat:     ChatView()
            case .memory:   NavigationStack { MemoryView() }
            case .video:    VideoView()
            case .settings: SettingsView()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .id(selection)
        .animation(Theme.Motion.standard, value: selection)
    }
}

// MARK: - Boot states

private struct BootingView: View {
    var body: some View {
        ZStack {
            Theme.backdrop
            GlassPanel(radius: Theme.Radius.panel) {
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text("Waking up BA6 AI")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: 320)
        }
    }
}

private struct BootErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.backdrop
            GlassPanel(radius: Theme.Radius.panel) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Label("Startup failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text(message)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: 420)
            .padding()
        }
    }
}
