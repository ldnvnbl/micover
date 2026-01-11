import SwiftUI

/// 设置页面
struct SettingsPage: View {
    var body: some View {
        VStack(spacing: 0) {
            // 固定区域
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                Text("设置")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // API 配置
                APIKeySettingsSection()
                
                // 音频
                AudioSettingsSection()
                
                // 语音输入
                VoiceInputSettingsSection()
                
                // 快捷键
                HotkeySettingsSection()
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    SettingsPage()
        .frame(width: 600, height: 500)
}
