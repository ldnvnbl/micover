import SwiftUI

/// 语音输入设置区块
struct VoiceInputSettingsSection: View {
    @State private var isOverCommandEnabled: Bool = SettingsStorage.shared.isOverCommandEnabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("Over 快捷回车")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                HStack {
                    Text("说 \"over\" 结尾时自动按回车")
                        .font(.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isOverCommandEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .onChange(of: isOverCommandEnabled) { _, newValue in
            SettingsStorage.shared.isOverCommandEnabled = newValue
        }
    }
}

#Preview {
    VoiceInputSettingsSection()
        .frame(width: 600)
        .padding()
}
