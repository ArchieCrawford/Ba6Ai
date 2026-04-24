import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var showWipeConfirm = false
    @State private var wipeError: String?
    @State private var cloudBoostEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                modelSection
                memorySection
                cloudSection
                aboutSection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .alert("Wipe all memory?", isPresented: $showWipeConfirm) {
                Button("Wipe everything", role: .destructive, action: wipeAll)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All memories, embeddings, and conversations will be erased from this device. This can't be undone.")
            }
            .alert(
                "Couldn't wipe memory",
                isPresented: .init(
                    get: { wipeError != nil },
                    set: { if !$0 { wipeError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(wipeError ?? "")
            }
        }
    }

    private var identitySection: some View {
        Section("Identity") {
            if let identity = app.identity {
                LabeledContent("Device fingerprint") {
                    Text(identity.fingerprint)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("Hardware-backed") {
                    Text(identity.isHardwareBacked ? "Secure Enclave" : "Software fallback")
                        .foregroundStyle(identity.isHardwareBacked ? .green : .yellow)
                }
                DisclosureGroup("Public key") {
                    Text(identity.publicKeyBase64)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            } else {
                Text("Loading…").foregroundStyle(.secondary)
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            ForEach(BA6Model.allCases) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                        Text("~\(model.approximateSizeMB) MB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Selection lives in ChatViewModel; surface here later
                    // when we persist user prefs.
                }
            }
        }
    }

    private var memorySection: some View {
        Section("Memory") {
            NavigationLink("Pinned memories") { PinnedMemoriesView() }
            Button("Forget this session", role: .destructive) {
                // Hook up from active chat context in a later pass.
            }
            Button("Wipe all memory", role: .destructive) {
                showWipeConfirm = true
            }
        }
    }

    private var cloudSection: some View {
        Section {
            Toggle("Cloud Boost", isOn: $cloudBoostEnabled)
        } header: {
            Text("Cloud")
        } footer: {
            Text("When Boost is on, large prompts can be routed to a stateless backend. Requests are signed with your device key and not logged.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1.0")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
        }
    }

    private func wipeAll() {
        do {
            try app.memory?.wipeAllMemory()
        } catch {
            wipeError = error.localizedDescription
        }
    }
}

struct PinnedMemoriesView: View {
    @Environment(AppModel.self) private var app
    @State private var memories: [Memory] = []

    var body: some View {
        List(memories) { mem in
            VStack(alignment: .leading) {
                Text(mem.content)
                Text(mem.createdAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if memories.isEmpty {
                ContentUnavailableView(
                    "No pinned memories yet",
                    systemImage: "pin.slash",
                    description: Text("Say “remember that …” in chat to pin a fact.")
                )
            }
        }
        .navigationTitle("Pinned memories")
    }
}
