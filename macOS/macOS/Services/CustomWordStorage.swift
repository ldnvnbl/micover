import Foundation

/// 个人词库存储服务
/// 负责词条的持久化存储
@MainActor
final class CustomWordStorage {
    static let shared = CustomWordStorage()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let customWords = "settings.customWords"
    }

    private init() {}

    // MARK: - CRUD Operations

    /// 保存所有自定义词条
    func save(_ words: [CustomWord]) {
        guard let data = try? JSONEncoder().encode(words) else {
            print("❌ Failed to encode custom words")
            return
        }
        userDefaults.set(data, forKey: Keys.customWords)
        print("✅ Saved \(words.count) custom words")
    }

    /// 加载所有自定义词条
    func load() -> [CustomWord] {
        guard let data = userDefaults.data(forKey: Keys.customWords),
              let words = try? JSONDecoder().decode([CustomWord].self, from: data) else {
            return []
        }
        return words
    }

    /// 检查词条是否已存在（忽略大小写）
    func wordExists(_ word: String, excludingId: UUID? = nil) -> Bool {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let words = load()
        return words.contains { existing in
            let existingNormalized = existing.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let excludingId = excludingId, existing.id == excludingId {
                return false
            }
            return existingNormalized == normalizedWord
        }
    }

    /// 获取所有启用的词条（用于发送给 API）
    func getEnabledWords() -> [String] {
        return load()
            .filter { $0.isEnabled }
            .map { $0.word }
    }
}
