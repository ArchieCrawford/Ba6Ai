import Foundation
import CoreImage
import MLX
import MLXLMCommon
import MLXVLM

/// Actor that owns the video understanding (VLM) path.
///
/// Shape mirrors `LLMEngine`: `load` → `stream(describe:...)` token
/// deltas. Generation lives in `VideoGenerator` — a separate actor so
/// understanding and generation can run independently and be toggled
/// per user flow.
actor VideoEngine {
    enum State: Equatable {
        case idle
        case loading(VideoModel, progress: Double)
        case ready(VideoModel)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var container: ModelContainer?
    private var current: VideoModel?

    struct Parameters: Sendable {
        var maxTokens: Int = 600
        var temperature: Float = 0.5
        var topP: Float = 0.9

        var mlxParameters: GenerateParameters {
            GenerateParameters(temperature: temperature, topP: topP)
        }
    }

    var parameters = Parameters()

    // MARK: - Lifecycle

    func load(_ model: VideoModel = .defaultUnderstanding) async throws {
        guard model.capability == .understanding else {
            throw EngineError.wrongCapability
        }
        if current == model, container != nil { return }

        state = .loading(model, progress: 0)
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let container = try await VLMModelFactory.shared.loadContainer(
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

    // MARK: - Understanding

    /// Streams a response about the video at `url`, given `question`.
    /// Internally samples N frames and hands them to the VLM.
    func describe(
        video url: URL,
        question: String,
        frames: Int = 8
    ) -> AsyncThrowingStream<String, Error> {
        let container = self.container
        let params = self.parameters.mlxParameters
        let maxTokens = self.parameters.maxTokens

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let container else { throw EngineError.notLoaded }

                    let sampled = try await VideoFrameSampler.evenlySpacedFrames(
                        from: url, count: frames
                    )
                    guard !sampled.isEmpty else {
                        throw EngineError.noFrames
                    }

                    let images: [UserInput.Image] = sampled.map { frame in
                        .ciImage(CIImage(cgImage: frame.image))
                    }

                    let systemPrompt = """
                    You are BA6 AI. You are looking at frames sampled \
                    evenly across a short video. Answer the user's \
                    question based on what is visible across those \
                    frames. Be concrete and brief. If the frames don't \
                    show enough to answer, say so.
                    """

                    let userInput = UserInput(
                        messages: [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": question]
                        ],
                        images: images
                    )

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

    // MARK: - Errors

    enum EngineError: LocalizedError {
        case notLoaded
        case wrongCapability
        case noFrames

        var errorDescription: String? {
            switch self {
            case .notLoaded: "Video model has not been loaded yet."
            case .wrongCapability: "This model isn't a vision-language model."
            case .noFrames: "Couldn't extract frames from the video."
            }
        }
    }
}
