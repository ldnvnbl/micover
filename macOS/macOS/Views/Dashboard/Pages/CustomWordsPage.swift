import SwiftUI
import Shared

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                maxRowWidth = max(maxRowWidth, x - horizontalSpacing)
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
        maxRowWidth = max(maxRowWidth, x)

        return (offsets, CGSize(width: maxRowWidth, height: y + rowHeight))
    }
}

// MARK: - Custom Words Page

enum VocabularyTab: String, CaseIterable {
    case words = "词库"
    case mappings = "纠错映射"
}

struct CustomWordsPage: View {
    @State private var selectedTab: VocabularyTab = .words
    @State private var words: [CustomWord] = []
    @State private var mappings: [CorrectionMapping] = []
    @State private var showAddSheet = false
    @State private var showBatchAddSheet = false
    @State private var showAddMappingSheet = false
    @State private var showDeleteAlert = false
    @State private var showDeleteMappingAlert = false
    @State private var wordToEdit: CustomWord?
    @State private var wordToDelete: CustomWord?
    @State private var mappingToEdit: CorrectionMapping?
    @State private var mappingToDelete: CorrectionMapping?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                contentCard
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
            loadWords()
            loadMappings()
        }
        .sheet(isPresented: $showAddSheet) {
            CustomWordEditSheet(mode: .add) { newWord in
                if CustomWordService.shared.addWord(newWord) {
                    loadWords()
                }
            }
        }
        .sheet(isPresented: $showBatchAddSheet) {
            CustomWordBatchAddSheet { addedCount in
                if addedCount > 0 {
                    loadWords()
                }
            }
        }
        .sheet(item: $wordToEdit) { word in
            CustomWordEditSheet(mode: .edit(word)) { updatedWord in
                CustomWordService.shared.updateWord(updatedWord)
                loadWords()
            }
        }
        .sheet(isPresented: $showAddMappingSheet) {
            MappingEditSheet(mode: .add) { mapping in
                CorrectionMappingStorage.shared.addMappings([mapping])
                loadMappings()
            }
        }
        .sheet(item: $mappingToEdit) { mapping in
            MappingEditSheet(mode: .edit(mapping)) { updated in
                CorrectionMappingStorage.shared.updateMapping(updated)
                loadMappings()
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { wordToDelete = nil }
            Button("删除", role: .destructive) {
                if let word = wordToDelete {
                    CustomWordService.shared.deleteWord(word)
                    loadWords()
                }
            }
        } message: {
            if let word = wordToDelete {
                Text("确定要删除词条「\(word.word)」吗？")
            }
        }
        .alert("确认删除", isPresented: $showDeleteMappingAlert) {
            Button("取消", role: .cancel) { mappingToDelete = nil }
            Button("删除", role: .destructive) {
                if let mapping = mappingToDelete {
                    CorrectionMappingStorage.shared.removeMapping(id: mapping.id)
                    loadMappings()
                }
            }
        } message: {
            if let mapping = mappingToDelete {
                Text("确定要删除映射「\(mapping.wrongText) → \(mapping.correctText)」吗？")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("个人词库")
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(VocabularyTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                HStack(spacing: 8) {
                    if selectedTab == .words {
                        Button {
                            showBatchAddSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("批量添加")
                                    .font(.system(size: 13))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Button {
                        if selectedTab == .words {
                            showAddSheet = true
                        } else {
                            showAddMappingSheet = true
                        }
                    } label: {
                        HStack(spacing: 6) {
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
        }
    }

    // MARK: - Content Card

    private var contentCard: some View {
        Group {
            if selectedTab == .words {
                wordsContent
            } else {
                mappingsContent
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

    @ViewBuilder
    private var wordsContent: some View {
        if words.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("词库为空")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("添加专业术语、人名等帮助语音识别更准确")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else {
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(words) { word in
                    WordTagView(
                        word: word,
                        onEdit: { wordToEdit = word },
                        onDelete: {
                            wordToDelete = word
                            showDeleteAlert = true
                        },
                        onToggle: {
                            CustomWordService.shared.toggleEnabled(word)
                            loadWords()
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var mappingsContent: some View {
        if mappings.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("暂无纠错映射")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("使用「AI 纠错」后可自动提炼，或手动添加")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else {
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(mappings) { mapping in
                    MappingTagView(
                        mapping: mapping,
                        onEdit: { mappingToEdit = mapping },
                        onDelete: {
                            mappingToDelete = mapping
                            showDeleteMappingAlert = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Methods

    private func loadWords() {
        words = CustomWordService.shared.words
    }

    private func loadMappings() {
        mappings = CorrectionMappingStorage.shared.mappings
    }
}

// MARK: - Word Tag

struct WordTagView: View {
    let word: CustomWord
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Text(word.word)
            .font(.system(size: 13))
            .foregroundColor(word.isEnabled ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering
                        ? Color(NSColor.selectedControlColor).opacity(0.15)
                        : Color(NSColor.windowBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(NSColor.separatorColor).opacity(isHovering ? 0.8 : 0.4), lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if isHovering {
                    Button { onDelete() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                    .transition(.opacity)
                }
            }
            .opacity(word.isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            }
            .contextMenu {
                Button("编辑...") { onEdit() }
                Button(word.isEnabled ? "停用" : "启用") { onToggle() }
                Divider()
                Button("删除", role: .destructive) { onDelete() }
            }
    }
}

// MARK: - Mapping Tag

struct MappingTagView: View {
    let mapping: CorrectionMapping
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(mapping.wrongText)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))

            Text(mapping.correctText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering
                    ? Color(NSColor.selectedControlColor).opacity(0.15)
                    : Color(NSColor.windowBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(NSColor.separatorColor).opacity(isHovering ? 0.8 : 0.4), lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { onDelete() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .transition(.opacity)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
        .contextMenu {
            Button("编辑...") { onEdit() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Edit Sheet

enum CustomWordEditMode: Identifiable {
    case add
    case edit(CustomWord)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let word): return word.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .add: return "添加词条"
        case .edit: return "编辑词条"
        }
    }

    var buttonTitle: String {
        switch self {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}

struct CustomWordEditSheet: View {
    let mode: CustomWordEditMode
    let onSave: (CustomWord) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var wordText: String = ""
    @State private var showDuplicateAlert = false

    private var existingWordId: UUID? {
        if case .edit(let word) = mode {
            return word.id
        }
        return nil
    }

    private var canSave: Bool {
        !wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(mode.title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("词条内容")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    VStack(spacing: 0) {
                        TextField("例如：张三、ByteDance、ChatGPT", text: $wordText)
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

                    Text("添加人名、品牌名、专业术语等词语")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Spacer()

            HStack {
                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(mode.buttonTitle) {
                    saveWord()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 400, height: 220)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if case .edit(let word) = mode {
                wordText = word.word
            }
        }
        .alert("词条已存在", isPresented: $showDuplicateAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请使用不同的词条。")
        }
    }

    private func saveWord() {
        let trimmedWord = wordText.trimmingCharacters(in: .whitespacesAndNewlines)

        if CustomWordStorage.shared.wordExists(trimmedWord, excludingId: existingWordId) {
            showDuplicateAlert = true
            return
        }

        let word: CustomWord
        switch mode {
        case .add:
            word = CustomWord(word: trimmedWord)
        case .edit(let existingWord):
            word = CustomWord(
                id: existingWord.id,
                word: trimmedWord,
                isEnabled: existingWord.isEnabled,
                createdAt: existingWord.createdAt
            )
        }

        onSave(word)
        dismiss()
    }
}

// MARK: - Batch Add Sheet

struct CustomWordBatchAddSheet: View {
    let onComplete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var addedCount: Int?

    private var wordCount: Int {
        parseWords().count
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("批量添加词条")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("输入词条")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    TextEditor(text: $inputText)
                        .font(.system(size: 13))
                        .frame(height: 200)
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

                HStack {
                    Text("每行一个词条，或用逗号、空格分隔")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))

                    Spacer()

                    if wordCount > 0 {
                        Text("识别到 \(wordCount) 个词条")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.leading, 4)

                if let count = addedCount {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("成功添加 \(count) 个词条")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Spacer()

            HStack {
                Spacer()

                Button("关闭") {
                    if let count = addedCount {
                        onComplete(count)
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("添加") {
                    let words = parseWords()
                    let count = CustomWordService.shared.addWords(words)
                    addedCount = count
                    if count > 0 {
                        inputText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(wordCount == 0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func parseWords() -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，、"))
        return inputText
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Mapping Edit Sheet

enum MappingEditMode: Identifiable {
    case add
    case edit(CorrectionMapping)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let m): return m.id.uuidString
        }
    }
}

struct MappingEditSheet: View {
    let mode: MappingEditMode
    let onSave: (CorrectionMapping) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var wrongText: String = ""
    @State private var correctText: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        let w = wrongText.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = correctText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !w.isEmpty && !c.isEmpty && w != c
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "编辑纠错映射" : "添加纠错映射")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("错误写法")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    TextField("语音识别可能出现的错误文本", text: $wrongText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("正确写法")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    TextField("应该纠正为的正确文本", text: $correctText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }

                Text("例如：因有额 → 营业额")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Spacer()

            HStack {
                Spacer()

                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "保存" : "添加") {
                    let w = wrongText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let c = correctText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let mapping: CorrectionMapping
                    if case .edit(let existing) = mode {
                        mapping = CorrectionMapping(id: existing.id, wrongText: w, correctText: c, createdAt: existing.createdAt)
                    } else {
                        mapping = CorrectionMapping(wrongText: w, correctText: c)
                    }
                    onSave(mapping)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if case .edit(let m) = mode {
                wrongText = m.wrongText
                correctText = m.correctText
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CustomWordsPage()
}
