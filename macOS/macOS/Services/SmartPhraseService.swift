import AppKit
import Foundation
import Shared

/// 智能短语服务 - 负责匹配与执行
@Observable
@MainActor
final class SmartPhraseService {
    static let shared = SmartPhraseService()
    
    private(set) var phrases: [SmartPhrase] = []
    
    /// AppState 引用，用于触发后刷新统计
    weak var appState: AppState?
    
    /// 文本输入服务（通过依赖注入）
    private var textInputService: TextInputService?
    
    private init() {
        loadPhrases()
    }
    
    /// 配置依赖
    func configure(appState: AppState, textInputService: TextInputService) {
        self.appState = appState
        self.textInputService = textInputService
    }
    
    // MARK: - CRUD Operations
    
    /// 添加智能短语
    /// - Returns: 是否添加成功
    func addPhrase(_ phrase: SmartPhrase) -> Bool {
        // 检查触发词唯一性
        if SmartPhraseStorage.shared.triggerExists(phrase.trigger) {
            print("⚠️ Trigger already exists: \(phrase.trigger)")
            return false
        }
        
        phrases.append(phrase)
        savePhrases()
        print("✅ Smart phrase added: \(phrase.trigger)")
        return true
    }
    
    /// 更新智能短语
    func updatePhrase(_ phrase: SmartPhrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else {
            print("⚠️ Phrase not found for update: \(phrase.id)")
            return
        }
        
        phrases[index] = phrase
        savePhrases()
        print("✅ Smart phrase updated: \(phrase.trigger)")
    }
    
    /// 删除智能短语
    func deletePhrase(_ phrase: SmartPhrase) {
        phrases.removeAll { $0.id == phrase.id }
        savePhrases()
        print("🗑️ Smart phrase deleted: \(phrase.trigger)")
    }
    
    /// 切换启用状态
    func toggleEnabled(_ phrase: SmartPhrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        phrases[index].isEnabled.toggle()
        savePhrases()
    }
    
    /// 加载短语
    func loadPhrases() {
        phrases = SmartPhraseStorage.shared.load()
    }
    
    /// 保存短语
    private func savePhrases() {
        SmartPhraseStorage.shared.save(phrases)
    }
    
    // MARK: - Matching & Execution
    
    /// 智能短语执行结果
    struct ExecutionResult {
        let phrase: SmartPhrase
        let actionType: SmartPhraseActionType
        let actionDetail: String  // 应用名称或文本内容
    }
    
    /// 尝试匹配并执行智能短语
    /// - Parameter text: 识别结果文本
    /// - Returns: 执行结果，nil 表示未匹配
    func tryExecute(text: String) async -> ExecutionResult? {
        let normalized = normalizeForMatching(text)
        
        // 精确匹配（忽略大小写、首尾空格和标点）
        guard let phrase = phrases.first(where: {
            $0.isEnabled && normalizeForMatching($0.trigger) == normalized
        }) else {
            return nil
        }
        
        print("🎯 Smart phrase matched: '\(phrase.trigger)' -> \(phrase.actionType.displayName)")
        
        do {
            try await executeAction(phrase)
            
            // 统计：增加总触发次数和单个短语触发次数
            recordTrigger(for: phrase)
            
            return ExecutionResult(
                phrase: phrase,
                actionType: phrase.actionType,
                actionDetail: phrase.actionDisplayName
            )
        } catch {
            print("❌ Smart phrase execution failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 记录触发统计
    private func recordTrigger(for phrase: SmartPhrase) {
        // 增加全局统计
        StatsStorage.shared.incrementSmartPhraseCount()
        
        // 增加单个短语的触发次数
        SmartPhraseStorage.shared.incrementTriggerCount(for: phrase.id)
        
        // 刷新 AppState 以更新 UI
        appState?.loadTodayStats()
        
        print("📊 Trigger recorded for phrase: \(phrase.trigger)")
    }
    
    /// 标准化文本用于匹配：去除首尾空格和标点，转小写
    private func normalizeForMatching(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 去除首尾标点符号
        let punctuationSet = CharacterSet.punctuationCharacters.union(.symbols)
        while let first = result.unicodeScalars.first, punctuationSet.contains(first) {
            result.removeFirst()
        }
        while let last = result.unicodeScalars.last, punctuationSet.contains(last) {
            result.removeLast()
        }
        
        return result.lowercased().trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Action Execution
    
    private func executeAction(_ phrase: SmartPhrase) async throws {
        switch phrase.actionType {
        case .openApp:
            try openApp(bundleID: phrase.actionPayload, name: phrase.actionDisplayName)
        case .typeText:
            typeText(phrase.actionPayload)
        case .openURL:
            try openURL(phrase.actionPayload)
        }
    }
    
    private func typeText(_ text: String) {
        guard let textInputService else {
            print("❌ TextInputService not configured")
            return
        }
        textInputService.pasteText(text)
        print("✅ Text typed: \(text.prefix(30))...")
    }
    
    private func openApp(bundleID: String, name: String) throws {
        let workspace = NSWorkspace.shared
        
        // 使用 Bundle ID 打开应用
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            workspace.openApplication(at: url, configuration: configuration) { app, error in
                if let error {
                    print("❌ Failed to open app: \(error.localizedDescription)")
                } else {
                    print("✅ App opened: \(name)")
                }
            }
            return
        }
        
        // 备用方案：尝试用名称打开
        if workspace.launchApplication(name) {
            print("✅ App launched by name: \(name)")
            return
        }
        
        throw SmartPhraseError.appNotFound(name)
    }
    
    private func openURL(_ urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw SmartPhraseError.executionFailed("无效的 URL: \(urlString)")
        }
        
        let success = NSWorkspace.shared.open(url)
        if success {
            print("✅ URL opened: \(urlString)")
        } else {
            throw SmartPhraseError.executionFailed("无法打开 URL: \(urlString)")
        }
    }
    
    // MARK: - App Discovery
    
    /// 获取已安装的应用列表
    nonisolated func getInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        var seenBundleIDs: Set<String> = []
        
        // 搜索路径
        let searchPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        
        let fileManager = FileManager.default
        
        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: searchPath) else {
                continue
            }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = URL(fileURLWithPath: searchPath).appendingPathComponent(item)
                
                if let appInfo = getAppInfo(at: appPath), !seenBundleIDs.contains(appInfo.bundleID) {
                    apps.append(appInfo)
                    seenBundleIDs.insert(appInfo.bundleID)
                }
            }
        }
        
        // 按名称排序
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private nonisolated func getAppInfo(at url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return nil
        }
        
        // 获取应用名称
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        return AppInfo(
            id: bundleID,
            name: name,
            bundleID: bundleID,
            path: url
        )
    }
}
