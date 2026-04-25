import Foundation

/// Shared chat / inference types used by every provider, the prompt
/// engine, and the chat view model.

public struct ChatTurn: Hashable, Sendable, Codable {
    public enum Role: String, Sendable, Codable { case system, user, assistant }
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public struct InferenceRequest: Sendable {
    public var prompt: String
    public var history: [ChatTurn]
    public var memories: [String]
    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float
    public var preference: InferencePreference
    public var attachments: [InferenceAttachment]

    public init(
        prompt: String,
        history: [ChatTurn] = [],
        memories: [String] = [],
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.95,
        preference: InferencePreference = .auto,
        attachments: [InferenceAttachment] = []
    ) {
        self.prompt = prompt
        self.history = history
        self.memories = memories
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.preference = preference
        self.attachments = attachments
    }
}

public enum InferenceAttachment: Sendable {
    case image(Data)
    case videoFrames([Data])
}

/// User-facing toggle: how should the engine decide where to run a
/// request? `auto` is the smart default.
public enum InferencePreference: String, Sendable, Codable, CaseIterable {
    case auto
    case localOnly
    case cloudBoost
}

/// What a provider can do. The router uses this to pick between
/// providers when `auto` is set.
public struct ProviderCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let textGeneration   = ProviderCapabilities(rawValue: 1 << 0)
    public static let vision           = ProviderCapabilities(rawValue: 1 << 1)
    public static let embeddings       = ProviderCapabilities(rawValue: 1 << 2)
    public static let runsOffline      = ProviderCapabilities(rawValue: 1 << 3)
    public static let largeContext     = ProviderCapabilities(rawValue: 1 << 4)
}

/// Live state of a provider. Surfaced to the UI so chips/badges can
/// reflect "loading…", "ready", or "failed".
public enum ProviderState: Equatable, Sendable {
    case idle
    case loading(progress: Double)
    case ready
    case failed(String)
}
