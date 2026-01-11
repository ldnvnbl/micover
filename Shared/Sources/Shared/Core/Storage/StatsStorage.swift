import Foundation

/// 每日统计数据
public struct DailyStats: Codable, Sendable {
    public let date: String  // "yyyy-MM-dd" 格式
    public var recordingCount: Int
    public var totalRecordingDuration: Int  // 秒
    public var totalTranscribedWords: Int
    public var smartPhraseTriggeredCount: Int  // 智能短语触发次数
    
    public init(date: String, recordingCount: Int = 0, totalRecordingDuration: Int = 0, totalTranscribedWords: Int = 0, smartPhraseTriggeredCount: Int = 0) {
        self.date = date
        self.recordingCount = recordingCount
        self.totalRecordingDuration = totalRecordingDuration
        self.totalTranscribedWords = totalTranscribedWords
        self.smartPhraseTriggeredCount = smartPhraseTriggeredCount
    }
    
    /// 创建今天的空统计
    public static func today() -> DailyStats {
        DailyStats(date: dateKey(for: Date()))
    }
    
    /// 生成日期 key
    public static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

/// 统计数据存储服务
@MainActor
public final class StatsStorage: Sendable {
    public static let shared = StatsStorage()
    
    private let userDefaults: UserDefaults
    private let statsKey = "com.micover.dailyStats"
    private let maxHistoryDays = 90
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public API
    
    /// 获取今日统计
    public func getTodayStats() -> DailyStats {
        let todayKey = DailyStats.dateKey(for: Date())
        let allStats = loadAllStats()
        return allStats[todayKey] ?? DailyStats.today()
    }
    
    /// 获取指定日期的统计
    public func getStats(for date: Date) -> DailyStats? {
        let dateKey = DailyStats.dateKey(for: date)
        let allStats = loadAllStats()
        return allStats[dateKey]
    }
    
    /// 获取所有历史统计
    public func getAllStats() -> [String: DailyStats] {
        loadAllStats()
    }
    
    /// 增加录音次数
    public func incrementRecordingCount() {
        var stats = getTodayStats()
        stats.recordingCount += 1
        saveTodayStats(stats)
    }
    
    /// 增加录音时长
    public func addRecordingDuration(_ seconds: Int) {
        var stats = getTodayStats()
        stats.totalRecordingDuration += seconds
        saveTodayStats(stats)
    }
    
    /// 增加转写字数
    public func addTranscribedWords(_ count: Int) {
        var stats = getTodayStats()
        stats.totalTranscribedWords += count
        saveTodayStats(stats)
    }
    
    /// 增加智能短语触发次数
    public func incrementSmartPhraseCount() {
        var stats = getTodayStats()
        stats.smartPhraseTriggeredCount += 1
        saveTodayStats(stats)
    }
    
    /// 更新今日统计（一次性更新多个字段）
    public func updateTodayStats(
        recordingDuration: Int? = nil,
        transcribedWords: Int? = nil
    ) {
        var stats = getTodayStats()
        
        if let duration = recordingDuration {
            stats.totalRecordingDuration += duration
        }
        
        if let words = transcribedWords {
            stats.totalTranscribedWords += words
        }
        
        saveTodayStats(stats)
    }
    
    // MARK: - Private
    
    private func loadAllStats() -> [String: DailyStats] {
        guard let data = userDefaults.data(forKey: statsKey) else {
            return [:]
        }
        
        do {
            let stats = try JSONDecoder().decode([String: DailyStats].self, from: data)
            return stats
        } catch {
            print("❌ Failed to decode stats: \(error)")
            return [:]
        }
    }
    
    private func saveTodayStats(_ stats: DailyStats) {
        var allStats = loadAllStats()
        allStats[stats.date] = stats
        
        // 清理过期数据（保留最近90天）
        allStats = cleanupOldStats(allStats)
        
        saveAllStats(allStats)
    }
    
    private func saveAllStats(_ stats: [String: DailyStats]) {
        do {
            let data = try JSONEncoder().encode(stats)
            userDefaults.set(data, forKey: statsKey)
        } catch {
            print("❌ Failed to encode stats: \(error)")
        }
    }
    
    private func cleanupOldStats(_ stats: [String: DailyStats]) -> [String: DailyStats] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxHistoryDays, to: Date()) ?? Date()
        let cutoffKey = DailyStats.dateKey(for: cutoffDate)
        
        return stats.filter { $0.key >= cutoffKey }
    }
}

// MARK: - 字数统计工具

public enum WordCounter {
    /// 智能混合字数统计
    /// - 中文：按字符数统计
    /// - 英文：按单词数统计
    /// - 数字：按连续数字块统计（一串数字算1个）
    public static func countWords(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        
        var count = 0
        
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { substring, _, _, _ in
            guard let word = substring, !word.isEmpty else { return }
            
            // 检查单词类型
            let firstScalar = word.unicodeScalars.first!
            
            if isChinese(firstScalar) {
                // 中文：按字符数统计
                count += word.count
            } else {
                // 英文/数字/其他：按单词数统计（1个单词=1）
                count += 1
            }
        }
        
        return count
    }
    
    /// 检查是否为中文字符
    private static func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        // CJK Unified Ideographs
        let cjkUnified: ClosedRange<UInt32> = 0x4E00...0x9FFF
        // CJK Unified Ideographs Extension A
        let cjkExtA: ClosedRange<UInt32> = 0x3400...0x4DBF
        // CJK Unified Ideographs Extension B
        let cjkExtB: ClosedRange<UInt32> = 0x20000...0x2A6DF
        // CJK Compatibility Ideographs
        let cjkCompat: ClosedRange<UInt32> = 0xF900...0xFAFF
        
        let value = scalar.value
        return cjkUnified.contains(value) ||
               cjkExtA.contains(value) ||
               cjkExtB.contains(value) ||
               cjkCompat.contains(value)
    }
}
