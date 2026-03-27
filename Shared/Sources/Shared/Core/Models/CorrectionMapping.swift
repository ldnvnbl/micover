import Foundation

/// 纠错映射条目（错误写法 → 正确写法）
public struct CorrectionMapping: Codable, Identifiable, Sendable {
    public let id: UUID
    public let wrongText: String
    public let correctText: String
    public let createdAt: Date

    public init(id: UUID = UUID(), wrongText: String, correctText: String, createdAt: Date = Date()) {
        self.id = id
        self.wrongText = wrongText
        self.correctText = correctText
        self.createdAt = createdAt
    }
}
