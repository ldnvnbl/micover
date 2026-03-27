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
            return .default
        }
    }
    
    func saveSettings(_ settings: HistorySettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.settings)
            
            // 保存设置后立即清理过期数据
            cleanupExpiredRecords()
        } catch {
            print("❌ Failed to save history settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Record Operations
    
    /// 添加新记录
    func addRecord(_ record: HistoryRecord) {
        let settings = getSettings()
        guard settings.isEnabled else { return }
        
        let weekKey = weekKey(for: record.timestamp)
        var records = loadRecords(forKey: weekKey)
        records.append(record)
        saveRecords(records, forKey: weekKey)

        // 发送通知以便 UI 刷新
        NotificationCenter.default.post(name: .historyRecordAdded, object: nil)
    }
    
    /// 加载所有记录（按时间倒序）- 同步版本
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

    /// 异步分页加载记录（在后台线程执行 JSON 解码）
    nonisolated func loadRecordsAsync(offset: Int = 0, limit: Int = 50) async -> (records: [HistoryRecord], hasMore: Bool) {
        // 在主线程获取必要的数据
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("history.") && $0.contains("-W") }

        // 收集所有周的数据（在主线程读取 UserDefaults）
        var allData: [(key: String, data: Data)] = []
        for key in allKeys {
            if let data = userDefaults.data(forKey: key) {
                allData.append((key, data))
            }
        }

        // 在后台线程执行 JSON 解码和排序
        return await Task.detached(priority: .userInitiated) {
            var allRecords: [HistoryRecord] = []
            let decoder = JSONDecoder()

            for (key, data) in allData {
                do {
                    let records = try decoder.decode([HistoryRecord].self, from: data)
                    allRecords.append(contentsOf: records)
                } catch {
                }
            }

            // 排序
            let sortedRecords = allRecords.sorted { $0.timestamp > $1.timestamp }

            // 分页
            let totalCount = sortedRecords.count
            let endIndex = min(offset + limit, totalCount)
            let hasMore = endIndex < totalCount

            let pageRecords = offset < totalCount ? Array(sortedRecords[offset..<endIndex]) : []
            return (pageRecords, hasMore)
        }.value
    }

    /// 异步获取记录总数
    nonisolated func getRecordCountAsync() async -> Int {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("history.") && $0.contains("-W") }

        var allData: [Data] = []
        for key in allKeys {
            if let data = userDefaults.data(forKey: key) {
                allData.append(data)
            }
        }

        return await Task.detached(priority: .userInitiated) {
            var count = 0
            let decoder = JSONDecoder()

            for data in allData {
                if let records = try? decoder.decode([HistoryRecord].self, from: data) {
                    count += records.count
                }
            }

            return count
        }.value
    }

    /// 按周增量加载记录（只加载必要的周数据）
    /// - Parameters:
    ///   - loadedWeekKeys: 已加载的周 key 列表（用于继续加载）
    ///   - limit: 需要加载的记录数
    /// - Returns: (records, hasMore, loadedWeekKeys)
    nonisolated func loadRecordsByWeekAsync(
        loadedWeekKeys: [String] = [],
        limit: Int = 50
    ) async -> (records: [HistoryRecord], hasMore: Bool, loadedWeekKeys: [String]) {
        let userDefaults = UserDefaults.standard

        // 1. 获取所有周 key 并按时间倒序排序
        let allWeekKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("history.") && $0.contains("-W") }
            .sorted { $0 > $1 }  // 倒序：2026-W03 > 2026-W02 > 2026-W01

        // 2. 找出未加载的周（保持倒序）
        let unloadedKeys = allWeekKeys.filter { !loadedWeekKeys.contains($0) }

        // 3. 逐周读取数据
        var weekDataList: [(key: String, data: Data)] = []
        for weekKey in unloadedKeys {
            if let data = userDefaults.data(forKey: weekKey) {
                weekDataList.append((weekKey, data))
            }
        }

        // 4. 在后台线程执行 JSON 解码
        return await Task.detached(priority: .userInitiated) {
            var records: [HistoryRecord] = []
            var newLoadedKeys = loadedWeekKeys
            let decoder = JSONDecoder()

            for (weekKey, data) in weekDataList {
                if let weekRecords = try? decoder.decode([HistoryRecord].self, from: data) {
                    records.append(contentsOf: weekRecords)
                    newLoadedKeys.append(weekKey)
                }

                // 如果已经超过 limit，停止加载更多周
                if records.count >= limit {
                    break
                }
            }

            // 5. 排序（只对本次加载的记录排序）
            records.sort { $0.timestamp > $1.timestamp }

            // 6. 判断是否还有更多
            let hasMore = newLoadedKeys.count < allWeekKeys.count || records.count > limit

            // 7. 返回结果（如果超过 limit，只返回 limit 条）
            let resultRecords = records.count > limit ? Array(records.prefix(limit)) : records

            return (resultRecords, hasMore, newLoadedKeys)
        }.value
    }

    /// 分页加载记录（同步版本，保留兼容性）
    func loadRecords(offset: Int = 0, limit: Int = 50) -> [HistoryRecord] {
        let allKeys = getAllWeekKeys()
        var allRecords: [HistoryRecord] = []

        // 收集所有记录
        for key in allKeys {
            let records = loadRecords(forKey: key)
            allRecords.append(contentsOf: records)
        }

        // 排序并分页
        let sortedRecords = allRecords.sorted { $0.timestamp > $1.timestamp }
        let endIndex = min(offset + limit, sortedRecords.count)

        return offset < sortedRecords.count ? Array(sortedRecords[offset..<endIndex]) : []
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
    
    /// 更新单条记录（例如存储 correctedText）
    func updateRecord(_ updatedRecord: HistoryRecord) {
        let wk = weekKey(for: updatedRecord.timestamp)
        var records = loadRecords(forKey: wk)
        guard let index = records.firstIndex(where: { $0.id == updatedRecord.id }) else { return }
        records[index] = updatedRecord
        saveRecords(records, forKey: wk)
    }

    /// 批量更新记录，按周分组减少编解码次数
    func updateRecords(_ updatedRecords: [HistoryRecord]) {
        let grouped = Dictionary(grouping: updatedRecords) { record in
            weekKey(for: record.timestamp)
        }

        for (wk, updates) in grouped {
            var records = loadRecords(forKey: wk)
            for update in updates {
                if let index = records.firstIndex(where: { $0.id == update.id }) {
                    records[index] = update
                }
            }
            saveRecords(records, forKey: wk)
        }

        NotificationCenter.default.post(name: .historyRecordsUpdated, object: nil)
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
        
    }
    
    // MARK: - Export
    
    /// 导出历史记录为 JSON 文件
    func exportToJSON() -> URL? {
        let records = loadAllRecords()
        
        guard !records.isEmpty else { return nil }
        
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
            return []
        }
    }
    
    private func saveRecords(_ records: [HistoryRecord], forKey key: String) {
        do {
            let data = try JSONEncoder().encode(records)
            userDefaults.set(data, forKey: key)
        } catch {
            print("❌ Failed to save history records: \(error.localizedDescription)")
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
    /// 历史记录批量更新通知
    static let historyRecordsUpdated = Notification.Name("historyRecordsUpdated")
}
