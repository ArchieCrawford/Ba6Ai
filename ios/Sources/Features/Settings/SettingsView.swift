import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    @State private var showWipeConfirm = false
    @State private var wipeError: String?
    @State private var cloudBoostPreference: InferencePreference = .auto
    @State private var cloudKitOn: Bool = false
    @State private var notificationsOn: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        identityCard
                        modelCard
                        memoryCard
                        cloudCard
                        privacyCard
                        aboutCard
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Settings")
            .alert("Wipe all memory?", isPresented: $showWipeConfirm) {
                Button("Wipe everything", role: .destructive, action: wipeAll)
                Button("Cancel", role: .cancel) {}
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
                Button("OK", role: .cancel) {}
            } message: {
                Text(wipeError ?? "")
            }
        }
    }

    // MARK: - Cards

    private var identityCard: some View {
        SettingsSection(title: "Identity") {
            if let identity = app.identity {
                row("Device fingerprint") {
                    Text(identity.fingerprint)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                row("Hardware-backed") {
                    GlassChip(
                        label: identity.isHardwareBacked ? "Secure Enclave" : "Software fallback",
                        status: identity.isHardwareBacked ? .success : .warning
                    )
                }
            } else {
                Text("Loading…").foregroundStyle(.secondary)
            }
        }
    }

    private var modelCard: some View {
        SettingsSection(title: "On-device models") {
            ForEach(BA6Model.allCases) { model in
                row(model.displayName) {
                    Text("~\(model.approximateSizeMB) MB")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var memoryCard: some View {
        SettingsSection(title: "Memory") {
            NavigationLink {
                MemoryView()
            } label: {
                rowLabel("Browse memories", icon: "brain")
            }

            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                rowLabel("Wipe all memory", icon: "trash", tint: .red)
            }
        }
    }

    private var cloudCard: some View {
        SettingsSection(title: "Inference") {
            Picker("Routing", selection: $cloudBoostPreference) {
                ForEach(InferencePreference.allCases, id: \.self) { pref in
                    Text(label(for: pref)).tag(pref)
                }
            }
            .pickerStyle(.segmented)

            Text(cloudFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var privacyCard: some View {
        SettingsSection(title: "Privacy") {
            Toggle(isOn: $cloudKitOn) {
                Label("Sync to my iCloud", systemImage: "icloud")
            }
            .onChange(of: cloudKitOn) { _, newValue in
                try? PersistenceController.shared.setCloudSync(newValue)
            }

            Toggle(isOn: $notificationsOn) {
                Label("Notifications", systemImage: "bell")
            }
            .onChange(of: notificationsOn) { _, newValue in
                guard newValue else { return }
                Task { _ = await NotificationService.shared.requestAuthorization() }
            }
        }
    }

    private var aboutCard: some View {
        SettingsSection(title: "About") {
            row("Version") { Text("0.1.0").foregroundStyle(.secondary) }
            row("Build") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bits

    private func row<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }

    private func rowLabel(_ title: String, icon: String, tint: Color = .white) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func label(for pref: InferencePreference) -> String {
        switch pref {
        case .auto:       "Auto"
        case .localOnly:  "Local"
        case .cloudBoost: "Boost"
        }
    }

    private var cloudFootnote: String {
        switch cloudBoostPreference {
        case .auto:
            "BA6 keeps everything on-device by default and silently falls back to Cloud Boost only for prompts your local model can't handle."
        case .localOnly:
            "Every request runs on this device. Long prompts will be capped to fit the local model's context window."
        case .cloudBoost:
            "Every request goes through BA6's stateless backend. Each call is signed with your device key — no accounts, no logs."
        }
    }

    private func wipeAll() {
        app.memory?.wipeAllMemory()
    }
}

// MARK: - Section wrapper

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            GlassPanel(radius: Theme.Radius.card) {
                VStack(alignment: .leading, spacing: 12) { content() }
            }
        }
    }
}
