import SwiftUI

/// 个人词库管理页面
struct CustomWordsPage: View {
    @State private var words: [CustomWord] = []
    @State private var showAddSheet = false
    @State private var showBatchAddSheet = false
    @State private var showDeleteAlert = false
    @State private var showDeleteAllAlert = false
    @State private var wordToEdit: CustomWord?
    @State private var wordToDelete: CustomWord?

    var body: some View {
        VStack(spacing: 0) {
            // 固定区域
            VStack(alignment: .leading, spacing: 16) {
                // 标题行：自定义词典 + 按钮
                headerSection

                // 词条列表卡片
                if words.isEmpty {
                    emptyStateView
                } else {
                    wordListCard
                }

                // 使用提示
                usageTipsView
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
            loadWords()
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
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                wordToDelete = nil
            }
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
        .alert("确认清空", isPresented: $showDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                CustomWordService.shared.deleteAllWords()
                loadWords()
            }
        } message: {
            Text("确定要清空个人词库吗？此操作不可撤销。")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("个人词库")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("添加人名、品牌名等词语，提高识别准确率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // 批量添加按钮
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

                // 添加按钮
                Button {
                    showAddSheet = true
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("词库为空")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("点击右上角「添加」按钮添加词条")
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

    // MARK: - Word List Card

    private var wordListCard: some View {
        VStack(spacing: 0) {
            // 统计信息和清空按钮
            HStack {
                let enabledCount = words.filter { $0.isEnabled }.count
                HStack(spacing: 0) {
                    Text("共 ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(words.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    Text(" 个词条，")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(enabledCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    Text(" 个已启用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("清空全部") {
                    showDeleteAllAlert = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 16)

            // 词条列表
            VStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                    CustomWordRow(
                        word: word,
                        onEdit: {
                            wordToEdit = word
                        },
                        onDelete: {
                            wordToDelete = word
                            showDeleteAlert = true
                        },
                        onToggle: {
                            CustomWordService.shared.toggleEnabled(word)
                            loadWords()
                        }
                    )

                    if index < words.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 4)
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

    // MARK: - Usage Tips

    private var usageTipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("使用提示", systemImage: "lightbulb")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                tipRow("添加容易被语音识别错误的词语，如人名、品牌名、专业术语")
                tipRow("词条启用后，会在每次语音识别时自动生效")
                tipRow("建议添加 2-4 字的词语效果最佳，避免添加过长的句子")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.05))
        )
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Methods

    private func loadWords() {
        words = CustomWordService.shared.words
    }
}

// MARK: - Custom Word Row

struct CustomWordRow: View {
    let word: CustomWord
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false
    @State private var isHoveringEdit = false
    @State private var isHoveringDelete = false

    var body: some View {
        HStack(spacing: 12) {
            // 词条内容
            Text(word.word)
                .font(.system(size: 14))
                .foregroundColor(word.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Toggle 开关（始终显示）
            Toggle("", isOn: Binding(
                get: { word.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            // 编辑/删除按钮（Hover 时显示）
            HStack(spacing: 4) {
                // 编辑按钮
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(isHoveringEdit ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHoveringEdit ? Color(NSColor.controlColor) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("编辑")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHoveringEdit = hovering
                    }
                }

                // 删除按钮
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(isHoveringDelete ? .red : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHoveringDelete ? Color.red.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("删除")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHoveringDelete = hovering
                    }
                }
            }
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.accentColor.opacity(0.08) : Color.clear)
                .padding(.horizontal, 8)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
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
            // Header
            Text(mode.title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Content
            VStack(alignment: .leading, spacing: 20) {
                // 词条输入
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

            // Footer
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

        // 检查词条唯一性
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
            // Header
            Text("批量添加词条")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Content
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

            // Footer
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
        // 支持换行、逗号、空格分隔
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，、"))
        return inputText
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Preview

#Preview {
    CustomWordsPage()
}
