import Foundation

/// 历史记录动作类型
enum HistoryActionType: String, Codable {
    case textInput              // 普通文本输入
    case smartPhraseOpenApp     // 智能短语 - 打开应用
    case smartPhraseTypeText    // 智能短语 - 输入文本
    case smartPhraseOpenURL     // 智能短语 - 打开链接
    
    var displayName: String {
        switch self {
        case .textInput:
            return "文本输入"
        case .smartPhraseOpenApp:
            return "打开应用"
        case .smartPhraseTypeText:
            return "输入文本"
        case .smartPhraseOpenURL:
            return "打开链接"
        }
    }
    
    var icon: String {
        switch self {
        case .textInput:
            return "text.cursor"
        case .smartPhraseOpenApp:
            return "app.fill"
        case .smartPhraseTypeText:
            return "doc.text.fill"
        case .smartPhraseOpenURL:
            return "link"
        }
    }
}

/// 历史记录条目
struct HistoryRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let transcribedText: String
    let duration: TimeInterval      // 录音时长（秒）
    let wordCount: Int
    let actionType: HistoryActionType
    let actionDetail: String?       // 智能短语名称等
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcribedText: String,
        duration: TimeInterval,
        wordCount: Int,
        actionType: HistoryActionType = .textInput,
        actionDetail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcribedText = transcribedText
        self.duration = duration
        self.wordCount = wordCount
        self.actionType = actionType
        self.actionDetail = actionDetail
    }
}

/// 历史记录保留时间选项
enum HistoryRetentionPeriod: Int, CaseIterable, Codable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90
    case forever = 0
    
    var displayName: String {
        switch self {
        case .sevenDays:
            return "7 天"
        case .thirtyDays:
            return "30 天"
        case .ninetyDays:
            return "90 天"
        case .forever:
            return "永久保留"
        }
    }
}

/// 历史记录设置
struct HistorySettings: Codable {
    var isEnabled: Bool
    var retentionPeriod: HistoryRetentionPeriod
    
    init(isEnabled: Bool = true, retentionPeriod: HistoryRetentionPeriod = .thirtyDays) {
        self.isEnabled = isEnabled
        self.retentionPeriod = retentionPeriod
    }
    
    static let `default` = HistorySettings()
}
