import Foundation
import CoreData
import Combine

/// Core Data-backed memory store. CRUD lives here; the in-memory
/// vector index sits alongside for fast cosine-similarity retrieval.
///
/// Concurrency: `MemoryStore` is `@MainActor`. Reads return
/// value-types (see `Models.swift`) so they can travel across actor
/// boundaries safely. Writes hop to a background context internally.
@MainActor
public final class MemoryStore: ObservableObject {
    public let persistence: PersistenceController
    private let vectorIndex = VectorIndex()

    /// Re-emits whenever the store changes so views can refresh.
    @Published public private(set) var version: Int = 0

    public init(persistence: PersistenceController) {
        self.persistence = persistence
        rebuildVectorIndex()
        observeRemoteChanges()
    }

    // MARK: - Conversations

    @discardableResult
    public func createConversation(title: String = "New Chat") -> Conversation {
        let ctx = persistence.viewContext
        let entity = ConversationEntity(context: ctx)
        let now = Date()
        entity.id = UUID()
        entity.title = title
        entity.createdAt = now
        entity.updatedAt = now
        save(ctx)
        bump()
        return entity.toValue()
    }

    public func listConversations() -> [Conversation] {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return ((try? persistence.viewContext.fetch(request)) ?? []).map { $0.toValue() }
    }

    public func deleteConversation(id: UUID) {
        let ctx = persistence.viewContext
        guard let entity = fetchConversation(id: id, in: ctx) else { return }
        ctx.delete(entity)
        save(ctx)
        bump()
    }

    // MARK: - Messages

    @discardableResult
    public func appendMessage(
        conversationID: UUID,
        role: ChatTurn.Role,
        content: String
    ) -> Message? {
        let ctx = persistence.viewContext
        guard let convo = fetchConversation(id: conversationID, in: ctx) else { return nil }
        let entity = MessageEntity(context: ctx)
        let now = Date()
        entity.id = UUID()
        entity.role = role.rawValue
        entity.content = content
        entity.createdAt = now
        entity.conversation = convo
        convo.updatedAt = now
        save(ctx)
        bump()
        return entity.toValue()
    }

    public func messages(in conversationID: UUID) -> [Message] {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return ((try? persistence.viewContext.fetch(request)) ?? []).map { $0.toValue() }
    }

    // MARK: - Memories

    @discardableResult
    public func rememberFact(
        _ content: String,
        sourceMessageID: UUID? = nil,
        embedding: [Float]? = nil,
        pinned: Bool = false
    ) -> Memory {
        let ctx = persistence.viewContext
        let entity = MemoryEntity(context: ctx)
        entity.id = UUID()
        entity.content = content
        entity.createdAt = Date()
        entity.sourceMessageID = sourceMessageID
        entity.pinned = pinned
        entity.vector = embedding?.asData
        save(ctx)
        if let embedding, let id = entity.id {
            vectorIndex.upsert(id: id.uuidString, vector: embedding)
        }
        bump()
        return entity.toValue()
    }

    public func listMemories(pinnedOnly: Bool = false) -> [Memory] {
        let request = NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
        if pinnedOnly { request.predicate = NSPredicate(format: "pinned == YES") }
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return ((try? persistence.viewContext.fetch(request)) ?? []).map { $0.toValue() }
    }

    public func setPinned(_ id: UUID, pinned: Bool) {
        let ctx = persistence.viewContext
        guard let entity = fetchMemory(id: id, in: ctx) else { return }
        entity.pinned = pinned
        save(ctx)
        bump()
    }

    public func forget(_ id: UUID) {
        let ctx = persistence.viewContext
        guard let entity = fetchMemory(id: id, in: ctx) else { return }
        ctx.delete(entity)
        save(ctx)
        vectorIndex.remove(id: id.uuidString)
        bump()
    }

    public func forgetSession(conversationID: UUID) {
        let ctx = persistence.viewContext
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
        let messageIDs = ((try? ctx.fetch(request)) ?? []).compactMap(\.id)

        let memReq = NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
        memReq.predicate = NSPredicate(format: "sourceMessageID IN %@", messageIDs)
        for entity in (try? ctx.fetch(memReq)) ?? [] {
            if let mid = entity.id { vectorIndex.remove(id: mid.uuidString) }
            ctx.delete(entity)
        }
        save(ctx)
        bump()
    }

    public func wipeAllMemory() {
        let ctx = persistence.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = MemoryEntity.fetchRequest()
        let delete = NSBatchDeleteRequest(fetchRequest: request)
        delete.resultType = .resultTypeObjectIDs
        if let result = try? persistence.container.persistentStoreCoordinator.execute(delete, with: ctx) as? NSBatchDeleteResult,
           let ids = result.result as? [NSManagedObjectID] {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                into: [persistence.viewContext]
            )
        }
        vectorIndex.clear()
        bump()
    }

    // MARK: - Retrieval

    public func topMemories(near query: [Float], k: Int = 5) -> [Memory] {
        let ids = vectorIndex.topK(query: query, k: k).compactMap(UUID.init)
        guard !ids.isEmpty else { return [] }
        let ctx = persistence.viewContext
        let request = NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
        request.predicate = NSPredicate(format: "id IN %@", ids)
        return ((try? ctx.fetch(request)) ?? []).map { $0.toValue() }
    }

    // MARK: - Internals

    private func rebuildVectorIndex() {
        vectorIndex.clear()
        let request = NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
        for entity in (try? persistence.viewContext.fetch(request)) ?? [] {
            guard let id = entity.id, let vec = entity.vectorAsFloats else { continue }
            vectorIndex.upsert(id: id.uuidString, vector: vec)
        }
    }

    private func observeRemoteChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistence.container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildVectorIndex()
                self?.bump()
            }
        }
    }

    private func fetchConversation(id: UUID, in ctx: NSManagedObjectContext) -> ConversationEntity? {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private func fetchMemory(id: UUID, in ctx: NSManagedObjectContext) -> MemoryEntity? {
        let request = NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private func save(_ ctx: NSManagedObjectContext) {
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch { assertionFailure("Save failed: \(error)") }
    }

    private func bump() { version &+= 1 }
}
