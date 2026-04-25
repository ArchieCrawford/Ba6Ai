import SwiftUI

/// The Memory feature surface. Lists every fact BA6 has been told to
/// remember, lets the user pin/unpin, expand to see the source, and
/// forget any single memory or wipe everything.
struct MemoryView: View {
    @Environment(AppModel.self) private var app
    @State private var memories: [Memory] = []
    @State private var expandedID: UUID?
    @State private var query = ""
    @State private var showWipeConfirm = false

    var body: some View {
        ZStack {
            Theme.backdrop

            VStack(spacing: Theme.Spacing.md) {
                searchBar
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(filtered) { mem in
                                memoryCard(mem)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Wipe all", role: .destructive) { showWipeConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Wipe every memory?", isPresented: $showWipeConfirm) {
            Button("Wipe", role: .destructive) {
                app.memory?.wipeAllMemory()
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is permanent. Pinned memories will also be removed.")
        }
        .task { refresh() }
        .onChange(of: app.memory?.version ?? 0) { _, _ in refresh() }
    }

    // MARK: - Pieces

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search memories", text: $query)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "brain")
                .font(.system(size: 44, weight: .light))
            Text("Nothing remembered yet")
                .font(.headline)
            Text("Say “remember that …” in chat to pin a fact here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 340)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.panel))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func memoryCard(_ mem: Memory) -> some View {
        let expanded = expandedID == mem.id
        return GlassCard(
            radius: Theme.Radius.card,
            isExpanded: expanded,
            onTap: { toggle(mem.id) },
            content: {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    pinIcon(mem)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mem.content)
                            .font(.body)
                            .lineLimit(expanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white)
                        Text(mem.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .animation(Theme.Motion.snappy, value: expanded)
                }
            },
            detail: {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Divider().opacity(0.3)
                    HStack {
                        GlassChip(
                            label: mem.pinned ? "Pinned" : "Pin",
                            icon: mem.pinned ? "pin.fill" : "pin",
                            status: mem.pinned ? .active : .neutral
                        )
                        .onTapGesture { app.memory?.setPinned(mem.id, pinned: !mem.pinned); refresh() }
                        Spacer()
                        GlassChip(label: "Forget", icon: "trash", status: .error)
                            .onTapGesture { app.memory?.forget(mem.id); refresh() }
                    }
                    if let source = mem.sourceMessageID {
                        Text("From message \(source.uuidString.prefix(8))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }

    private func pinIcon(_ mem: Memory) -> some View {
        ZStack {
            Circle()
                .fill(mem.pinned ? Color.accentColor.opacity(0.25) : .white.opacity(0.06))
                .frame(width: 32, height: 32)
            Image(systemName: mem.pinned ? "pin.fill" : "lightbulb")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mem.pinned ? .accent : .white)
        }
    }

    // MARK: - State

    private var filtered: [Memory] {
        guard !query.isEmpty else { return memories }
        let q = query.lowercased()
        return memories.filter { $0.content.lowercased().contains(q) }
    }

    private func refresh() {
        memories = app.memory?.listMemories() ?? []
    }

    private func toggle(_ id: UUID) {
        withAnimation(Theme.Motion.standard) {
            expandedID = expandedID == id ? nil : id
        }
    }
}
