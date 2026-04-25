import SwiftUI
import AppIntents

@main
struct Ba6AiApp: App {
    @State private var appModel = AppModel()

    init() {
        // App Intents need access to inference + memory before the
        // chat surface ever opens, so we register the router as a
        // dependency here. The router itself starts unconfigured and
        // becomes usable once `AppModel.bootstrap()` calls
        // `router.configure(...)`.
        AppDependencyManager.shared.add(dependency: BA6IntentRouter.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .preferredColorScheme(.dark)
                .task { await appModel.bootstrap() }
        }
    }
}

@Observable
@MainActor
public final class AppModel {
    public var identity: DeviceIdentity?
    public var memory: MemoryStore?
    public var engine: InferenceEngine?
    public var videoEngine: VideoEngine?
    public var memoryContext: MemoryContext?
    public var bootError: String?
    public var isReady = false

    public init() {}

    func bootstrap() async {
        do {
            let identity = try DeviceIdentity.loadOrCreate()
            let signer = RequestSigner(identity: identity)
            let persistence = PersistenceController.shared
            let memory = MemoryStore(persistence: persistence)

            // Build the providers + the router that picks between them.
            let mlx = MLXProvider()
            let coreML = CoreMLProvider()
            let remote = RemoteProvider(
                config: .init(
                    baseURL: URL(string: "https://api.ba6ai.com")!,
                    defaultModel: "ba6-cloud-large"
                ),
                signer: signer
            )
            let engine = InferenceEngine(mlx: mlx, coreML: coreML, remote: remote)
            await engine.warmup()

            let memoryContext = MemoryContext(store: memory, coreML: coreML)

            await BA6IntentRouter.shared.configure(
                engine: engine,
                memoryContext: memoryContext
            )

            let videoEngine = VideoEngine()

            self.identity = identity
            self.memory = memory
            self.engine = engine
            self.videoEngine = videoEngine
            self.memoryContext = memoryContext
            self.isReady = true

            _ = await NotificationService.shared.requestAuthorization()
        } catch {
            self.bootError = String(describing: error)
        }
    }
}
