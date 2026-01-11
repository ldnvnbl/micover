import Foundation
import AppKit

/// 历史记录存储服务 - 使用 UserDefaults，以周为 Key 存储
@MainActor
final class HistoryStorage {
    static let shared = HistoryStorage()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let settings = "history.settings"
        static func weekKey(year: Int, week: Int) -> String {
            return String(format: "history.%04d-W%02d", year, week)
        }
    }
    
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        return cal
    }()
    
    private init() {
        // 启动时清理过期数据
        cleanupExpiredRecords()
    }
    
    // MARK: - Settings
    
    func getSettings() -> HistorySettings {
        guard let data = userDefaults.data(forKey: Keys.settings) else {
            return .default
        }
        
        do {
            return try JSONDecoder().decode(HistorySettings.self, from: data)
        } catch {
            print("❌ Failed to decode history settings: \(error)")
            return .default
        }
    }
    
    func saveSettings(_ settings: HistorySettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.settings)
            print("✅ History settings saved")
            
            // 保存设置后立即清理过期数据
            cleanupExpiredRecords()
        } catch {
            print("❌ Failed to save history settings: \(error)")
        }
    }
    
    // MARK: - Record Operations
    
    /// 添加新记录
    func addRecord(_ record: HistoryRecord) {
        let settings = getSettings()
        guard settings.isEnabled else {
            print("📝 History is disabled, skipping record")
            return
        }
        
        let weekKey = weekKey(for: record.timestamp)
        var records = loadRecords(forKey: weekKey)
        records.append(record)
        saveRecords(records, forKey: weekKey)
        
        print("✅ History record added: \(record.transcribedText.prefix(30))...")
        
        // 发送通知以便 UI 刷新
        NotificationCenter.default.post(name: .historyRecordAdded, object: nil)
    }
    
    /// 加载所有记录（按时间倒序）
    func loadAllRecords() -> [HistoryRecord] {
        let allKeys = getAllWeekKeys()
        var allRecords: [HistoryRecord] = []
        
        for key in allKeys {
            let records = loadRecords(forKey: key)
            allRecords.append(contentsOf: records)
        }
        
        // 按时间倒序排列
        return allRecords.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// 删除单条记录
    func deleteRecord(id: UUID) {
        let allKeys = getAllWeekKeys()
        
        for key in allKeys {
            var records = loadRecords(forKey: key)
            if let index = records.firstIndex(where: { $0.id == id }) {
                records.remove(at: index)
                
                if records.isEmpty {
                    userDefaults.removeObject(forKey: key)
                } else {
                    saveRecords(records, forKey: key)
                }
                
                print("✅ History record deleted")
                return
            }
        }
    }
    
    /// 清空所有历史记录
    func clearAllRecords() {
        let allKeys = getAllWeekKeys()
        
        for key in allKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        print("🗑️ All history records cleared")
    }
    
    /// 清理过期记录
    func cleanupExpiredRecords() {
        let settings = getSettings()
        
        // 永久保留时不清理
        guard settings.retentionPeriod != .forever else { return }
        
        let retentionDays = settings.retentionPeriod.rawValue
        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }
        
        let allKeys = getAllWeekKeys()
        var deletedCount = 0
        
        for key in allKeys {
            // 解析周 Key 获取该周的结束日期
            if let weekEndDate = parseWeekEndDate(from: key), weekEndDate < cutoffDate {
                userDefaults.removeObject(forKey: key)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            print("🧹 Cleaned up \(deletedCount) expired history weeks")
        }
    }
    
    /// 获取记录总数
    func getRecordCount() -> Int {
        let allKeys = getAllWeekKeys()
        var count = 0
        
        for key in allKeys {
            let records = loadRecords(forKey: key)
            count += records.count
        }
        
        return count
    }
    
    // MARK: - Export
    
    /// 导出历史记录为 JSON 文件
    func exportToJSON() -> URL? {
        let records = loadAllRecords()
        
        guard !records.isEmpty else {
            print("⚠️ No records to export")
            return nil
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(records)
            
            // 创建临时文件
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "MicOver_History_\(dateString).json"
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            
            print("✅ History exported to: \(tempURL.path)")
            return tempURL
        } catch {
            print("❌ Failed to export history: \(error)")
            return nil
        }
    }
    
    /// 显示导出保存对话框
    func exportWithSavePanel() {
        guard let sourceURL = exportToJSON() else {
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = sourceURL.lastPathComponent
        savePanel.title = "导出历史记录"
        savePanel.message = "选择保存位置"
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // 如果目标文件已存在，先删除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    print("✅ History exported to: \(destinationURL.path)")
                } catch {
                    print("❌ Failed to save exported file: \(error)")
                }
            }
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }
    
    // MARK: - Private Helpers
    
    private func weekKey(for date: Date) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return Keys.weekKey(year: year, week: week)
    }
    
    private func loadRecords(forKey key: String) -> [HistoryRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([HistoryRecord].self, from: data)
        } catch {
            print("❌ Failed to decode history records for \(key): \(error)")
            return []
        }
    }
    
    private func saveRecords(_ records: [HistoryRecord], forKey key: String) {
        do {
            let data = try JSONEncoder().encode(records)
            userDefaults.set(data, forKey: key)
        } catch {
            print("❌ Failed to save history records: \(error)")
        }
    }
    
    private func getAllWeekKeys() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys.filter { $0.hasPrefix("history.") && $0.contains("-W") }
    }
    
    /// 解析周 Key 获取该周的结束日期（周日）
    private func parseWeekEndDate(from key: String) -> Date? {
        // Key 格式: "history.2024-W01"
        // 提取年份和周数
        let components = key.replacingOccurrences(of: "history.", with: "").split(separator: "-W")
        guard components.count == 2,
              let year = Int(components[0]),
              let week = Int(components[1]) else {
            return nil
        }
        
        // 获取该周的周一
        var dateComponents = DateComponents()
        dateComponents.yearForWeekOfYear = year
        dateComponents.weekOfYear = week
        dateComponents.weekday = 2 // Monday
        
        guard let monday = calendar.date(from: dateComponents) else {
            return nil
        }
        
        // 返回周日（周一 + 6 天）
        return calendar.date(byAdding: .day, value: 6, to: monday)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 历史记录新增通知
    static let historyRecordAdded = Notification.Name("historyRecordAdded")
}
