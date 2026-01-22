import Foundation
import Observation

/// 自定义词典服务
/// 负责自定义词条的业务逻辑
@Observable
@MainActor
final class CustomWordService {
    static let shared = CustomWordService()

    private(set) var words: [CustomWord] = []

    private init() {
        loadWords()
    }

    // MARK: - CRUD Operations

    /// 加载所有词条
    func loadWords() {
        words = CustomWordStorage.shared.load()
    }

    /// 添加新词条
    /// - Returns: 是否添加成功（词条已存在时返回 false）
    func addWord(_ word: CustomWord) -> Bool {
        // 检查是否已存在
        if CustomWordStorage.shared.wordExists(word.word) {
            return false
        }

        words.append(word)
        CustomWordStorage.shared.save(words)
        return true
    }

    /// 批量添加词条
    /// - Returns: 成功添加的数量
    func addWords(_ newWords: [String]) -> Int {
        var addedCount = 0
        for wordText in newWords {
            let trimmed = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !CustomWordStorage.shared.wordExists(trimmed) {
                let word = CustomWord(word: trimmed)
                words.append(word)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            CustomWordStorage.shared.save(words)
        }
        return addedCount
    }

    /// 更新词条
    func updateWord(_ word: CustomWord) {
        guard let index = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[index] = word
        CustomWordStorage.shared.save(words)
    }

    /// 删除词条
    func deleteWord(_ word: CustomWord) {
        words.removeAll { $0.id == word.id }
        CustomWordStorage.shared.save(words)
    }

    /// 切换词条启用状态
    func toggleEnabled(_ word: CustomWord) {
        guard let index = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[index].isEnabled.toggle()
        CustomWordStorage.shared.save(words)
    }

    /// 删除所有词条
    func deleteAllWords() {
        words.removeAll()
        CustomWordStorage.shared.save(words)
    }

    // MARK: - API Integration

    /// 获取用于 API 的热词 JSON 字符串
    /// 格式: {"hotwords":[{"word":"词条1"}, {"word":"词条2"}]}
    func getHotwordsJSON() -> String? {
        let enabledWords = words.filter { $0.isEnabled }
        guard !enabledWords.isEmpty else { return nil }

        let hotwordsArray = enabledWords.map { ["word": $0.word] }
        let hotwordsDict: [String: Any] = ["hotwords": hotwordsArray]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: hotwordsDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }
}
