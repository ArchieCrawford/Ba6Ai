import Foundation

/// A pluggable inference backend. Implementations: `MLXProvider`,
/// `CoreMLProvider`, `RemoteProvider`. New providers (a hosted Apple
/// Intelligence model, a federated peer device, ...) only need to
/// conform to this protocol — nothing else changes.
public protocol InferenceProvider: Actor {
    var capabilities: ProviderCapabilities { get }
    var state: ProviderState { get async }
    func warmup() async
    func stream(_ request: InferenceRequest) -> AsyncThrowingStream<String, Error>
}

/// Top-level inference router used by Chat, Memory, App Intents, and
/// the share-sheet entry. Holds every provider, picks the right one
/// per call, and exposes one `stream(_:)` API to the rest of the app.
///
/// Heuristic for `.auto`:
///
/// 1. If the user toggled `.cloudBoost`, always use Remote.
/// 2. If `.localOnly`, always use MLX (or fail if not loaded).
/// 3. Otherwise:
///    * Vision request → MLX (the only on-device VLM today).
///    * Estimated context length above `largeContextThreshold` → Remote.
///    * Else MLX if ready, else Remote, else fail with a clear message.
///
/// All routing happens inside the actor; the call site never touches
/// individual providers.
public actor InferenceEngine {
    public let mlx: MLXProvider
    public let coreML: CoreMLProvider
    public let remote: RemoteProvider

    /// Number of estimated input tokens above which `auto` prefers
    /// Remote over local. Tune per-device class.
    public var largeContextThreshold: Int = 4_000

    public init(mlx: MLXProvider, coreML: CoreMLProvider, remote: RemoteProvider) {
        self.mlx = mlx
        self.coreML = coreML
        self.remote = remote
    }

    public func warmup() async {
        await mlx.warmup()
        await coreML.warmup()
        // Remote never warms up — it's stateless on our side.
    }

    public func stream(_ request: InferenceRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let provider = await self.selectProvider(for: request)
                    let stream = await provider.stream(request)
                    for try await piece in stream {
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Routing

    func selectProvider(for request: InferenceRequest) async -> any InferenceProvider {
        switch request.preference {
        case .cloudBoost:
            return remote
        case .localOnly:
            return mlx
        case .auto:
            if !request.attachments.isEmpty {
                return mlx                                    // only local VLM today
            }
            let estimated = estimateTokens(in: request)
            if estimated > largeContextThreshold {
                return remote
            }
            switch await mlx.state {
            case .ready: return mlx
            default: return remote
            }
        }
    }

    private func estimateTokens(in request: InferenceRequest) -> Int {
        // Rough but stable: ~4 chars / token for English.
        let bodies = request.history.map(\.content) + [request.prompt] + request.memories
        return bodies.reduce(0) { $0 + $1.count / 4 }
    }
}
