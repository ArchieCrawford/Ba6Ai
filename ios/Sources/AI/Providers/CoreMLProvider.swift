import Foundation
import CoreML
import NaturalLanguage

/// Apple Neural Engine path via Core ML.
///
/// Why this exists alongside MLX:
/// * MLX runs general LLMs *fast* on the GPU + ANE, but eats memory
///   and warm-up time. Core ML is the better path for *small,
///   distilled* models (e.g. a 350M-class summariser, an embedding
///   model, an on-device classifier) where ANE-only execution wins on
///   energy and latency.
/// * App Intents and shortcuts often need a sub-second response. A
///   tiny Core ML model behind this provider gives that without
///   spinning up the full LLM.
///
/// What's wired today:
/// * Embedding generation via `NLEmbedding` — used by
///   `MemoryContext` to score relevance against stored memories.
///   Ships with the system, no model download required.
///
/// What's stubbed:
/// * `stream(_:)` for full text generation. Drop in a Core ML-converted
///   distilled model (Phi-mini Core ML, etc.) and replace the stub.
public actor CoreMLProvider: InferenceProvider {
    public nonisolated let capabilities: ProviderCapabilities = [
        .embeddings, .runsOffline
    ]

    public private(set) var state: ProviderState = .idle
    private var sentenceEmbedding: NLEmbedding?

    public init() {}

    public func warmup() async {
        guard state == .idle else { return }
        state = .loading(progress: 0.5)
        // NLEmbedding loads lazily; touch it once so first use is instant.
        sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
        state = sentenceEmbedding != nil
            ? .ready
            : .failed("System sentence embedding unavailable.")
    }

    /// Embed a string with the system sentence model. Used by
    /// `MemoryContext` for retrieval. Output dim is fixed by the model
    /// (~512 for English).
    public func embed(_ text: String) async -> [Float]? {
        if sentenceEmbedding == nil { await warmup() }
        guard let embedding = sentenceEmbedding else { return nil }
        guard let vector = embedding.vector(for: text) else { return nil }
        return vector.map(Float.init)
    }

    public func stream(_ request: InferenceRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.notImplemented)
        }
    }

    enum ProviderError: LocalizedError {
        case notImplemented
        var errorDescription: String? {
            "Core ML text generation isn't wired yet. Convert a small instruct model and plug it in here."
        }
    }
}
