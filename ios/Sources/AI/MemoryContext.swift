import Foundation

/// Bridges the Memory store and the inference engine.
///
/// Responsibilities:
/// 1. Decide what existing memories are relevant to the user's current
///    prompt and return their text bodies for injection.
/// 2. Detect "remember this" intent in the prompt, embed the fact, and
///    persist it for next time.
///
/// Embeddings come from `CoreMLProvider` (NLEmbedding under the hood).
/// Retrieval is cosine similarity via `VectorIndex`.
@MainActor
public final class MemoryContext {
    private let store: MemoryStore
    private let coreML: CoreMLProvider
    private let topK: Int

    public init(store: MemoryStore, coreML: CoreMLProvider, topK: Int = 5) {
        self.store = store
        self.coreML = coreML
        self.topK = topK
    }

    /// Look up the most relevant memories for `prompt`. Returns their
    /// content strings ready to drop into a system prompt.
    public func relevantMemories(for prompt: String) async -> [String] {
        guard let query = await coreML.embed(prompt) else { return [] }
        return store.topMemories(near: query, k: topK).map(\.content)
    }

    /// If the user said "remember that …", persist the fact (with an
    /// embedding so retrieval works next time). Returns the new memory
    /// for UI confirmation, or nil if no directive was found.
    @discardableResult
    public func captureMemoryIfDirected(
        from prompt: String,
        sourceMessageID: UUID? = nil
    ) async -> Memory? {
        guard let fact = PromptEngine.extractMemoryDirective(from: prompt) else {
            return nil
        }
        let vector = await coreML.embed(fact)
        return store.rememberFact(
            fact,
            sourceMessageID: sourceMessageID,
            embedding: vector,
            pinned: false
        )
    }
}
