import Foundation
import GRDB

/// On-device persistence for conversations, messages, and memory flags.
///
/// Backed by SQLite via GRDB. Lives in the app's Application Support
/// directory and is encrypted at rest by iOS Data Protection
/// (`NSFileProtectionCompleteUntilFirstUserAuthentication`).
///
/// The vector index is kept in-memory and rebuilt from `embeddings` on
/// launch — fine for the first ~100k chunks. Swap for USearch when the
/// working set grows.
final class MemoryStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let vectorIndex = VectorIndex()

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
        try loadVectorIndex()
    }

    static func openDefault() throws -> MemoryStore {
        let fm = FileManager.default
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = support.appendingPathComponent("ba6.sqlite")
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL;")
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }
        let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
        try? fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dbURL.path
        )
        return try MemoryStore(dbQueue: queue)
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "conversations") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(table: "messages") { t in
                t.primaryKey("id", .text)
                t.column("conversation_id", .text)
                    .notNull()
                    .references("conversations", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(table: "memories") { t in
                t.primaryKey("id", .text)
                t.column("content", .text).notNull()
                t.column("source_message_id", .text)
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(table: "embeddings") { t in
                t.primaryKey("memory_id", .text)
                    .references("memories", onDelete: .cascade)
                t.column("dim", .integer).notNull()
                t.column("vector", .blob).notNull()
            }
        }
        return m
    }

    // MARK: - Conversations

    func createConversation(title: String = "New Chat") throws -> Conversation {
        let now = Date()
        let convo = Conversation(
            id: UUID().uuidString,
            title: title,
            createdAt: now,
            updatedAt: now
        )
        try dbQueue.write { try convo.insert($0) }
        return convo
    }

    func listConversations() throws -> [Conversation] {
        try dbQueue.read { db in
            try Conversation
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    func deleteConversation(id: String) throws {
        _ = try dbQueue.write { db in
            try Conversation.deleteOne(db, key: id)
        }
    }

    // MARK: - Messages

    func appendMessage(
        conversationID: String,
        role: ChatTurn.Role,
        content: String
    ) throws -> Message {
        let now = Date()
        let msg = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            role: role.rawValue,
            content: content,
            createdAt: now
        )
        try dbQueue.write { db in
            try msg.insert(db)
            try db.execute(
                sql: "UPDATE conversations SET updated_at = ? WHERE id = ?",
                arguments: [now, conversationID]
            )
        }
        return msg
    }

    func messages(in conversationID: String) throws -> [Message] {
        try dbQueue.read { db in
            try Message
                .filter(Column("conversation_id") == conversationID)
                .order(Column("created_at"))
                .fetchAll(db)
        }
    }

    // MARK: - Memories (facts the user wants the model to remember)

    func rememberFact(
        _ content: String,
        sourceMessageID: String? = nil,
        embedding: [Float]? = nil,
        pinned: Bool = false
    ) throws -> Memory {
        let mem = Memory(
            id: UUID().uuidString,
            content: content,
            sourceMessageID: sourceMessageID,
            pinned: pinned,
            createdAt: Date()
        )
        try dbQueue.write { db in
            try mem.insert(db)
            if let embedding {
                try Embedding(memoryID: mem.id, vector: embedding).insert(db)
            }
        }
        if let embedding {
            vectorIndex.upsert(id: mem.id, vector: embedding)
        }
        return mem
    }

    func forgetSession(conversationID: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM memories
                WHERE source_message_id IN (
                    SELECT id FROM messages WHERE conversation_id = ?
                )
                """,
                arguments: [conversationID]
            )
        }
        try loadVectorIndex()
    }

    func wipeAllMemory() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM embeddings")
            try db.execute(sql: "DELETE FROM memories")
        }
        vectorIndex.clear()
    }

    // MARK: - Retrieval

    func topMemories(near query: [Float], k: Int = 5) throws -> [Memory] {
        let ids = vectorIndex.topK(query: query, k: k)
        guard !ids.isEmpty else { return [] }
        return try dbQueue.read { db in
            try Memory.filter(ids.contains(Column("id"))).fetchAll(db)
        }
    }

    private func loadVectorIndex() throws {
        let all = try dbQueue.read { db in
            try Embedding.fetchAll(db)
        }
        vectorIndex.clear()
        for e in all {
            vectorIndex.upsert(id: e.memoryID, vector: e.vector)
        }
    }
}
