import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let error = app.bootError {
            BootErrorView(message: error)
        } else if app.isReady {
            MainTabs()
        } else {
            BootingView()
        }
    }
}

private struct MainTabs: View {
    @State private var selection: Tab = .chat

    enum Tab: Hashable { case chat, files, settings }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: Tab.chat) {
                ChatView()
            }
            Tab("Files", systemImage: "doc.text.magnifyingglass", value: Tab.files) {
                FilesView()
            }
            Tab("Settings", systemImage: "gearshape", value: Tab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

private struct BootingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().controlSize(.large).tint(.white)
                Text("Waking up BA6 AI")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }
}

private struct BootErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Label("Startup failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(message)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(20)
            .frame(maxWidth: 420)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding()
        }
    }
}
