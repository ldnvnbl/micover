import SwiftUI
import Shared

/// 首页 - 显示语音输入状态和今日统计
struct HomePage: View {
    @Environment(PushToTalkService.self) var pushToTalkService
    @Environment(AppState.self) var appState

    @State private var hotkeyConfiguration = SettingsStorage.shared.loadHotkeyConfiguration()
    @State private var isPulsing = false

    // 趋势图表状态
    @State private var selectedMetric: TrendMetric = .recordingCount
    @State private var selectedTimeRange: TimeRange = .week
    @State private var trendData: [DailyStats] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                Text("首页")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // 语音输入卡片
                voiceInputCard

                // 今日统计卡片
                statsCard

                // 趋势图表卡片
                TrendChartCard(
                    selectedMetric: $selectedMetric,
                    selectedTimeRange: $selectedTimeRange,
                    data: trendData
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            appState.loadTodayStats()
            hotkeyConfiguration = SettingsStorage.shared.loadHotkeyConfiguration()
            loadTrendData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyConfigurationChanged)) { _ in
            hotkeyConfiguration = SettingsStorage.shared.loadHotkeyConfiguration()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadTrendData()
        }
    }

    /// 加载趋势数据
    private func loadTrendData() {
        trendData = StatsStorage.shared.getStatsForRange(days: selectedTimeRange.rawValue)
    }
    
    // MARK: - 语音输入卡片

    private var voiceInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("语音输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // 卡片
            HStack {
                // 左侧：状态指示器
                HStack(spacing: 8) {
                    if pushToTalkService.isRecording {
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .symbolEffect(.variableColor.iterative.reversing)
                    } else {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                            .scaleEffect(isPulsing && pushToTalkService.isEnabled ? 1.3 : 1.0)
                            .opacity(isPulsing && pushToTalkService.isEnabled ? 0.7 : 1.0)
                            .animation(
                                pushToTalkService.isEnabled
                                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                    : .default,
                                value: isPulsing
                            )
                    }

                    Text(statusText)
                        .font(.body)
                        .foregroundColor(statusColor)
                }

                Spacer()

                // 右侧：说明文字 + 快捷键按钮风格
                HStack(spacing: 4) {
                    Text("按住")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(currentHotkeyParts.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            Text("+")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        KeyboardKey(key: part)
                    }

                    Text("说话，松开即输入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        }
        .onAppear {
            isPulsing = true
        }
    }
    
    // MARK: - 今日统计卡片

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("今日统计")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // 第一行：3 列
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    icon: "wand.and.stars",
                    title: "智能短语",
                    value: "\(appState.smartPhraseTriggeredCount)",
                    unit: "次",
                    color: .pink
                )

                statCard(
                    icon: "mic.fill",
                    title: "录音次数",
                    value: "\(appState.recordingCount)",
                    unit: "次",
                    color: .blue
                )

                statCard(
                    icon: "clock.fill",
                    title: "使用时长",
                    value: formatDurationValue(appState.totalRecordingDuration),
                    unit: formatDurationUnit(appState.totalRecordingDuration),
                    color: .green
                )
            }

            // 第二行：2 列
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    icon: "text.bubble.fill",
                    title: "转写字数",
                    value: "\(appState.totalTranscribedWords)",
                    unit: "字",
                    color: .purple
                )

                statCard(
                    icon: "speedometer",
                    title: "输入速度",
                    value: formatSpeedValue(appState.averageWPM),
                    unit: "字/分",
                    color: .orange
                )
            }
        }
    }

    // MARK: - 统计卡片组件

    private func statCard(icon: String, title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 彩色圆形图标背景
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                )

            // 数值和单位
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 标签
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 4) {
                Text("还没有录音记录")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("按住")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    ForEach(Array(currentHotkeyParts.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            Text("+")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        KeyboardKey(key: part)
                    }
                    Text("开始第一次语音输入")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - 辅助属性

    private var hasAnyStats: Bool {
        appState.recordingCount > 0 ||
        appState.totalRecordingDuration > 0 ||
        appState.totalTranscribedWords > 0 ||
        appState.smartPhraseTriggeredCount > 0
    }
    
    // MARK: - 辅助属性
    
    private var statusColor: Color {
        if pushToTalkService.isRecording {
            return .red
        } else if pushToTalkService.isEnabled {
            return .green
        } else {
            return .secondary
        }
    }
    
    private var statusText: String {
        if pushToTalkService.isRecording {
            return "录音中..."
        } else if pushToTalkService.isEnabled {
            return "已就绪"
        } else {
            return "未就绪"
        }
    }
    
    private var currentHotkey: Hotkey? {
        hotkeyConfiguration.hotkeys.first
    }

    private var currentHotkeyParts: [String] {
        currentHotkey?.keyParts ?? ["快捷键"]
    }
    
    // MARK: - 格式化方法

    private func formatDurationValue(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)"
        } else if seconds < 3600 {
            return "\(seconds / 60)"
        } else {
            return String(format: "%.1f", Double(seconds) / 3600)
        }
    }

    private func formatDurationUnit(_ seconds: Int) -> String {
        if seconds < 60 {
            return "秒"
        } else if seconds < 3600 {
            return "分钟"
        } else {
            return "小时"
        }
    }

    private func formatSpeedValue(_ wpm: Double) -> String {
        if wpm < 1 {
            return "0"
        }
        return String(format: "%.0f", wpm)
    }
}

// MARK: - Keyboard Key Component

struct KeyboardKey: View {
    let key: String
    @State private var isPressed = false
    
    var body: some View {
        Text(key)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(Color(NSColor.labelColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color(NSColor.separatorColor),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = hovering
                }
            }
    }
}

// MARK: - Preview

#Preview {
    HomePage()
        .environment(PushToTalkService())
        .environment(AppState())
        .frame(width: 600, height: 500)
}
