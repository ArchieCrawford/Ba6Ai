import SwiftUI
import PhotosUI
import AVKit

struct VideoView: View {
    @Environment(AppModel.self) private var app
    @State private var vm: VideoViewModel?

    var body: some View {
        Group {
            if let vm {
                VideoSurface(vm: vm)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            guard vm == nil, let engine = app.videoEngine else { return }
            let new = VideoViewModel(engine: engine)
            vm = new
            await new.onAppear()
        }
    }
}

private struct VideoSurface: View {
    @Bindable var vm: VideoViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color(white: 0.05), .black],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("", selection: $vm.mode) {
                        ForEach(VideoViewModel.Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ScrollView {
                        Group {
                            switch vm.mode {
                            case .understand: UnderstandPane(vm: vm)
                            case .generate: GeneratePane(vm: vm)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Understand

private struct UnderstandPane: View {
    @Bindable var vm: VideoViewModel

    var body: some View {
        VStack(spacing: 14) {
            statusBadge

            PhotosPicker(
                selection: $vm.pickerItem,
                matching: .videos
            ) {
                HStack {
                    Image(systemName: "film.stack")
                    Text(vm.videoURL == nil ? "Pick a video" : "Replace video")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .onChange(of: vm.pickerItem) { _, _ in
                Task { await vm.loadPickedVideo() }
            }

            if let url = vm.videoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 20))
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }

            TextField("Ask something about the clip…", text: $vm.question, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            HStack {
                Button(action: vm.isAnswering ? vm.stop : vm.ask) {
                    Label(
                        vm.isAnswering ? "Stop" : "Ask BA6",
                        systemImage: vm.isAnswering ? "stop.fill" : "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
                .disabled(vm.videoURL == nil || vm.question.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !vm.answer.isEmpty {
                Text(vm.answer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .textSelection(.enabled)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: String {
        switch vm.vlmState {
        case .idle: "VLM: idle"
        case .loading(let m, let p): "VLM: loading \(m.displayName) \(Int(p * 100))%"
        case .ready(let m): "VLM: \(m.displayName)"
        case .failed(let msg): "VLM error: \(msg)"
        }
    }

    private var color: Color {
        switch vm.vlmState {
        case .idle: .gray
        case .loading: .yellow
        case .ready: .green
        case .failed: .red
        }
    }
}

// MARK: - Generate

private struct GeneratePane: View {
    @Bindable var vm: VideoViewModel

    var body: some View {
        VStack(spacing: 14) {
            InfoCard()

            TextField("Describe the clip…", text: $vm.prompt, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            knobs

            Button {
                vm.generate()
            } label: {
                Label("Render clip", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .disabled(isRendering)

            progress

            if let url = vm.lastGeneratedURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 240)
                    .clipShape(.rect(cornerRadius: 20))
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
    }

    private var isRendering: Bool {
        if case .rendering = vm.generationState { return true }
        return false
    }

    private var knobs: some View {
        VStack(spacing: 8) {
            LabeledContent("Duration") {
                Slider(value: $vm.durationSeconds, in: 1...6, step: 0.5)
                Text("\(String(format: "%.1f", vm.durationSeconds))s")
                    .font(.caption.monospaced())
                    .frame(width: 40)
            }
            LabeledContent("FPS") {
                Stepper("\(vm.fps)", value: $vm.fps, in: 8...24, step: 2)
            }
            LabeledContent("Resolution") {
                Picker("", selection: $vm.resolution) {
                    Text("256").tag(256)
                    Text("320").tag(320)
                    Text("384").tag(384)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var progress: some View {
        switch vm.generationState {
        case .idle:
            EmptyView()
        case .rendering(let frame, let total):
            VStack(alignment: .leading, spacing: 4) {
                Text("Rendering \(frame) / \(total)").font(.caption)
                ProgressView(value: total > 0 ? Double(frame) / Double(total) : 0)
            }
            .padding(.horizontal, 4)
        case .finished:
            Text("Done").font(.caption).foregroundStyle(.green)
        case .failed(let m):
            Text("⚠️ \(m)").font(.caption).foregroundStyle(.red)
        }
    }
}

private struct InfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Generation preview", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("The full Metal + AVAssetWriter pipeline is live. The diffusion model that paints each frame isn't wired yet — for now you'll see a prompt-seeded gradient so you can verify the render loop and file output.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}
