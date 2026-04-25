import Foundation
import CoreData

/// Core Data + CloudKit stack.
///
/// CloudKit sync is **off by default**. The user opts in from Settings;
/// when they do, we swap the persistent-store description to one with
/// `cloudKitContainerOptions` set. iCloud private-database semantics
/// mean only the user's own Apple ID can read this data — not us, not
/// anyone else.
///
/// History tracking + remote-change notifications are always on so we
/// can react to writes from extensions (Share Sheet target, future
/// widgets, App Intents background runs).
public final class PersistenceController: @unchecked Sendable {
    public static let shared = PersistenceController()

    public let container: NSPersistentCloudKitContainer
    private let storeURL: URL

    public var viewContext: NSManagedObjectContext { container.viewContext }

    public init(inMemory: Bool = false, cloudSync: Bool = false) {
        let container = NSPersistentCloudKitContainer(name: "BA6AI")
        let description = container.persistentStoreDescriptions.first!

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if cloudSync {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.ai.ba6.Ba6Ai"
            )
        } else {
            description.cloudKitContainerOptions = nil
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data load failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        self.container = container
        self.storeURL = description.url ?? URL(fileURLWithPath: "/dev/null")
    }

    /// Toggle CloudKit sync at runtime. Tears down the existing store
    /// and reloads with the new option.
    public func setCloudSync(_ enabled: Bool) throws {
        let description = container.persistentStoreDescriptions.first!
        description.cloudKitContainerOptions = enabled
            ? NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.ai.ba6.Ba6Ai")
            : nil
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try container.persistentStoreCoordinator.remove(store)
        }
        var loadError: Error?
        container.loadPersistentStores { _, err in loadError = err }
        if let loadError { throw loadError }
    }

    /// Background context for writes from non-UI code (App Intents,
    /// share sheet drains, batch ops). Auto-merges to viewContext.
    public func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}
