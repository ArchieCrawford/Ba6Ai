import Foundation
import GRDB

struct Conversation: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "conversations"

    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Message: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "messages"

    var id: String
    var conversationID: String
    var role: String
    var content: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
    }

    var asTurn: ChatTurn? {
        guard let r = ChatTurn.Role(rawValue: role) else { return nil }
        return ChatTurn(role: r, content: content)
    }
}

struct Memory: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "memories"

    var id: String
    var content: String
    var sourceMessageID: String?
    var pinned: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case sourceMessageID = "source_message_id"
        case pinned
        case createdAt = "created_at"
    }
}

struct Embedding: FetchableRecord, PersistableRecord {
    static let databaseTableName = "embeddings"

    var memoryID: String
    var vector: [Float]

    init(memoryID: String, vector: [Float]) {
        self.memoryID = memoryID
        self.vector = vector
    }

    init(row: Row) throws {
        memoryID = row["memory_id"]
        let data: Data = row["vector"]
        vector = data.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Float.self))
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container["memory_id"] = memoryID
        container["dim"] = vector.count
        container["vector"] = vector.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
    }
}
