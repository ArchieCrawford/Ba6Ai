import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

@Observable
@MainActor
final class VideoViewModel {
    enum Mode: String, CaseIterable, Identifiable, Hashable {
        case understand = "Understand"
        case generate = "Generate"
        var id: String { rawValue }
    }

    var mode: Mode = .understand

    // Understanding state
    var pickerItem: PhotosPickerItem?
    var videoURL: URL?
    var question: String = "What happens in this clip?"
    var answer: String = ""
    var isAnswering = false
    var vlmState: VideoEngine.State = .idle

    // Generation state
    var prompt: String = "A neon jellyfish drifting through deep-sea fog"
    var durationSeconds: Double = 3
    var fps: Int = 12
    var resolution: Int = 320
    var generationState: VideoGenerator.State = .idle
    var lastGeneratedURL: URL?

    private let engine: VideoEngine
    private let generator: VideoGenerator?
    private var answerTask: Task<Void, Never>?
    private var generateTask: Task<Void, Never>?

    init(engine: VideoEngine) {
        self.engine = engine
        self.generator = try? VideoGenerator()
    }

    // MARK: - Understanding

    func onAppear() async {
        vlmState = await engine.state
        if case .idle = vlmState {
            do {
                try await engine.load(.defaultUnderstanding)
            } catch {
                // surfaced via state below
            }
        }
        vlmState = await engine.state
    }

    func loadPickedVideo() async {
        guard let pickerItem else { return }
        do {
            if let data = try await pickerItem.loadTransferable(type: Data.self) {
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString + ".mov")
                try data.write(to: url)
                videoURL = url
            }
        } catch {
            answer = "Couldn't load video: \(error.localizedDescription)"
        }
    }

    func ask() {
        guard let videoURL, !question.isEmpty, !isAnswering else { return }
        answer = ""
        isAnswering = true

        answerTask = Task { [engine] in
            let stream = await engine.describe(video: videoURL, question: self.question)
            do {
                for try await piece in stream {
                    self.answer += piece
                }
            } catch {
                self.answer += "\n⚠️ \(error.localizedDescription)"
            }
            self.isAnswering = false
        }
    }

    func stop() {
        answerTask?.cancel()
        answerTask = nil
        isAnswering = false
    }

    // MARK: - Generation

    func generate() {
        guard let generator, generateTask == nil else { return }
        generationState = .rendering(frame: 0, total: 1)

        let request = VideoGenerator.Request(
            prompt: prompt,
            seconds: durationSeconds,
            fps: fps,
            width: resolution,
            height: resolution,
            seed: UInt64(abs(prompt.hashValue))
        )
        let url = VideoGenerator.makeOutputURL()

        generateTask = Task { [weak self] in
            defer { Task { @MainActor in self?.generateTask = nil } }
            do {
                _ = try await generator.generate(request, to: url)
                let state = await generator.state
                await MainActor.run {
                    self?.generationState = state
                    if case .finished(let finalURL) = state {
                        self?.lastGeneratedURL = finalURL
                    }
                }
                // Poll progress while rendering: generator's `state` is
                // the source of truth; surface it to the UI.
            } catch {
                await MainActor.run {
                    self?.generationState = .failed(error.localizedDescription)
                }
            }
        }

        // Progress watcher — peek at the actor's state at ~15 Hz.
        Task { [weak self] in
            while let self, self.generateTask != nil {
                let s = await generator.state
                await MainActor.run { self.generationState = s }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }
}
