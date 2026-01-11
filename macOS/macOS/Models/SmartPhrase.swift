import Foundation
import SwiftUI

/// 智能短语动作类型 - 可扩展设计
enum SmartPhraseActionType: String, Codable, CaseIterable {
    case openApp = "openApp"
    case typeText = "typeText"
    case openURL = "openURL"
    // 未来扩展:
    // case runShortcut = "runShortcut"
    
    var displayName: String {
        switch self {
        case .openApp:
            return "打开应用"
        case .typeText:
            return "输入文本"
        case .openURL:
            return "打开链接"
        }
    }
    
    var icon: String {
        switch self {
        case .openApp:
            return "arrow.up.forward.app.fill"
        case .typeText:
            return "text.cursor"
        case .openURL:
            return "link"
        }
    }
    
    var description: String {
        switch self {
        case .openApp:
            return "启动指定的应用程序"
        case .typeText:
            return "输入预设的文本内容"
        case .openURL:
            return "使用默认浏览器打开链接"
        }
    }
    
    /// Badge 显示文字（英文简短）
    var badgeText: String {
        switch self {
        case .openApp:
            return "Open App"
        case .typeText:
            return "Type Text"
        case .openURL:
            return "Open URL"
        }
    }
    
    /// Badge 颜色
    var badgeColor: Color {
        switch self {
        case .openApp:
            return .blue
        case .typeText:
            return .green
        case .openURL:
            return .orange
        }
    }
}

/// 智能短语模型
struct SmartPhrase: Codable, Identifiable, Equatable {
    let id: UUID
    var trigger: String                      // 触发词（精确匹配）
    var actionType: SmartPhraseActionType
    var actionPayload: String                // 动作参数（对于 openApp 是 Bundle ID）
    var actionDisplayName: String            // 动作显示名称（对于 openApp 是应用名）
    var isEnabled: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        trigger: String,
        actionType: SmartPhraseActionType,
        actionPayload: String,
        actionDisplayName: String,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.trigger = trigger
        self.actionType = actionType
        self.actionPayload = actionPayload
        self.actionDisplayName = actionDisplayName
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

/// 智能短语错误类型
enum SmartPhraseError: LocalizedError {
    case appNotFound(String)
    case triggerExists(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .appNotFound(let name):
            return "找不到应用: \(name)"
        case .triggerExists(let trigger):
            return "触发词已存在: \(trigger)"
        case .executionFailed(let reason):
            return "执行失败: \(reason)"
        }
    }
}

/// 应用信息（用于 APP 选择器）
struct AppInfo: Identifiable, Hashable {
    let id: String          // Bundle ID
    let name: String        // 应用名称
    let bundleID: String    // Bundle ID
    let path: URL           // 应用路径
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
