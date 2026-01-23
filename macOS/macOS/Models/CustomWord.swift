import Foundation

/// 个人词库条目
/// 用于提高语音识别对特定词汇的准确率
struct CustomWord: Codable, Identifiable, Equatable {
    let id: UUID
    var word: String
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        word: String,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
