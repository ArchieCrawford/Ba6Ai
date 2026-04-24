import Foundation
import MLXLMCommon

/// Vision-language + text-to-video models available to the video engine.
enum VideoModel: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Understanding (VLM) — captions, Q&A, frame-by-frame analysis.
    case qwen25vl3b
    case qwen25vl7b

    // Generation — currently a placeholder until an MLX-compatible
    // text-to-video model ships. LTX Video 2B and Wan 2.1 are the two
    // most likely candidates to land first; both target the same
    // diffusion loop so the Metal renderer below already knows how to
    // host them.
    case ltxVideo2bPreview

    var id: String { rawValue }

    var capability: Capability {
        switch self {
        case .qwen25vl3b, .qwen25vl7b: .understanding
        case .ltxVideo2bPreview: .generation
        }
    }

    enum Capability: String, Sendable { case understanding, generation }

    var displayName: String {
        switch self {
        case .qwen25vl3b: "Qwen 2.5-VL 3B · 4-bit"
        case .qwen25vl7b: "Qwen 2.5-VL 7B · 4-bit"
        case .ltxVideo2bPreview: "LTX Video 2B · preview"
        }
    }

    var approximateSizeMB: Int {
        switch self {
        case .qwen25vl3b: 2100
        case .qwen25vl7b: 4800
        case .ltxVideo2bPreview: 1600
        }
    }

    var configuration: ModelConfiguration {
        switch self {
        case .qwen25vl3b:
            ModelConfiguration(id: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        case .qwen25vl7b:
            ModelConfiguration(id: "mlx-community/Qwen2.5-VL-7B-Instruct-4bit")
        case .ltxVideo2bPreview:
            // No public MLX port yet; the VideoGenerator treats this as a
            // feature-flagged stub and renders a debug gradient until the
            // diffusion weights are wired in.
            ModelConfiguration(id: "mlx-community/LTX-Video-2B-preview-4bit")
        }
    }

    static let defaultUnderstanding: VideoModel = .qwen25vl3b
}
