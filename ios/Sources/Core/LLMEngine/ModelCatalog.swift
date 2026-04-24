import Foundation
import MLXLMCommon
import MLXLLM

/// On-device models shipped with BA6 AI.
///
/// Start with small 3B-class instruct models quantized to 4-bit so they fit
/// comfortably on an iPhone 15 Pro / 16 family. Larger picks are opt-in via
/// the Boost toggle in Settings.
enum BA6Model: String, CaseIterable, Identifiable, Hashable, Sendable {
    case qwen2_5_3b_4bit
    case llama3_2_3b_4bit
    case phi3_5_mini_4bit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen2_5_3b_4bit: "Qwen 2.5 3B · 4-bit"
        case .llama3_2_3b_4bit: "Llama 3.2 3B · 4-bit"
        case .phi3_5_mini_4bit: "Phi 3.5 Mini · 4-bit"
        }
    }

    var approximateSizeMB: Int {
        switch self {
        case .qwen2_5_3b_4bit: 1900
        case .llama3_2_3b_4bit: 1900
        case .phi3_5_mini_4bit: 2300
        }
    }

    /// MLX model configuration — resolved by `LLMModelFactory` which pulls
    /// the weights from Hugging Face on first use and caches them in the
    /// app's sandbox. Adjust the repo IDs if you self-host.
    var configuration: ModelConfiguration {
        switch self {
        case .qwen2_5_3b_4bit:
            ModelConfiguration(id: "mlx-community/Qwen2.5-3B-Instruct-4bit")
        case .llama3_2_3b_4bit:
            ModelConfiguration(id: "mlx-community/Llama-3.2-3B-Instruct-4bit")
        case .phi3_5_mini_4bit:
            ModelConfiguration(id: "mlx-community/Phi-3.5-mini-instruct-4bit")
        }
    }

    static let `default`: BA6Model = .qwen2_5_3b_4bit
}
