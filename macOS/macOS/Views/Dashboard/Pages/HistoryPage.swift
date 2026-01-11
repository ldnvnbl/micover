import SwiftUI

/// 历史记录页面
struct HistoryPage: View {
    @State private var records: [HistoryRecord] = []
    @State private var settings: HistorySettings = HistoryStorage.shared.getSettings()
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 固定区域（不滚动）
            VStack(alignment: .leading, spacing: 16) {
                // Header with action buttons
                headerSection
                
                // Settings Card (合并设置和隐私声明)
                settingsCard
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 16)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity, alignment: .center)
            
            // 滚动区域（边框在外层容器，不随内容滚动）
            if records.isEmpty {
                emptyStateView
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    recordsListContent
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyRecordAdded)) { _ in
            loadRecords()
        }
        .alert("确认清空", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearAllRecords()
            }
        } message: {
            Text("确定要清空所有历史记录吗？此操作不可恢复。")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Text("历史记录")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // 导出按钮
            Button {
                HistoryStorage.shared.exportWithSavePanel()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("导出")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(records.isEmpty)

            // 清空按钮
            Button {
                showClearConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("清空")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
            .disabled(records.isEmpty)
        }
    }
    
    // MARK: - Settings Card (合并设置和隐私声明)
    
    private var settingsCard: some View {
        VStack(spacing: 0) {
            // 启用历史记录
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                
                Text("启用历史记录")
                    .font(.body)
                
                Spacer()
                
                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: settings.isEnabled) { _, _ in
                        HistoryStorage.shared.saveSettings(settings)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.leading, 52)
            
            // 保留时长
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                
                Text("保留时长")
                    .font(.body)
                
                Spacer()
                
                Picker("", selection: $settings.retentionPeriod) {
                    ForEach(HistoryRetentionPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: 120)
                .onChange(of: settings.retentionPeriod) { _, _ in
                    HistoryStorage.shared.saveSettings(settings)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.leading, 52)
            
            // 数据隐私保护
            HStack(alignment: .center) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                
                Text("数据隐私保护")
                    .font(.body)
                
                Spacer()
                
                Text("所有记录仅保存在本地设备，不会上传到任何服务器")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无历史记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("开始使用语音输入后，记录将显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Records List
    
    /// 记录列表内容（不带边框，用于 ScrollView 内部）
    private var recordsListContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(records) { record in
                HistoryRecordRow(record: record) {
                    deleteRecord(record)
                }
                
                if record.id != records.last?.id {
                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
    }
    
    private func deleteRecord(_ record: HistoryRecord) {
        HistoryStorage.shared.deleteRecord(id: record.id)
        loadRecords()
    }
    
    // MARK: - Methods
    
    private func loadRecords() {
        records = HistoryStorage.shared.loadAllRecords()
    }
    
    private func clearAllRecords() {
        HistoryStorage.shared.clearAllRecords()
        loadRecords()
    }
}

// MARK: - History Record Row

struct HistoryRecordRow: View {
    let record: HistoryRecord
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var isHoveringCopy = false
    @State private var isHoveringDelete = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Time
            Text(formattedTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Content
            if record.transcribedText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("未检测到语音")
                        .font(.system(size: 14))
                }
                .foregroundColor(.secondary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(record.transcribedText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action Buttons (always present, opacity controlled)
            HStack(spacing: 6) {
                // Copy Button (只在有内容时显示)
                if !record.transcribedText.isEmpty {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(showCopiedFeedback ? .green : (isHoveringCopy ? .primary : .secondary))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(isHoveringCopy ? Color(NSColor.controlColor) : Color(NSColor.controlBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    .help("复制")
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isHoveringCopy = hovering
                        }
                    }
                }
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(isHoveringDelete ? .red : .secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(isHoveringDelete ? Color(NSColor.controlColor) : Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
                .help("删除")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHoveringDelete = hovering
                    }
                }
            }
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())  // 让整行区域都可以接收 hover 事件
        .background(isHovering ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: record.timestamp)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.transcribedText, forType: .string)
        
        // Show feedback
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = false
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryPage()
}
