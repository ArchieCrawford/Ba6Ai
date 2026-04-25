import Foundation
import Metal
import MetalKit
import CoreVideo
import CoreImage

/// Metal compute host for the video pipeline.
///
/// Responsibilities:
///
/// * Own the `MTLDevice`, queue, library, and pipeline states.
/// * Convert `CVPixelBuffer`s ↔ `MTLTexture`s via a shared
///   `CVMetalTextureCache` (zero-copy on IOSurface).
/// * Dispatch compute kernels from `Shaders.metal`.
///
/// MLX already uses Metal internally for inference. This renderer is
/// the layer *around* MLX: it composites latents / frames into the
/// output texture that `AVAssetWriter` reads back.
final class MetalRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let library: MTLLibrary
    private var pipelines: [String: MTLComputePipelineState] = [:]
    private var textureCache: CVMetalTextureCache

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.noDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.noQueue
        }
        let library = try device.makeDefaultLibrary(bundle: .main)

        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault, nil, device, nil, &cache
        )
        guard status == kCVReturnSuccess, let cache else {
            throw RendererError.textureCacheFailure(status)
        }

        self.device = device
        self.queue = queue
        self.library = library
        self.textureCache = cache

        try warmup(kernels: [
            "ba6_identity_kernel",
            "ba6_posterize_kernel",
            "ba6_latent_composite_kernel"
        ])
    }

    private func warmup(kernels names: [String]) throws {
        for name in names {
            guard let fn = library.makeFunction(name: name) else {
                throw RendererError.missingKernel(name)
            }
            pipelines[name] = try device.makeComputePipelineState(function: fn)
        }
    }

    // MARK: - Texture helpers

    func makeEmptyPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary, &pb
        )
        guard status == kCVReturnSuccess, let pb else {
            throw RendererError.pixelBufferCreate(status)
        }
        return pb
    }

    func texture(for pixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTex: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTex
        )
        guard status == kCVReturnSuccess,
              let cvTex,
              let tex = CVMetalTextureGetTexture(cvTex) else {
            throw RendererError.textureConversion(status)
        }
        return tex
    }

    // MARK: - Dispatch

    /// Runs `kernel` with `source` → `destination`. Optional `params`
    /// buffer is bound at `buffer(0)`.
    func dispatch(
        kernel: String,
        source: MTLTexture,
        destination: MTLTexture,
        params: UnsafePointer<Float>? = nil,
        paramsLength: Int = 0
    ) throws {
        guard let pipeline = pipelines[kernel] else {
            throw RendererError.missingKernel(kernel)
        }
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            throw RendererError.commandFailure
        }
        enc.setComputePipelineState(pipeline)
        enc.setTexture(source, index: 0)
        enc.setTexture(destination, index: 1)
        if let params, paramsLength > 0 {
            enc.setBytes(params, length: paramsLength, index: 0)
        }

        let tw = pipeline.threadExecutionWidth
        let th = max(1, pipeline.maxTotalThreadsPerThreadgroup / tw)
        let tg = MTLSize(width: tw, height: th, depth: 1)
        let grid = MTLSize(
            width: (destination.width + tw - 1) / tw,
            height: (destination.height + th - 1) / th,
            depth: 1
        )
        enc.dispatchThreadgroups(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        if let err = cmd.error {
            throw RendererError.gpuError(err.localizedDescription)
        }
    }

    // MARK: - Errors

    enum RendererError: LocalizedError {
        case noDevice
        case noQueue
        case textureCacheFailure(CVReturn)
        case missingKernel(String)
        case pixelBufferCreate(CVReturn)
        case textureConversion(CVReturn)
        case commandFailure
        case gpuError(String)

        var errorDescription: String? {
            switch self {
            case .noDevice: "No Metal device available on this system."
            case .noQueue: "Couldn't create a Metal command queue."
            case .textureCacheFailure(let s): "CVMetalTextureCache failed (\(s))."
            case .missingKernel(let k): "Metal kernel not found: \(k)."
            case .pixelBufferCreate(let s): "CVPixelBufferCreate failed (\(s))."
            case .textureConversion(let s): "Texture conversion failed (\(s))."
            case .commandFailure: "Couldn't create Metal command buffer."
            case .gpuError(let d): "GPU error: \(d)."
            }
        }
    }
}
