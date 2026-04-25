import Foundation
import Accelerate

/// In-memory cosine-similarity index.
///
/// Good enough for the first few tens of thousands of memories. When you
/// need more, swap this out for USearch or HNSWlib — the public surface
/// (`upsert`, `topK`, `clear`) is deliberately narrow so the swap is local.
final class VectorIndex: @unchecked Sendable {
    private struct Entry {
        let id: String
        let vector: [Float]
        let norm: Float
    }

    private var entries: [Entry] = []
    private let lock = NSLock()

    func upsert(id: String, vector: [Float]) {
        let norm = Self.l2(vector)
        let entry = Entry(id: id, vector: vector, norm: norm)
        lock.lock(); defer { lock.unlock() }
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll(keepingCapacity: false)
    }

    func remove(id: String) {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll { $0.id == id }
    }

    func topK(query: [Float], k: Int) -> [String] {
        let qNorm = Self.l2(query)
        guard qNorm > 0 else { return [] }

        lock.lock()
        let snapshot = entries
        lock.unlock()

        let scored: [(String, Float)] = snapshot.compactMap { entry in
            guard entry.vector.count == query.count, entry.norm > 0 else { return nil }
            var dot: Float = 0
            vDSP_dotpr(entry.vector, 1, query, 1, &dot, vDSP_Length(query.count))
            let cosine = dot / (entry.norm * qNorm)
            return (entry.id, cosine)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(k)
            .map(\.0)
    }

    private static func l2(_ v: [Float]) -> Float {
        var result: Float = 0
        vDSP_svesq(v, 1, &result, vDSP_Length(v.count))
        return sqrt(result)
    }
}
