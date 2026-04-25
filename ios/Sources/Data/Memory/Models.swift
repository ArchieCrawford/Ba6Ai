import Foundation
import CoreData

/// Plain-Swift value types used by the rest of the app. Core Data
/// `NSManagedObject`s are kept inside `MemoryStore` and never leak out
/// — every public API returns these instead. That keeps view models
/// and inference code thread-safe and Sendable-clean.

public struct Conversation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
}

public struct Message: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public var role: ChatTurn.Role
    public var content: String
    public var createdAt: Date

    public var asTurn: ChatTurn { ChatTurn(role: role, content: content) }
}

public struct Memory: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var content: String
    public var sourceMessageID: UUID?
    public var pinned: Bool
    public var createdAt: Date
}

// MARK: - NSManagedObject subclasses
//
// Hand-rolled rather than auto-generated so we can keep the data
// model file together with the rest of the app and not have Xcode
// fight us about codegen settings.

@objc(ConversationEntity)
public final class ConversationEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var messages: NSSet?
}

@objc(MessageEntity)
public final class MessageEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var role: String?
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var conversation: ConversationEntity?
}

@objc(MemoryEntity)
public final class MemoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var sourceMessageID: UUID?
    @NSManaged public var pinned: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var vector: Data?
}

extension ConversationEntity {
    func toValue() -> Conversation {
        Conversation(
            id: id ?? UUID(),
            title: title ?? "New Chat",
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? .distantPast
        )
    }
}

extension MessageEntity {
    func toValue() -> Message {
        Message(
            id: id ?? UUID(),
            conversationID: conversation?.id ?? UUID(),
            role: ChatTurn.Role(rawValue: role ?? "user") ?? .user,
            content: content ?? "",
            createdAt: createdAt ?? .distantPast
        )
    }
}

extension MemoryEntity {
    func toValue() -> Memory {
        Memory(
            id: id ?? UUID(),
            content: content ?? "",
            sourceMessageID: sourceMessageID,
            pinned: pinned,
            createdAt: createdAt ?? .distantPast
        )
    }

    var vectorAsFloats: [Float]? {
        guard let data = vector else { return nil }
        return data.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Float.self))
        }
    }
}

extension Array where Element == Float {
    var asData: Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
