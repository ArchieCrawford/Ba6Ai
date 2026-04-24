import Foundation

/// Optional stateless Cloud Boost path for long prompts / big models.
///
/// * Requests are signed with `RequestSigner` so the backend knows it's
///   the same device without any account.
/// * Body is sent over HTTPS; a future version will layer on hybrid
///   encryption (HPKE) so even the cloud operator can't read it.
/// * No session state is kept server-side — each request is answered,
///   returned, and discarded.
///
/// This file is a stub. Wire it up when you stand up the Boost backend.
actor CloudBoostClient {
    struct Config: Sendable {
        var baseURL: URL
        var defaultModel: String = "ba6-cloud-large"
    }

    struct CompletionRequest: Codable, Sendable {
        let prompt: String
        let history: [Turn]
        let model: String

        struct Turn: Codable, Sendable {
            let role: String
            let content: String
        }
    }

    let config: Config
    let signer: RequestSigner

    init(config: Config, signer: RequestSigner) {
        self.config = config
        self.signer = signer
    }

    /// Streams tokens back from the backend via server-sent events.
    /// The backend is responsible for emitting `data: {"delta": "..."}`
    /// chunks and closing the stream with `data: [DONE]`.
    func stream(
        prompt: String,
        history: [ChatTurn]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try JSONEncoder().encode(CompletionRequest(
                        prompt: prompt,
                        history: history.map { .init(role: $0.role.rawValue, content: $0.content) },
                        model: config.defaultModel
                    ))

                    var request = URLRequest(url: config.baseURL.appending(path: "/v1/stream"))
                    request.httpMethod = "POST"
                    request.httpBody = body
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let headers = try signer.sign(
                        method: "POST",
                        path: "/v1/stream",
                        body: body
                    )
                    headers.apply(to: &request)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst("data: ".count)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode([String: String].self, from: data),
                           let delta = decoded["delta"] {
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
}
