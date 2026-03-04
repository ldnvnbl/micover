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

        // Debug: 打印上下文详情
        if let entries = contextEntries {
            print("📋 [ASRContext] dialog_ctx entries (\(entries.count)):")
            for (i, entry) in entries.enumerated() {
                print("  [\(i)] \(entry.text ?? "")")
            }
        } else {
            print("📋 [ASRContext] no dialog_ctx entries")
        }

        return CorpusContext(
            hotwords: hotwords,
            contextType: contextEntries != nil ? "dialog_ctx" : nil,
            contextData: contextEntries
        )
    }

    // MARK: - Hotwords

    /// 从 UserDefaults 加载启用的热词
    nonisolated private func loadHotwords() -> [HotwordEntry]? {
        guard let data = UserDefaults.standard.data(forKey: "settings.customWords"),
              let words = try? JSONDecoder().decode([CustomWord].self, from: data) else {
            return nil
        }

        let enabled = words.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return nil }

        return enabled.map { HotwordEntry(word: $0.word) }
    }

    // MARK: - Dialog Context

    /// 组合三种上下文数据源
    nonisolated private func buildDialogContext() -> [ContextDataEntry]? {
        var entries: [ContextDataEntry] = []
        var usedTokens = 0

        // 1. 当前前台应用
        let appEntry = frontmostAppEntry()
        print("📋 [ASRContext] frontmostApp: \(appEntry?.text ?? "nil")")
        if let appEntry {
            let tokens = estimateTokens(appEntry.text ?? "")
            if usedTokens + tokens <= Self.maxContextTokenEstimate {
                entries.append(appEntry)
                usedTokens += tokens
            }
        }

        // 2. 智能短语触发词
        let phraseEntry = smartPhrasesEntry()
        print("📋 [ASRContext] smartPhrases: \(phraseEntry?.text ?? "nil")")
        if let phraseEntry {
            let tokens = estimateTokens(phraseEntry.text ?? "")
            if usedTokens + tokens <= Self.maxContextTokenEstimate {
                entries.append(phraseEntry)
                usedTokens += tokens
            }
        }

        // 3. 最近转录历史（按时间从旧到新）
        let historyEntries = recentTranscriptionEntries(remainingTokens: Self.maxContextTokenEstimate - usedTokens)
        print("📋 [ASRContext] history: \(historyEntries.count) entries")
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

    // MARK: - 2c. 最近转录历史

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

            let textInputRecords = weekRecords.filter { $0.actionType == .textInput && !$0.transcribedText.isEmpty }
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
            let tokens = estimateTokens(record.transcribedText)
            if usedTokens + tokens > remainingTokens {
                break
            }
            selected.append(ContextDataEntry(text: record.transcribedText))
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
