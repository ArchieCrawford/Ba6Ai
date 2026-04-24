import SwiftUI

@main
struct Ba6AiApp: App {
    @State private var appModel = AppModel()

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
final class AppModel {
    var identity: DeviceIdentity?
    var memory: MemoryStore?
    var engine: LLMEngine?
    var bootError: String?
    var isReady = false

    func bootstrap() async {
        do {
            let identity = try DeviceIdentity.loadOrCreate()
            let memory = try MemoryStore.openDefault()
            let engine = LLMEngine()

            self.identity = identity
            self.memory = memory
            self.engine = engine
            self.isReady = true
        } catch {
            self.bootError = String(describing: error)
        }
    }
}
