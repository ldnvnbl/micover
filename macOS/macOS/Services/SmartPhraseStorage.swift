import Foundation
import Shared

/// 智能短语存储服务 - 使用 UserDefaults 存储
@MainActor
final class SmartPhraseStorage {
    static let shared = SmartPhraseStorage()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let smartPhrases = "settings.smartPhrases"
        static let triggerCounts = "settings.smartPhrases.triggerCounts"
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 保存所有智能短语
    func save(_ phrases: [SmartPhrase]) {
        do {
            let data = try JSONEncoder().encode(phrases)
            userDefaults.set(data, forKey: Keys.smartPhrases)
            print("✅ Smart phrases saved: \(phrases.count) items")
        } catch {
            print("❌ Failed to save smart phrases: \(error)")
        }
    }
    
    /// 加载所有智能短语
    func load() -> [SmartPhrase] {
        guard let data = userDefaults.data(forKey: Keys.smartPhrases) else {
            print("📭 No saved smart phrases found")
            return []
        }
        
        do {
            let phrases = try JSONDecoder().decode([SmartPhrase].self, from: data)
            print("✅ Smart phrases loaded: \(phrases.count) items")
            return phrases
        } catch {
            print("❌ Failed to load smart phrases: \(error)")
            return []
        }
    }
    
    /// 检查触发词是否已存在
    /// - Parameters:
    ///   - trigger: 要检查的触发词
    ///   - excludingId: 排除的 ID（用于编辑时排除自身）
    /// - Returns: 是否存在
    func triggerExists(_ trigger: String, excludingId: UUID? = nil) -> Bool {
        let phrases = load()
        let normalizedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        return phrases.contains { phrase in
            if let excludingId, phrase.id == excludingId {
                return false
            }
            return phrase.trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTrigger
        }
    }
    
    /// 清空所有智能短语
    func clear() {
        userDefaults.removeObject(forKey: Keys.smartPhrases)
        print("🗑️ Smart phrases cleared")
    }
    
    // MARK: - Trigger Count Statistics
    
    /// 增加指定短语的今日触发次数
    func incrementTriggerCount(for phraseId: UUID) {
        var allCounts = loadTriggerCounts()
        let todayKey = todayDateKey()
        let phraseKey = phraseId.uuidString
        
        // 获取或创建该短语的计数字典
        var phraseCounts = allCounts[phraseKey] ?? [:]
        phraseCounts[todayKey] = (phraseCounts[todayKey] ?? 0) + 1
        allCounts[phraseKey] = phraseCounts
        
        // 清理旧数据并保存
        allCounts = cleanupOldCounts(allCounts)
        saveTriggerCounts(allCounts)
    }
    
    /// 获取指定短语的今日触发次数
    func getTodayTriggerCount(for phraseId: UUID) -> Int {
        let allCounts = loadTriggerCounts()
        let todayKey = todayDateKey()
        let phraseKey = phraseId.uuidString
        
        return allCounts[phraseKey]?[todayKey] ?? 0
    }
    
    // MARK: - Private Helpers
    
    private func todayDateKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    /// 存储结构: [phraseId: [dateKey: count]]
    private func loadTriggerCounts() -> [String: [String: Int]] {
        guard let data = userDefaults.data(forKey: Keys.triggerCounts) else {
            return [:]
        }
        
        do {
            return try JSONDecoder().decode([String: [String: Int]].self, from: data)
        } catch {
            print("❌ Failed to load trigger counts: \(error)")
            return [:]
        }
    }
    
    private func saveTriggerCounts(_ counts: [String: [String: Int]]) {
        do {
            let data = try JSONEncoder().encode(counts)
            userDefaults.set(data, forKey: Keys.triggerCounts)
        } catch {
            print("❌ Failed to save trigger counts: \(error)")
        }
    }
    
    /// 清理 90 天前的数据
    private func cleanupOldCounts(_ counts: [String: [String: Int]]) -> [String: [String: Int]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) else {
            return counts
        }
        let cutoffKey = formatter.string(from: cutoffDate)
        
        var cleaned: [String: [String: Int]] = [:]
        for (phraseId, dateCounts) in counts {
            let filteredCounts = dateCounts.filter { $0.key >= cutoffKey }
            if !filteredCounts.isEmpty {
                cleaned[phraseId] = filteredCounts
            }
        }
        return cleaned
    }
}
