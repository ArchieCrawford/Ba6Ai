import Foundation
import MLX
import MLXLMCommon
import MLXLLM

/// On-device LLM provider backed by MLX. Conforms to `InferenceProvider`
/// so the engine can swap it for Core ML or Remote at runtime.
///
/// Streams tokens as they're produced — the chat surface paints them
/// the moment they arrive. That's what makes BA6 feel native rather
/// than "loading…".
public actor MLXProvider: InferenceProvider {
    public nonisolated let capabilities: ProviderCapabilities = [
        .textGeneration, .vision, .runsOffline
    ]

    public private(set) var state: ProviderState = .idle
    public private(set) var current: BA6Model?
    private var container: ModelContainer?

    public init() {}

    public func warmup() async {
        guard state == .idle else { return }
        try? await load(.default)
    }

    public func load(_ model: BA6Model) async throws {
        if current == model, container != nil { return }
        state = .loading(progress: 0)
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let factory = LLMModelFactory.shared
        let container = try await factory.loadContainer(
            configuration: model.configuration
        ) { [weak self] progress in
            Task { await self?.updateProgress(progress.fractionCompleted) }
        }
        self.container = container
        self.current = model
        self.state = .ready
    }

    private func updateProgress(_ fraction: Double) {
        if case .loading = state { state = .loading(progress: fraction) }
    }

    // MARK: - Streaming

    public func stream(_ request: InferenceRequest) -> AsyncThrowingStream<String, Error> {
        let container = self.container
        let parameters = GenerateParameters(
            temperature: request.temperature,
            topP: request.topP
        )
        let maxTokens = request.maxTokens
        let messages = PromptEngine.buildMessages(request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let container else { throw EngineError.notLoaded }
                    let userInput = UserInput(messages: messages)

                    _ = try await container.perform { (context: ModelContext) -> Void in
                        let lmInput = try await context.processor.prepare(input: userInput)
                        let iterator = try TokenIterator(
                            input: lmInput,
                            model: context.model,
                            parameters: parameters
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

    enum EngineError: LocalizedError {
        case notLoaded
        var errorDescription: String? { "Local model has not been loaded yet." }
    }
}
