import SwiftUI

/// 设置卡片状态
enum SettingsCardStatus {
    case configured
    case notConfigured
    case none
    
    var label: String {
        switch self {
        case .configured: return "已配置"
        case .notConfigured: return "未配置"
        case .none: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .configured: return "checkmark.circle.fill"
        case .notConfigured: return "exclamationmark.circle.fill"
        case .none: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .configured: return .green
        case .notConfigured: return .orange
        case .none: return .clear
        }
    }
}

/// 通用设置卡片组件
struct SettingsCard<Content: View, HeaderAction: View>: View {
    let title: String
    let icon: String
    let description: String?
    let status: SettingsCardStatus
    let headerAction: HeaderAction?
    let content: Content
    
    init(
        title: String,
        icon: String,
        description: String? = nil,
        status: SettingsCardStatus = .none,
        @ViewBuilder headerAction: () -> HeaderAction,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.description = description
        self.status = status
        self.headerAction = headerAction()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                
                // 标题
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // 状态指示
                if status != .none {
                    Label(status.label, systemImage: status.icon)
                        .font(.caption)
                        .foregroundColor(status.color)
                }
                
                Spacer()
                
                // 右侧操作按钮
                if let action = headerAction {
                    action
                }
            }
            
            // 说明文字
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// 无 HeaderAction 时的便捷初始化
extension SettingsCard where HeaderAction == EmptyView {
    init(
        title: String,
        icon: String,
        description: String? = nil,
        status: SettingsCardStatus = .none,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.description = description
        self.status = status
        self.headerAction = nil
        self.content = content()
    }
}

#Preview {
    VStack(spacing: 24) {
        SettingsCard(
            title: "语音识别 API",
            icon: "key.fill",
            description: "请填写火山引擎语音识别 API Key",
            status: .configured
        ) {
            Text("内容区域")
        }
        
        SettingsCard(
            title: "Push-to-Talk 快捷键",
            icon: "keyboard",
            description: "配置用于触发语音录制的快捷键",
            status: .none
        ) {
            Button("添加快捷键", systemImage: "plus.circle.fill") {}
                .buttonStyle(.borderedProminent)
        } content: {
            Text("快捷键列表")
        }
    }
    .padding()
    .frame(width: 600)
}
