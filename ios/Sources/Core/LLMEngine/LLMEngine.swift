import Foundation
import MLX
import MLXLMCommon
import MLXLLM

/// Thin wrapper around `MLXLLM`'s `ModelContainer` that exposes:
///
/// * async `load(_ model:)` — download + load a model into memory
/// * async `stream(prompt:memories:)` → `AsyncStream<String>` of token deltas
///
/// The stream emits incremental text as tokens are decoded. Consume with
/// `for await token in engine.stream(...) { append(token) }` so the UI
/// paints each token the moment it's produced.
actor LLMEngine {
    enum State: Equatable {
        case idle
        case loading(BA6Model, progress: Double)
        case ready(BA6Model)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var container: ModelContainer?
    private var current: BA6Model?

    /// Tunables. Keep `maxTokens` small by default — on-device generation is
    /// fast per-token but latency grows linearly.
    struct Parameters: Sendable {
        var maxTokens: Int = 512
        var temperature: Float = 0.7
        var topP: Float = 0.95
        var repetitionPenalty: Float? = 1.05

        var mlxParameters: GenerateParameters {
            GenerateParameters(
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty
            )
        }
    }

    var parameters = Parameters()

    // MARK: - Lifecycle

    func load(_ model: BA6Model) async throws {
        if current == model, container != nil { return }

        state = .loading(model, progress: 0)

        // MLX can keep ~50% of device RAM without hitting jetsam.
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let factory = LLMModelFactory.shared
        let container = try await factory.loadContainer(
            configuration: model.configuration
        ) { [weak self] progress in
            Task { await self?.updateLoadProgress(progress.fractionCompleted) }
        }

        self.container = container
        self.current = model
        self.state = .ready(model)
    }

    private func updateLoadProgress(_ fraction: Double) {
        if case .loading(let model, _) = state {
            state = .loading(model, progress: fraction)
        }
    }

    // MARK: - Generation

    /// Streams tokens for the given prompt + retrieved memories.
    /// The caller concatenates incoming strings to build the full response.
    func stream(
        prompt: String,
        history: [ChatTurn] = [],
        memories: [String] = []
    ) -> AsyncThrowingStream<String, Error> {
        let container = self.container
        let params = self.parameters.mlxParameters
        let maxTokens = self.parameters.maxTokens

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let container else {
                        throw EngineError.notLoaded
                    }

                    let messages = Self.buildMessages(
                        prompt: prompt,
                        history: history,
                        memories: memories
                    )
                    let userInput = UserInput(messages: messages)

                    _ = try await container.perform { (context: ModelContext) -> Void in
                        let lmInput = try await context.processor.prepare(input: userInput)
                        let iterator = try TokenIterator(
                            input: lmInput,
                            model: context.model,
                            parameters: params
                        )
                        var produced = 0
                        var detokenizer = NaiveStreamingDetokenizer(tokenizer: context.tokenizer)

                        for token in iterator {
                            if Task.isCancelled { break }
                            if token == context.tokenizer.eosTokenId { break }

                            detokenizer.append(token: token)
                            if let piece = detokenizer.next() {
                                continuation.yield(piece)
                            }
                            produced += 1
                            if produced >= maxTokens { break }
                        }
                        if let tail = detokenizer.finalize() {
                            continuation.yield(tail)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prompt assembly

    private static func buildMessages(
        prompt: String,
        history: [ChatTurn],
        memories: [String]
    ) -> [[String: String]] {
        var messages: [[String: String]] = []
        messages.append([
            "role": "system",
            "content": systemPrompt(memories: memories)
        ])
        for turn in history {
            messages.append(["role": turn.role.rawValue, "content": turn.content])
        }
        messages.append(["role": "user", "content": prompt])
        return messages
    }

    private static func systemPrompt(memories: [String]) -> String {
        var s = """
        You are BA6 AI — a private, on-device intelligence layer for Apple \
        devices. Be direct, practical, and concise. Prefer short answers \
        unless the user asks for depth. Never invent personal details about \
        the user. Everything stays on this device.
        """
        if !memories.isEmpty {
            s += "\n\nRelevant memory:\n"
            for m in memories.prefix(8) {
                s += "- \(m)\n"
            }
        }
        return s
    }

    enum EngineError: LocalizedError {
        case notLoaded

        var errorDescription: String? {
            switch self {
            case .notLoaded: "Model has not been loaded yet."
            }
        }
    }
}

struct ChatTurn: Hashable, Sendable {
    enum Role: String, Sendable { case user, assistant }
    let role: Role
    let content: String
}
