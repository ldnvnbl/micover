import AppKit
import Foundation
import Shared

/// ASR 上下文提供者 — 组装 hotwords + dialog context
/// 所有方法标记 nonisolated，直接从 UserDefaults 读取，供闭包安全调用
@MainActor
final class ASRContextProvider {
    static let shared = ASRContextProvider()

    /// Token 预算：dialog_ctx 上限 800，留余量给其他上下文
    private static let maxContextTokenEstimate = 700

    private init() {}

    /// 构建完整的 corpus context（nonisolated，可在任意线程调用）
    nonisolated func buildCorpusContext() -> CorpusContext? {
        let hotwords = loadHotwords()
        let contextEntries = buildDialogContext()

        guard hotwords != nil || contextEntries != nil else { return nil }

        return CorpusContext(
            hotwords: hotwords,
            contextType: contextEntries != nil ? "dialog_ctx" : nil,
            contextData: contextEntries
        )
    }

    // MARK: - Hotwords

    /// 从 UserDefaults 加载启用的热词（含词库 + 纠错映射中的正确写法）
    nonisolated private func loadHotwords() -> [HotwordEntry]? {
        var hotwords: [HotwordEntry] = []

        // 词库
        if let data = UserDefaults.standard.data(forKey: "settings.customWords"),
           let words = try? JSONDecoder().decode([CustomWord].self, from: data) {
            let enabled = words.filter { $0.isEnabled }
            hotwords.append(contentsOf: enabled.map { HotwordEntry(word: $0.word) })
        }

        // 纠错映射的正确写法也作为热词，帮助 ASR 更准确识别
        if let data = UserDefaults.standard.data(forKey: "ai.correctionMappings"),
           let mappings = try? JSONDecoder().decode([CorrectionMapping].self, from: data) {
            let mappingWords = Set(mappings.map { $0.correctText })
            let existingWords = Set(hotwords.map { $0.word })
            for word in mappingWords where !existingWords.contains(word) {
                hotwords.append(HotwordEntry(word: word))
            }
        }

        return hotwords.isEmpty ? nil : hotwords
    }

    // MARK: - Dialog Context

    /// 组合三种上下文数据源
    nonisolated private func buildDialogContext() -> [ContextDataEntry]? {
        var entries: [ContextDataEntry] = []
        var usedTokens = 0

        // 1. 当前前台应用
        let appEntry = frontmostAppEntry()
        if let appEntry {
            let tokens = estimateTokens(appEntry.text ?? "")
            if usedTokens + tokens <= Self.maxContextTokenEstimate {
                entries.append(appEntry)
                usedTokens += tokens
            }
        }

        // 2. 智能短语触发词
        let phraseEntry = smartPhrasesEntry()
        if let phraseEntry {
            let tokens = estimateTokens(phraseEntry.text ?? "")
            if usedTokens + tokens <= Self.maxContextTokenEstimate {
                entries.append(phraseEntry)
                usedTokens += tokens
            }
        }

        // 3. 纠错映射提示
        let mappingEntry = correctionMappingsEntry()
        if let mappingEntry {
            let tokens = estimateTokens(mappingEntry.text ?? "")
            if usedTokens + tokens <= Self.maxContextTokenEstimate {
                entries.append(mappingEntry)
                usedTokens += tokens
            }
        }

        // 4. 最近转录历史（按时间从旧到新）
        let historyEntries = recentTranscriptionEntries(remainingTokens: Self.maxContextTokenEstimate - usedTokens)
        entries.append(contentsOf: historyEntries)

        return entries.isEmpty ? nil : entries
    }

    // MARK: - 2a. 当前前台应用

    nonisolated private func frontmostAppEntry() -> ContextDataEntry? {
        // NSWorkspace.shared 需要在主线程访问
        let appName: String? = if Thread.isMainThread {
            NSWorkspace.shared.frontmostApplication?.localizedName
        } else {
            DispatchQueue.main.sync {
                NSWorkspace.shared.frontmostApplication?.localizedName
            }
        }

        guard let name = appName, !name.isEmpty else { return nil }
        return ContextDataEntry(text: "用户正在使用\(name)输入文字")
    }

    // MARK: - 2b. 智能短语触发词

    nonisolated private func smartPhrasesEntry() -> ContextDataEntry? {
        guard let data = UserDefaults.standard.data(forKey: "settings.smartPhrases"),
              let phrases = try? JSONDecoder().decode([SmartPhrase].self, from: data) else {
            return nil
        }

        let enabledTriggers = phrases.filter { $0.isEnabled }.map { $0.trigger }
        guard !enabledTriggers.isEmpty else { return nil }

        let joined = enabledTriggers.joined(separator: "、")
        return ContextDataEntry(text: "用户可能会说以下指令：\(joined)")
    }

    // MARK: - 2c. 纠错映射

    nonisolated private func correctionMappingsEntry() -> ContextDataEntry? {
        guard let data = UserDefaults.standard.data(forKey: "ai.correctionMappings"),
              let mappings = try? JSONDecoder().decode([CorrectionMapping].self, from: data),
              !mappings.isEmpty else {
            return nil
        }

        let pairs = mappings.map { "\($0.wrongText)应为\($0.correctText)" }.joined(separator: "，")
        return ContextDataEntry(text: "常见纠错：\(pairs)")
    }

    // MARK: - 2d. 最近转录历史

    nonisolated private func recentTranscriptionEntries(remainingTokens: Int) -> [ContextDataEntry] {
        let userDefaults = UserDefaults.standard

        // 获取所有 history week keys，按时间倒序
        let weekKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("history.") && $0.contains("-W") }
            .sorted { $0 > $1 }

        var records: [HistoryRecord] = []
        let decoder = JSONDecoder()

        // 逐周加载，收集最近的 textInput 记录
        for weekKey in weekKeys {
            guard let data = userDefaults.data(forKey: weekKey),
                  let weekRecords = try? decoder.decode([HistoryRecord].self, from: data) else {
                continue
            }

            let textInputRecords = weekRecords.filter { $0.actionType == .textInput && !$0.displayText.isEmpty }
            records.append(contentsOf: textInputRecords)

            // 收集足够多就停止（最多取 20 条候选）
            if records.count >= 20 {
                break
            }
        }

        // 按时间倒序排列，取最近的
        records.sort { $0.timestamp > $1.timestamp }

        // 从最近的开始，在 token 预算内尽可能多地取
        var selected: [ContextDataEntry] = []
        var usedTokens = 0

        for record in records {
            let tokens = estimateTokens(record.displayText)
            if usedTokens + tokens > remainingTokens {
                break
            }
            selected.append(ContextDataEntry(text: record.displayText))
            usedTokens += tokens
        }

        // 反转为从旧到新的顺序
        selected.reverse()
        return selected
    }

    // MARK: - Token 估算

    /// 简单估算 token 数（中文约 1 字 = 1-2 token，英文约 4 字符 = 1 token）
    nonisolated private func estimateTokens(_ text: String) -> Int {
        var tokens = 0
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // CJK 统一汉字 + 扩展区
            if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) {
                tokens += 2
            } else {
                tokens += 1
            }
        }
        // 粗略：每 4 个 ASCII 字符约 1 token
        return max(1, tokens / 3)
    }
}
