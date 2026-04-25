import AVFoundation
import CoreVideo

/// Thin wrapper around `AVAssetWriter` for appending BGRA pixel buffers
/// at a fixed frame rate. Encodes to HEVC (H.265) by default — roughly
/// half the bitrate of H.264 at the same quality on Apple Silicon.
final class VideoWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let frameDuration: CMTime
    private var frameIndex: Int64 = 0

    let outputURL: URL

    init(
        url: URL,
        width: Int,
        height: Int,
        fps: Int = 24,
        codec: AVVideoCodecType = .hevc
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        self.outputURL = url

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        writer.add(input)

        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelAttrs
        )

        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        guard writer.startWriting() else {
            throw WriterError.startFailed(writer.error?.localizedDescription ?? "unknown")
        }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ pixelBuffer: CVPixelBuffer) async throws {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let pts = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
        if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
            throw WriterError.appendFailed(writer.error?.localizedDescription ?? "unknown")
        }
        frameIndex += 1
    }

    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw WriterError.finishFailed(writer.error?.localizedDescription ?? "unknown")
        }
    }

    enum WriterError: LocalizedError {
        case startFailed(String)
        case appendFailed(String)
        case finishFailed(String)

        var errorDescription: String? {
            switch self {
            case .startFailed(let m): "AVAssetWriter start failed: \(m)"
            case .appendFailed(let m): "Frame append failed: \(m)"
            case .finishFailed(let m): "AVAssetWriter finish failed: \(m)"
            }
        }
    }
}
