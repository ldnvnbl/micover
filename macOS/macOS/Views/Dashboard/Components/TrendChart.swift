import SwiftUI
import Shared

/// 趋势图表指标类型
enum TrendMetric: String, CaseIterable {
    case recordingCount = "录音次数"
    case duration = "使用时长"
    case words = "转写字数"
    case smartPhrase = "智能短语"

    var icon: String {
        switch self {
        case .recordingCount: return "mic.fill"
        case .duration: return "clock.fill"
        case .words: return "text.bubble.fill"
        case .smartPhrase: return "wand.and.stars"
        }
    }

    var color: Color {
        switch self {
        case .recordingCount: return .blue
        case .duration: return .green
        case .words: return .purple
        case .smartPhrase: return .pink
        }
    }

    var unit: String {
        switch self {
        case .recordingCount: return "次"
        case .duration: return "分钟"
        case .words: return "字"
        case .smartPhrase: return "次"
        }
    }

    /// 从 DailyStats 中提取对应指标的值
    func value(from stats: DailyStats) -> Int {
        switch self {
        case .recordingCount:
            return stats.recordingCount
        case .duration:
            return stats.totalRecordingDuration / 60  // 转换为分钟
        case .words:
            return stats.totalTranscribedWords
        case .smartPhrase:
            return stats.smartPhraseTriggeredCount
        }
    }
}

/// 时间范围选项
enum TimeRange: Int, CaseIterable {
    case week = 7
    case month = 30
    case quarter = 90

    var displayName: String {
        switch self {
        case .week: return "7天"
        case .month: return "30天"
        case .quarter: return "90天"
        }
    }
}

/// 趋势图表视图
struct TrendChart: View {
    let data: [DailyStats]
    let metric: TrendMetric
    let timeRange: TimeRange

    @State private var hoveredIndex: Int? = nil

    /// 日期格式化器
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    var body: some View {
        GeometryReader { geometry in
            let values = data.map { metric.value(from: $0) }
            let maxValue = max(values.max() ?? 1, 1)
            let barSpacing: CGFloat = timeRange == .week ? 8 : (timeRange == .month ? 4 : 2)
            let leftPadding: CGFloat = 35  // 左侧留给 Y 轴参考线标签
            let rightPadding: CGFloat = 20
            let availableWidth = geometry.size.width - leftPadding - rightPadding
            let barWidth = max((availableWidth - CGFloat(data.count - 1) * barSpacing) / CGFloat(data.count), 4)
            let chartHeight = geometry.size.height - 30  // 底部留空间给日期标签
            let chartAreaHeight = chartHeight - 20

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // 图表区域（包含参考线和柱状图）
                    ZStack(alignment: .bottom) {
                        // Y 轴参考线
                        ReferenceLines(maxValue: maxValue, height: chartAreaHeight, metric: metric)
                            .padding(.leading, leftPadding)
                            .padding(.trailing, rightPadding)

                        // 柱状图
                        HStack(alignment: .bottom, spacing: barSpacing) {
                            ForEach(Array(data.enumerated()), id: \.offset) { index, stats in
                                let value = metric.value(from: stats)
                                let heightRatio = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
                                let barHeight = max(heightRatio * chartAreaHeight, value > 0 ? 4 : 0)

                                BarView(
                                    value: value,
                                    barWidth: barWidth,
                                    barHeight: barHeight,
                                    color: metric.color,
                                    isHovered: hoveredIndex == index
                                )
                                .onHover { isHovered in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hoveredIndex = isHovered ? index : nil
                                    }
                                }
                            }
                        }
                        .padding(.leading, leftPadding)
                        .padding(.trailing, rightPadding)
                    }
                    .frame(height: chartAreaHeight)

                    // X 轴日期标签
                    HStack(spacing: 0) {
                        ForEach(labelIndices, id: \.self) { index in
                            if index < data.count {
                                Text(formatDate(data[index].date))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: 20)
                    .padding(.leading, leftPadding)
                    .padding(.trailing, rightPadding)
                }

                // Tooltip
                if let index = hoveredIndex, index < data.count {
                    let stats = data[index]
                    let value = metric.value(from: stats)
                    let barX = leftPadding + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2

                    TooltipView(
                        date: formatTooltipDate(stats.date),
                        value: value,
                        unit: metric.unit,
                        color: metric.color
                    )
                    .position(x: min(max(barX, 50), geometry.size.width - 50), y: 20)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: metric)
            .animation(.easeInOut(duration: 0.3), value: timeRange)
        }
    }

    /// 计算需要显示标签的索引
    private var labelIndices: [Int] {
        let count = data.count
        switch timeRange {
        case .week:
            return Array(0..<count)
        case .month:
            return stride(from: 0, to: count, by: 7).map { $0 }
        case .quarter:
            return stride(from: 0, to: count, by: 14).map { $0 }
        }
    }

    /// 格式化日期字符串（X 轴）
    private func formatDate(_ dateString: String) -> String {
        guard let date = Self.dateFormatter.date(from: dateString) else {
            return dateString
        }
        return Self.displayFormatter.string(from: date)
    }

    /// 格式化日期字符串（Tooltip）
    private func formatTooltipDate(_ dateString: String) -> String {
        guard let date = Self.dateFormatter.date(from: dateString) else {
            return dateString
        }
        return Self.tooltipDateFormatter.string(from: date)
    }
}

// MARK: - Y 轴参考线

private struct ReferenceLines: View {
    let maxValue: Int
    let height: CGFloat
    let metric: TrendMetric

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 参考线（只显示 2 条：最大值和中间值）
            ForEach(referenceValues, id: \.self) { value in
                let y = height - (CGFloat(value) / CGFloat(maxValue)) * height

                HStack(spacing: 4) {
                    // 标签
                    Text(formatValue(value))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28, alignment: .trailing)

                    // 参考线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 1)
                }
                .offset(y: y - 5)
            }

            // 底部基线（0）
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("0")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28, alignment: .trailing)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 1)
                }
            }
        }
    }

    /// 计算参考值（最大值和中间值）
    private var referenceValues: [Int] {
        guard maxValue > 0 else { return [] }

        let midValue = maxValue / 2
        if midValue > 0 && midValue != maxValue {
            return [midValue, maxValue]
        }
        return [maxValue]
    }

    /// 格式化参考值
    private func formatValue(_ value: Int) -> String {
        if value >= 1000 {
            return "\(value / 1000)k"
        }
        return "\(value)"
    }
}

// MARK: - 柱子视图

private struct BarView: View {
    let value: Int
    let barWidth: CGFloat
    let barHeight: CGFloat
    let color: Color
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(value > 0 ? (isHovered ? 0.8 : 1) : 0.2))
            .frame(width: barWidth, height: barHeight)
            .scaleEffect(x: isHovered ? 1.1 : 1, y: 1, anchor: .bottom)
            .shadow(color: isHovered ? color.opacity(0.3) : .clear, radius: 4, y: 2)
    }
}

// MARK: - Tooltip 视图

private struct TooltipView: View {
    let date: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(date)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("\(value)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

/// 趋势图表卡片（完整组件，包含标题、切换器、图表）
struct TrendChartCard: View {
    @Binding var selectedMetric: TrendMetric
    @Binding var selectedTimeRange: TimeRange
    let data: [DailyStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("趋势")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // 卡片内容
            VStack(spacing: 16) {
                // 顶部：时间范围切换
                HStack {
                    // 汇总数值
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalValue)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(selectedMetric.unit)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 时间范围切换
                    HStack(spacing: 4) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTimeRange = range
                                }
                            } label: {
                                Text(range.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedTimeRange == range ? .white : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedTimeRange == range ? selectedMetric.color : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 指标切换标签
                HStack(spacing: 8) {
                    ForEach(TrendMetric.allCases, id: \.self) { metric in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMetric = metric
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 11))
                                Text(metric.rawValue)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(selectedMetric == metric ? metric.color : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedMetric == metric ? metric.color.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedMetric == metric ? metric.color.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 图表
                TrendChart(data: data, metric: selectedMetric, timeRange: selectedTimeRange)
                    .frame(height: 150)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        }
    }

    /// 计算当前范围内选中指标的总值
    private var totalValue: Int {
        data.reduce(0) { $0 + selectedMetric.value(from: $1) }
    }
}

// MARK: - Preview

#Preview {
    // 生成模拟数据
    let mockData: [DailyStats] = (0..<7).reversed().map { dayOffset in
        let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        let dateKey = DailyStats.dateKey(for: date)
        return DailyStats(
            date: dateKey,
            recordingCount: Int.random(in: 0...10),
            totalRecordingDuration: Int.random(in: 0...600),
            totalTranscribedWords: Int.random(in: 0...500),
            smartPhraseTriggeredCount: Int.random(in: 0...5)
        )
    }

    return TrendChartCard(
        selectedMetric: .constant(.recordingCount),
        selectedTimeRange: .constant(.week),
        data: mockData
    )
    .padding()
    .frame(width: 600, height: 350)
}
