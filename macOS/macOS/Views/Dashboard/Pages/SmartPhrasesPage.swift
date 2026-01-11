import SwiftUI

/// 智能短语管理页面
struct SmartPhrasesPage: View {
    @Environment(AppState.self) var appState
    
    @State private var phrases: [SmartPhrase] = []
    @State private var showAddSheet = false
    @State private var showDeleteAlert = false
    @State private var phraseToEdit: SmartPhrase?
    @State private var phraseToDelete: SmartPhrase?
    
    var body: some View {
        VStack(spacing: 0) {
            // 固定区域
            VStack(alignment: .leading, spacing: 16) {
                // 标题行：智能短语 + 添加按钮
                headerSection
                
                // 短语列表卡片
                if phrases.isEmpty {
                    emptyStateView
                } else {
                    phraseListCard
                }
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
        .onAppear {
            loadPhrases()
        }
        .onChange(of: appState.smartPhraseTriggeredCount) {
            loadPhrases()
        }
        .sheet(isPresented: $showAddSheet) {
            SmartPhraseEditSheet(mode: .add) { newPhrase in
                if SmartPhraseService.shared.addPhrase(newPhrase) {
                    loadPhrases()
                }
            }
        }
        .sheet(item: $phraseToEdit) { phrase in
            SmartPhraseEditSheet(mode: .edit(phrase)) { updatedPhrase in
                SmartPhraseService.shared.updatePhrase(updatedPhrase)
                loadPhrases()
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                phraseToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let phrase = phraseToDelete {
                    SmartPhraseService.shared.deletePhrase(phrase)
                    loadPhrases()
                }
            }
        } message: {
            if let phrase = phraseToDelete {
                Text("确定要删除智能短语 \"\(phrase.trigger)\" 吗？")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Text("智能短语")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // 添加按钮
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("添加")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无智能短语")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角「添加」按钮创建智能短语")
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
    
    // MARK: - Phrase List Card
    
    private var phraseListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                SmartPhraseRow(
                    phrase: phrase,
                    todayTriggerCount: SmartPhraseStorage.shared.getTodayTriggerCount(for: phrase.id),
                    onEdit: {
                        phraseToEdit = phrase
                    },
                    onDelete: {
                        phraseToDelete = phrase
                        showDeleteAlert = true
                    },
                    onToggle: {
                        SmartPhraseService.shared.toggleEnabled(phrase)
                        loadPhrases()
                    }
                )
                
                if index < phrases.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
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
    
    // MARK: - Methods
    
    private func loadPhrases() {
        phrases = SmartPhraseService.shared.phrases
    }
}

// MARK: - Smart Phrase Row

struct SmartPhraseRow: View {
    let phrase: SmartPhrase
    let todayTriggerCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    @State private var isHovering = false
    @State private var isHoveringEdit = false
    @State private var isHoveringDelete = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 触发短语
            Text(phrase.trigger)
                .font(.system(size: 14))
                .foregroundColor(phrase.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .frame(minWidth: 80, alignment: .leading)
            
            // 动作类型标签
            ActionTypeBadge(actionType: phrase.actionType)
                .fixedSize()
            
            // 目标（带图标）
            HStack(spacing: 6) {
                if phrase.actionType == .openApp {
                    AppIconView(bundleID: phrase.actionPayload)
                        .frame(width: 18, height: 18)
                } else if phrase.actionType == .openURL {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "text.quote")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                
                Text(phrase.actionDisplayName)
                    .font(.system(size: 13))
                    .foregroundColor(phrase.isEnabled ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
            
            // 今日次数
            HStack(spacing: 4) {
                Text("今日")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(todayTriggerCount)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(todayTriggerCount > 0 ? .pink : .secondary)
            }
            .frame(width: 50, alignment: .trailing)
            
            // 操作按钮（Hover 时显示）
            HStack(spacing: 6) {
                // Toggle 开关
                Toggle("", isOn: Binding(
                    get: { phrase.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                
                // 编辑按钮
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(isHoveringEdit ? .primary : .secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(isHoveringEdit ? Color(NSColor.controlColor) : Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
                .help("编辑")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHoveringEdit = hovering
                    }
                }
                
                // 删除按钮
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
        .contentShape(Rectangle())
        .background(isHovering ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .opacity(phrase.isEnabled ? 1 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Action Type Badge

struct ActionTypeBadge: View {
    let actionType: SmartPhraseActionType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: actionType.icon)
                .font(.system(size: 10, weight: .semibold))
            
            Text(actionType.badgeText)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(actionType.badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(actionType.badgeColor.opacity(0.12))
        )
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleID: String
    
    var body: some View {
        Group {
            if let icon = getAppIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getAppIcon() -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Edit Sheet

enum SmartPhraseEditMode {
    case add
    case edit(SmartPhrase)
    
    var title: String {
        switch self {
        case .add: return "添加智能短语"
        case .edit: return "编辑智能短语"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}

struct SmartPhraseEditSheet: View {
    let mode: SmartPhraseEditMode
    let onSave: (SmartPhrase) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var trigger: String = ""
    @State private var actionType: SmartPhraseActionType = .openApp
    @State private var selectedApp: AppInfo?
    @State private var installedApps: [AppInfo] = []
    @State private var showDuplicateAlert = false
    @State private var isLoadingApps = true
    @State private var searchText = ""
    @State private var textToType: String = ""
    @State private var urlToOpen: String = ""
    
    private var existingPhraseId: UUID? {
        if case .edit(let phrase) = mode {
            return phrase.id
        }
        return nil
    }
    
    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var canSave: Bool {
        let hasTrigger = !trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch actionType {
        case .openApp:
            return hasTrigger && selectedApp != nil
        case .typeText:
            return hasTrigger && !textToType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openURL:
            return hasTrigger && isValidURL(urlToOpen)
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(mode.title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
// Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 触发短语 Section（用户首先想到的）
                    triggerSection
                    
                    // 动作 Section
                    actionSection
                    
                    // 选择应用 / 输入文本 / URL Section
                    if actionType == .openApp {
                        appSelectionSection
                    } else if actionType == .typeText {
                        textInputSection
                    } else if actionType == .openURL {
                        urlInputSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            // Footer
            HStack {
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button(mode.buttonTitle) {
                    savePhrase()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadInitialData()
        }
        .alert("触发短语已存在", isPresented: $showDuplicateAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请使用不同的触发短语。")
        }
    }
    
    // MARK: - 触发短语 Section
    
    private var triggerPlaceholder: String {
        switch actionType {
        case .openApp:
            return "例如：打开微信"
        case .typeText:
            return "例如：输入我的邮箱"
        case .openURL:
            return "例如：打开谷歌"
        }
    }
    
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("触发短语")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                TextField(triggerPlaceholder, text: $trigger)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            
            // 提示
            Text("精确匹配，忽略大小写和首尾标点")
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.leading, 4)
        }
    }
    
    // MARK: - 动作 Section
    
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("动作")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                HStack {
                    Text("动作类型")
                        .font(.body)
                    
                    Spacer()
                    
                    Picker("", selection: $actionType) {
                        ForEach(SmartPhraseActionType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .frame(width: 140)
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
    
    // MARK: - 选择应用 Section
    
    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行（带已选提示）
            HStack {
                Text("选择应用")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let app = selectedApp {
                    Text("已选: \(app.name)")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 4)
            
            // 卡片
            VStack(spacing: 0) {
                if isLoadingApps {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("加载应用列表...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // 搜索框行
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextField("搜索应用", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // 应用列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                                AppSelectionRow(
                                    app: app,
                                    isSelected: selectedApp?.bundleID == app.bundleID,
                                    onSelect: { selectedApp = app }
                                )
                                
                                if index < filteredApps.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
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
    
    // MARK: - 输入文本 Section
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("替换文本")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                // 预设模板行
                HStack(spacing: 8) {
                    Text("快捷模板")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    ForEach(TextTemplate.allCases, id: \.self) { template in
                        Button(template.displayName) {
                            trigger = template.trigger
                            textToType = template.text
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 文本编辑器
                TextEditor(text: $textToType)
                    .font(.system(size: 13))
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            
            // 提示
            Text("匹配时自动输入此文本（支持多行）")
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.leading, 4)
        }
    }
    
    // MARK: - URL 输入 Section
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("目标链接")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // 卡片
            VStack(spacing: 0) {
                // 预设模板行
                HStack(spacing: 8) {
                    Text("快捷模板")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    ForEach(URLTemplate.allCases, id: \.self) { template in
                        Button(template.displayName) {
                            trigger = template.trigger
                            urlToOpen = template.url
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // URL 输入框
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("https://example.com", text: $urlToOpen)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            
            // 提示
            HStack(spacing: 4) {
                if !urlToOpen.isEmpty && !isValidURL(urlToOpen) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("请输入有效的 URL（需以 http:// 或 https:// 开头）")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("将使用默认浏览器打开此链接")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
            .padding(.leading, 4)
        }
    }
    
    // MARK: - Methods
    
    private func loadInitialData() {
        // 如果是编辑模式，加载现有数据
        if case .edit(let phrase) = mode {
            trigger = phrase.trigger
            actionType = phrase.actionType
            
            // 加载 typeText 的数据
            if phrase.actionType == .typeText {
                textToType = phrase.actionPayload
            }
            
            // 加载 openURL 的数据
            if phrase.actionType == .openURL {
                urlToOpen = phrase.actionPayload
            }
        }
        
        // 异步加载应用列表
        Task {
            let service = SmartPhraseService.shared
            
            let apps = await Task.detached(priority: .userInitiated) {
                return service.getInstalledApps()
            }.value
            
            installedApps = apps
            isLoadingApps = false
            
            // 如果是编辑模式，选中当前的应用
            if case .edit(let phrase) = mode, phrase.actionType == .openApp {
                selectedApp = apps.first { $0.bundleID == phrase.actionPayload }
            }
        }
    }
    
    private func savePhrase() {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查触发短语唯一性
        if SmartPhraseStorage.shared.triggerExists(trimmedTrigger, excludingId: existingPhraseId) {
            showDuplicateAlert = true
            return
        }
        
        // 根据动作类型获取 payload 和 displayName
        let payload: String
        let displayName: String
        
        switch actionType {
        case .openApp:
            guard let app = selectedApp else { return }
            payload = app.bundleID
            displayName = app.name
        case .typeText:
            let trimmedText = textToType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return }
            payload = trimmedText
            // 显示名称：截取前 20 个字符
            let previewText = trimmedText.replacingOccurrences(of: "\n", with: " ")
            displayName = previewText.count > 20 ? String(previewText.prefix(20)) + "..." : previewText
        case .openURL:
            let trimmedURL = urlToOpen.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidURL(trimmedURL) else { return }
            payload = trimmedURL
            // 显示名称：提取域名
            if let url = URL(string: trimmedURL), let host = url.host {
                displayName = host
            } else {
                displayName = trimmedURL.count > 30 ? String(trimmedURL.prefix(30)) + "..." : trimmedURL
            }
        }
        
        let phrase: SmartPhrase
        
        switch mode {
        case .add:
            phrase = SmartPhrase(
                trigger: trimmedTrigger,
                actionType: actionType,
                actionPayload: payload,
                actionDisplayName: displayName
            )
        case .edit(let existingPhrase):
            phrase = SmartPhrase(
                id: existingPhrase.id,
                trigger: trimmedTrigger,
                actionType: actionType,
                actionPayload: payload,
                actionDisplayName: displayName,
                isEnabled: existingPhrase.isEnabled,
                createdAt: existingPhrase.createdAt
            )
        }
        
        onSave(phrase)
        dismiss()
    }
}

// MARK: - Text Templates

enum TextTemplate: CaseIterable {
    case phone
    case email
    case address
    
    var displayName: String {
        switch self {
        case .phone: return "电话"
        case .email: return "邮箱"
        case .address: return "地址"
        }
    }
    
    var trigger: String {
        switch self {
        case .phone: return "请输入电话号码"
        case .email: return "请输入邮箱地址"
        case .address: return "请输入地址"
        }
    }
    
    var text: String {
        switch self {
        case .phone: return "131****8888"
        case .email: return "example@email.com"
        case .address: return "北京市朝阳区xxx路xxx号"
        }
    }
}

// MARK: - URL Templates

enum URLTemplate: CaseIterable {
    case google
    case github
    case youtube
    
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .github: return "GitHub"
        case .youtube: return "YouTube"
        }
    }
    
    var trigger: String {
        switch self {
        case .google: return "打开谷歌"
        case .github: return "打开 GitHub"
        case .youtube: return "打开 YouTube"
        }
    }
    
    var url: String {
        switch self {
        case .google: return "https://www.google.com"
        case .github: return "https://github.com"
        case .youtube: return "https://www.youtube.com"
        }
    }
}

// MARK: - App Selection Row

struct AppSelectionRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // App Icon
                if let icon = NSWorkspace.shared.icon(forFile: app.path.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                
                // App Name
                Text(app.name)
                    .font(.body)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : (isHovering ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SmartPhrasesPage()
        .environment(AppState())
}
