import Foundation

/// Glue between App Intents and the rest of BA6.
///
/// Intents run on a different thread (and sometimes a different
/// process) than the chat UI, so they can't reach `AppModel` directly.
/// `BA6IntentRouter` is registered with `AppDependencyManager.shared`
/// at app launch; intents declare `@Dependency var router:
/// BA6IntentRouter` and call its narrow API.
public actor BA6IntentRouter {
    public static let shared = BA6IntentRouter()

    private var engine: InferenceEngine?
    private var memoryContext: MemoryContext?

    private init() {}

    public func configure(engine: InferenceEngine, memoryContext: MemoryContext) {
        self.engine = engine
        self.memoryContext = memoryContext
    }

    /// Run a one-shot prompt and collect the full streamed answer
    /// before returning. Intents need a complete string, not a stream.
    public func answer(_ question: String) async throws -> String {
        guard let engine else { throw RouterError.notConfigured }
        let memories = await memoryContext?.relevantMemories(for: question) ?? []
        let request = InferenceRequest(
            prompt: question,
            history: [],
            memories: memories,
            maxTokens: 320,
            preference: .auto
        )
        var collected = ""
        for try await piece in await engine.stream(request) {
            collected += piece
            if collected.count > 6_000 { break }            // hard cap for Siri readback
        }
        return collected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Persist a fact directly without going through the LLM.
    public func remember(_ fact: String) async throws {
        guard let memoryContext else { throw RouterError.notConfigured }
        _ = await memoryContext.captureMemoryIfDirected(from: "remember that \(fact)")
    }

    enum RouterError: LocalizedError {
        case notConfigured
        var errorDescription: String? {
            "BA6 intent router isn't ready. Open BA6 once, then try again."
        }
    }
}
