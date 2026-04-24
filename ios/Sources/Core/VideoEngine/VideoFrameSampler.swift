import AVFoundation
import CoreGraphics
import CoreImage

/// Extracts evenly-spaced frames from a video asset for VLM consumption.
///
/// We don't pass raw frames to the model — typical VLMs want 4–16 stills
/// with a long side of ~384–512px. This sampler picks N timestamps,
/// extracts the nearest keyframe-ish image, and downsamples.
enum VideoFrameSampler {
    struct Frame: Sendable {
        let time: CMTime
        let image: CGImage
    }

    static func evenlySpacedFrames(
        from url: URL,
        count: Int,
        longSide: Int = 448
    ) async throws -> [Frame] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let total = CMTimeGetSeconds(duration)
        guard total.isFinite, total > 0, count > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = .init(width: longSide, height: longSide)

        // Skip the exact endpoints; they're often black / title frames.
        let step = total / Double(count + 1)
        let times: [CMTime] = (1...count).map { i in
            CMTime(seconds: step * Double(i), preferredTimescale: 600)
        }

        return try await withThrowingTaskGroup(of: (Int, Frame).self) { group in
            for (idx, time) in times.enumerated() {
                group.addTask {
                    let result = try await generator.image(at: time)
                    return (idx, Frame(time: result.actualTime, image: result.image))
                }
            }
            var collected: [(Int, Frame)] = []
            for try await pair in group { collected.append(pair) }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
