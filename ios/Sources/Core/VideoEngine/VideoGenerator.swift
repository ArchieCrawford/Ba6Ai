import Foundation
import Metal
import AVFoundation
import CoreVideo

/// Text-to-video generation pipeline.
///
/// The plumbing is real and working: MetalRenderer + VideoWriter drive
/// a fixed-rate frame loop and produce a valid HEVC .mp4. The
/// *diffusion model* that fills in each frame is stubbed — when an
/// MLX port of LTX Video / Wan 2.1 / similar lands, the
/// `produceLatent(step:prompt:)` hook below is where it slots in.
///
/// Until then, `generate` renders a deterministic prompt-seeded
/// gradient so we can verify the output path end-to-end (file opens,
/// plays, correct fps, correct duration).
actor VideoGenerator {
    struct Request: Sendable, Hashable {
        var prompt: String
        var seconds: Double = 3
        var fps: Int = 12
        var width: Int = 320
        var height: Int = 320
        var seed: UInt64 = 0xBA6

        var totalFrames: Int { max(1, Int(Double(fps) * seconds)) }
    }

    enum State: Equatable {
        case idle
        case rendering(frame: Int, total: Int)
        case finished(URL)
        case failed(String)
    }

    private(set) var state: State = .idle
    let renderer: MetalRenderer

    init() throws {
        self.renderer = try MetalRenderer()
    }

    // MARK: - Public entry

    /// Render a video for `request` to `outputURL`. Reports progress via
    /// `state` after each frame so the UI can observe.
    func generate(_ request: Request, to outputURL: URL) async throws -> URL {
        state = .rendering(frame: 0, total: request.totalFrames)
        do {
            let writer = try VideoWriter(
                url: outputURL,
                width: request.width,
                height: request.height,
                fps: request.fps
            )

            // Source + destination ping-pong buffers. Source is the raw
            // "latent" — currently a gradient; swap for the diffusion
            // decoder's output. Destination is what goes to the writer.
            let srcPB = try renderer.makeEmptyPixelBuffer(
                width: request.width, height: request.height
            )

            for frame in 0..<request.totalFrames {
                if Task.isCancelled { throw GeneratorError.cancelled }

                fill(
                    pixelBuffer: srcPB,
                    width: request.width,
                    height: request.height,
                    phase: Double(frame) / Double(request.totalFrames),
                    seed: request.seed
                )

                let dstPB = try renderer.makeEmptyPixelBuffer(
                    width: request.width, height: request.height
                )
                let srcTex = try renderer.texture(for: srcPB)
                let dstTex = try renderer.texture(for: dstPB)

                var exposure: Float = 1.4
                try renderer.dispatch(
                    kernel: "ba6_latent_composite_kernel",
                    source: srcTex,
                    destination: dstTex,
                    params: &exposure,
                    paramsLength: MemoryLayout<Float>.size
                )

                try await writer.append(dstPB)
                state = .rendering(frame: frame + 1, total: request.totalFrames)
            }

            try await writer.finish()
            state = .finished(writer.outputURL)
            return writer.outputURL
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Debug latent (replace with diffusion decode)

    private nonisolated func fill(
        pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int,
        phase: Double,
        seed: UInt64
    ) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // Seed-biased gradient so different prompts feel distinct.
        let seedR = Double((seed      ) & 0xFF) / 255.0
        let seedG = Double((seed >>  8) & 0xFF) / 255.0
        let seedB = Double((seed >> 16) & 0xFF) / 255.0

        let w = Double(width), h = Double(height)
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) / w
                let v = Double(y) / h
                // BGRA order.
                let r = min(1, 0.5 * (sin((u + phase) * .pi * 2) + 1)) * seedR + 0.1
                let g = min(1, 0.5 * (sin((v + phase * 1.3) * .pi * 2) + 1)) * seedG + 0.1
                let b = min(1, 0.5 * (sin((u + v + phase) * .pi * 2) + 1)) * seedB + 0.1

                let o = y * bytesPerRow + x * 4
                ptr[o + 0] = UInt8(b * 255)
                ptr[o + 1] = UInt8(g * 255)
                ptr[o + 2] = UInt8(r * 255)
                ptr[o + 3] = 255
            }
        }
    }

    // MARK: - Output location

    /// Where generated clips land. Documents dir so they survive relaunches
    /// and are visible to Files.app (if we add `LSSupportsOpeningDocumentsInPlace`).
    static func makeOutputURL(prefix: String = "ba6") -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ts = Int(Date().timeIntervalSince1970)
        return dir.appendingPathComponent("\(prefix)-\(ts).mp4")
    }

    enum GeneratorError: LocalizedError {
        case cancelled
        var errorDescription: String? { "Generation cancelled." }
    }
}
