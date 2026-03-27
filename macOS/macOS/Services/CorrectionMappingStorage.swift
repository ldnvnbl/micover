import Foundation

/// 纠错映射条目（错误写法 → 正确写法）
struct CorrectionMapping: Codable, Identifiable {
    let id: UUID
    let wrongText: String
    let correctText: String
    let createdAt: Date

    init(id: UUID = UUID(), wrongText: String, correctText: String, createdAt: Date = Date()) {
        self.id = id
        self.wrongText = wrongText
        self.correctText = correctText
        self.createdAt = createdAt
    }
}

/// 纠错映射存储 — 持久化 A→B 纠错对照表
@MainActor
final class CorrectionMappingStorage {
    static let shared = CorrectionMappingStorage()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let mappings = "ai.correctionMappings"
    }

    private init() {}

    var mappings: [CorrectionMapping] {
        guard let data = defaults.data(forKey: Keys.mappings),
              let decoded = try? JSONDecoder().decode([CorrectionMapping].self, from: data) else {
            return []
        }
        return decoded
    }

    func save(_ mappings: [CorrectionMapping]) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Keys.mappings)
    }

    func addMappings(_ newMappings: [CorrectionMapping]) {
        var current = mappings
        for mapping in newMappings {
            // 相同错误写法 → 更新为最新的正确写法
            if let index = current.firstIndex(where: { $0.wrongText == mapping.wrongText }) {
                current[index] = mapping
            } else {
                current.append(mapping)
            }
        }
        save(current)
    }

    func updateMapping(_ mapping: CorrectionMapping) {
        var current = mappings
        guard let index = current.firstIndex(where: { $0.id == mapping.id }) else { return }
        current[index] = mapping
        save(current)
    }

    func removeMapping(id: UUID) {
        var current = mappings
        current.removeAll { $0.id == id }
        save(current)
    }
}
