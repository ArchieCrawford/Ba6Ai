import Foundation

/// One source of truth for how prompts get assembled before they hit a
/// model.
///
/// Why split this out: the system prompt, memory injection format, and
/// chat-template shape all evolve over time, and the *same* shape has
/// to be used by MLX, Core ML, and Remote providers. Centralising it
/// here means a tweak to BA6's tone or memory framing changes one
/// file, not three.
public enum PromptEngine {
    /// The persona. Keep it short — long system prompts steal context.
    public static let basePersona: String = """
    You are BA6 AI — a private, on-device intelligence layer for Apple \
    devices. Be direct, practical, and concise. Prefer short answers \
    unless the user asks for depth. Never invent personal details about \
    the user. Everything stays on this device unless the user explicitly \
    enables Cloud Boost.
    """

    /// Builds the system prompt with optional retrieved memories.
    public static func systemPrompt(memories: [String]) -> String {
        var s = basePersona
        if !memories.isEmpty {
            s += "\n\nRelevant memory:"
            for m in memories.prefix(8) {
                s += "\n- \(m)"
            }
        }
        return s
    }

    /// Provider-agnostic chat-template message list.
    /// MLX's `UserInput` and our remote wire format both consume this.
    public static func buildMessages(_ request: InferenceRequest) -> [[String: String]] {
        var messages: [[String: String]] = []
        messages.append([
            "role": "system",
            "content": systemPrompt(memories: request.memories)
        ])
        for turn in request.history {
            messages.append(["role": turn.role.rawValue, "content": turn.content])
        }
        messages.append(["role": "user", "content": request.prompt])
        return messages
    }

    /// Detect a "remember this …" instruction and extract the fact to
    /// persist. Heuristic but works well for the natural-language
    /// shape users actually type. Returning nil means: don't save a
    /// memory, just answer the prompt.
    public static func extractMemoryDirective(from prompt: String) -> String? {
        let lower = prompt.lowercased()
        let triggers = [
            "remember that ",
            "remember this: ",
            "remember: ",
            "make a note: ",
            "make a note that ",
            "note that "
        ]
        for trigger in triggers {
            if let range = lower.range(of: trigger) {
                let start = prompt.index(prompt.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                let rest = String(prompt[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty { return rest }
            }
        }
        return nil
    }
}
