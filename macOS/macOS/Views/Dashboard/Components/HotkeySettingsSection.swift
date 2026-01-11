import SwiftUI

/// 快捷键设置区块
struct HotkeySettingsSection: View {
    @State private var configuration = SettingsStorage.shared.loadHotkeyConfiguration()
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?
    @State private var fnKeyDetected = false

    /// 当前显示的快捷键（只取第一个）
    private var currentHotkey: Hotkey? {
        configuration.hotkeys.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("快捷键")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                // 语音录制快捷键行
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("语音录制")
                            .font(.body)
                        
                        Text("按住说话，松开即输入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 快捷键输入框
                    hotkeyInputField
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
    }
    
    // MARK: - Hotkey Input Field
    
    @ViewBuilder
    private var hotkeyInputField: some View {
        if isRecording {
            // 录制状态
            HStack(spacing: 8) {
                Image(systemName: "record.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, isActive: true)
                
                Text("按下快捷键...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Button("取消") {
                    stopRecording()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            )
        } else {
            // 显示当前快捷键的输入框样式
            HStack(spacing: 6) {
                // 左侧：快捷键显示
                if let hotkey = currentHotkey {
                    ForEach(Array(hotkey.keyParts.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            Text("+")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        KeyboardKeyCompact(key: part)
                    }
                } else {
                    Text("点击设置")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // 右侧：清除按钮（重置为 Fn）
                Button {
                    resetToDefault()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("重置为默认快捷键 (Fn)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                startRecording()
            }
            .help("点击修改快捷键")
        }
    }
    
    // MARK: - Recording Methods
    
    private func startRecording() {
        isRecording = true
        fnKeyDetected = false
        
        // 监听普通按键
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape 取消录制
            if event.keyCode == 0x35 {
                stopRecording()
                return nil
            }

            if let hotkey = Hotkey.fromKeyEvent(event) {
                setHotkey(hotkey)
            }
            return nil
        }

        // 监听 Fn 键
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.modifierFlags.contains(.function) && !fnKeyDetected {
                fnKeyDetected = true
                setHotkey(.fnKey)
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        cleanupMonitors()
    }
    
    private func setHotkey(_ hotkey: Hotkey) {
        // 替换为新的快捷键（只保留一个）
        configuration.hotkeys = [hotkey]
        SettingsStorage.shared.saveHotkeyConfiguration(configuration)
        SettingsStorage.shared.notifyConfigurationChanged(configuration)
        stopRecording()
    }
    
    private func resetToDefault() {
        // 重置为默认的 Fn 键
        setHotkey(.fnKey)
    }
    
    private func cleanupMonitors() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        fnKeyDetected = false
    }
}

// MARK: - Compact Keyboard Key Component

/// 紧凑型键盘按键样式（用于输入框内）
struct KeyboardKeyCompact: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Color(NSColor.labelColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
    }
}

#Preview {
    VStack {
        HotkeySettingsSection()
            .padding()
    }
    .frame(width: 600, height: 200)
}
