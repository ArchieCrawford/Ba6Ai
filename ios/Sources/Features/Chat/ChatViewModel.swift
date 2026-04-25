import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    struct Bubble: Identifiable, Hashable {
        let id: UUID
        var role: ChatTurn.Role
        var content: String
        var isStreaming: Bool
    }

    private(set) var bubbles: [Bubble] = []
    private(set) var conversationID: UUID?
    var draft: String = ""
    var preference: InferencePreference = .auto

    var isGenerating: Bool { currentTask != nil }
    var providerLabel: String = "Ready"
    var providerStatus: GlassChip.Status = .neutral

    private var currentTask: Task<Void, Never>?
    private let engine: InferenceEngine
    private let memory: MemoryStore
    private let memoryContext: MemoryContext

    init(engine: InferenceEngine, memory: MemoryStore, memoryContext: MemoryContext) {
        self.engine = engine
        self.memory = memory
        self.memoryContext = memoryContext
    }

    // MARK: - Lifecycle

    func onAppear() async {
        if conversationID == nil {
            conversationID = memory.createConversation().id
        }
        await refreshProviderState()
    }

    func refreshProviderState() async {
        let mlxState = await engine.mlx.state
        switch mlxState {
        case .idle:
            providerLabel = "Idle"
            providerStatus = .neutral
        case .loading(let p):
            providerLabel = "Loading \(Int(p * 100))%"
            providerStatus = .warning
        case .ready:
            providerLabel = "On-device"
            providerStatus = .success
        case .failed:
            providerLabel = "Local failed"
            providerStatus = .error
        }
    }

    // MARK: - Send

    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating, let conversationID else { return }
        draft = ""

        let userBubble = Bubble(id: UUID(), role: .user, content: prompt, isStreaming: false)
        bubbles.append(userBubble)
        let userMessage = memory.appendMessage(
            conversationID: conversationID, role: .user, content: prompt
        )

        var assistant = Bubble(id: UUID(), role: .assistant, content: "", isStreaming: true)
        bubbles.append(assistant)
        let assistantID = assistant.id

        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.runTurn(prompt: prompt, userMessageID: userMessage?.id, assistantID: assistantID)
        }
        _ = assistant
    }

    private func runTurn(prompt: String, userMessageID: UUID?, assistantID: UUID) async {
        // Side-effect: capture "remember that …" directives.
        await memoryContext.captureMemoryIfDirected(
            from: prompt, sourceMessageID: userMessageID
        )

        let memories = await memoryContext.relevantMemories(for: prompt)
        let history = bubbles.dropLast(2).map { ChatTurn(role: $0.role, content: $0.content) }

        let request = InferenceRequest(
            prompt: prompt,
            history: history,
            memories: memories,
            preference: preference
        )

        do {
            let stream = await engine.stream(request)
            for try await piece in stream {
                appendDelta(piece, to: assistantID)
            }
            finalize(assistantID: assistantID, success: true)
        } catch {
            finalize(assistantID: assistantID, success: false, errorText: error.localizedDescription)
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Helpers

    private func appendDelta(_ delta: String, to id: UUID) {
        guard let idx = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[idx].content += delta
    }

    private func finalize(assistantID: UUID, success: Bool, errorText: String? = nil) {
        guard let idx = bubbles.firstIndex(where: { $0.id == assistantID }) else { return }
        if !success, let errorText {
            bubbles[idx].content = "⚠️ \(errorText)"
        }
        bubbles[idx].isStreaming = false
        currentTask = nil

        if success, let conversationID {
            memory.appendMessage(
                conversationID: conversationID,
                role: .assistant,
                content: bubbles[idx].content
            )
        }
    }
}
