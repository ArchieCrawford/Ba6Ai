import Foundation

/// Stateless cloud fallback. Used by the engine when the user enables
/// `Cloud Boost`, when context exceeds the local model's effective
/// window, or when MLX hasn't loaded yet.
///
/// Wire-format: SSE stream of `{"delta": "..."}` chunks terminated by
/// `data: [DONE]`. Every request is signed with the device's Secure
/// Enclave key — no accounts, no tokens.
public actor RemoteProvider: InferenceProvider {
    public nonisolated let capabilities: ProviderCapabilities = [
        .textGeneration, .largeContext
    ]

    public struct Config: Sendable {
        public var baseURL: URL
        public var defaultModel: String

        public init(baseURL: URL, defaultModel: String = "ba6-cloud-large") {
            self.baseURL = baseURL
            self.defaultModel = defaultModel
        }
    }

    public private(set) var state: ProviderState = .ready

    private let config: Config
    private let signer: RequestSigner

    public init(config: Config, signer: RequestSigner) {
        self.config = config
        self.signer = signer
    }

    public func warmup() async {
        // No warmup — server is stateless.
    }

    public func stream(_ request: InferenceRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let payload = WirePayload(
                        prompt: request.prompt,
                        history: request.history.map { .init(role: $0.role.rawValue, content: $0.content) },
                        memories: request.memories,
                        model: config.defaultModel,
                        maxTokens: request.maxTokens,
                        temperature: request.temperature
                    )
                    let body = try JSONEncoder().encode(payload)

                    var urlRequest = URLRequest(url: config.baseURL.appending(path: "/v1/stream"))
                    urlRequest.httpMethod = "POST"
                    urlRequest.httpBody = body
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let headers = try signer.sign(method: "POST", path: "/v1/stream", body: body)
                    headers.apply(to: &urlRequest)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst("data: ".count)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                           let delta = chunk.delta {
                            continuation.yield(delta)
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

    private struct WirePayload: Codable {
        struct Turn: Codable { let role: String; let content: String }
        let prompt: String
        let history: [Turn]
        let memories: [String]
        let model: String
        let maxTokens: Int
        let temperature: Float
    }

    private struct StreamChunk: Codable {
        let delta: String?
    }
}
