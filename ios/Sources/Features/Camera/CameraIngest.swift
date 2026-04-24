import SwiftUI
import Vision
import PhotosUI

/// Phase 4 placeholder for camera + photo library ingestion.
///
/// Pipeline sketch:
///
///   Image → VNRecognizeTextRequest / VNImageRequestHandler
///         → plain-text description + OCR payload
///         → injected as a user message with an image attachment
///
/// Keeping the entry point defined so the Share Extension and Camera
/// features have a stable target for their output.
struct CameraIngestPayload: Sendable, Hashable {
    let ocrText: String
    let caption: String?
    let imageData: Data?
}

enum CameraIngest {
    /// Run Vision text recognition on an image. Async wrapper around
    /// the request/handler pair so callers don't have to deal with
    /// the old callback API.
    static func ocr(image cg: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([req]) } catch { cont.resume(throwing: error) }
            }
        }
    }
}
