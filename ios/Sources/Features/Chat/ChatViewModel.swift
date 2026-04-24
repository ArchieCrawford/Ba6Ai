import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    struct Bubble: Identifiable, Hashable {
        let id: String
        var role: ChatTurn.Role
        var content: String
        var isStreaming: Bool
    }

    private(set) var bubbles: [Bubble] = []
    private(set) var conversationID: String?
    var draft: String = ""
    var isGenerating: Bool { currentTask != nil }
    var modelState: LLMEngine.State = .idle
    var selectedModel: BA6Model = .default

    private var currentTask: Task<Void, Never>?
    private let engine: LLMEngine
    private let memory: MemoryStore

    init(engine: LLMEngine, memory: MemoryStore) {
        self.engine = engine
        self.memory = memory
    }

    func onAppear() async {
        await refreshModelState()
        if modelState == .idle {
            await loadModel(selectedModel)
        }
        if conversationID == nil {
            do {
                let convo = try memory.createConversation()
                conversationID = convo.id
            } catch {
                append(system: "Couldn't start a conversation: \(error.localizedDescription)")
            }
        }
    }

    func refreshModelState() async {
        modelState = await engine.state
    }

    func loadModel(_ model: BA6Model) async {
        selectedModel = model
        do {
            try await engine.load(model)
        } catch {
            append(system: "Model load failed: \(error.localizedDescription)")
        }
        await refreshModelState()
    }

    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        draft = ""

        guard let conversationID else { return }

        let userBubble = Bubble(
            id: UUID().uuidString,
            role: .user,
            content: prompt,
            isStreaming: false
        )
        bubbles.append(userBubble)

        do {
            _ = try memory.appendMessage(
                conversationID: conversationID,
                role: .user,
                content: prompt
            )
        } catch {
            append(system: "Couldn't save message: \(error.localizedDescription)")
        }

        let assistant = Bubble(
            id: UUID().uuidString,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        bubbles.append(assistant)
        let assistantID = assistant.id

        currentTask = Task { [weak self, engine] in
            guard let self else { return }
            do {
                let history = self.bubbles
                    .dropLast(2)
                    .map { ChatTurn(role: $0.role, content: $0.content) }

                let stream = await engine.stream(
                    prompt: prompt,
                    history: history,
                    memories: []
                )
                for try await piece in stream {
                    await self.appendDelta(piece, to: assistantID)
                }
                await self.finalize(assistantID: assistantID, success: true)
            } catch {
                await self.finalize(
                    assistantID: assistantID,
                    success: false,
                    errorText: error.localizedDescription
                )
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Helpers

    private func appendDelta(_ delta: String, to id: String) {
        guard let idx = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[idx].content += delta
    }

    private func finalize(assistantID: String, success: Bool, errorText: String? = nil) {
        guard let idx = bubbles.firstIndex(where: { $0.id == assistantID }) else { return }
        if !success, let errorText {
            bubbles[idx].content = "⚠️ \(errorText)"
        }
        bubbles[idx].isStreaming = false
        currentTask = nil

        if success, let conversationID {
            try? memory.appendMessage(
                conversationID: conversationID,
                role: .assistant,
                content: bubbles[idx].content
            )
        }
    }

    private func append(system text: String) {
        bubbles.append(.init(
            id: UUID().uuidString,
            role: .assistant,
            content: text,
            isStreaming: false
        ))
    }
}
