import SwiftUI
import Shared

/// AI 批量纠错审核 Sheet
struct BatchCorrectionReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let records: [HistoryRecord]

    @State private var correctionModelId: String = BatchCorrectionStorage.shared.correctionModelId
    @State private var correctionContext: String = ""
    @State private var editingId: UUID?
    @State private var editText: String = ""
    @State private var showExistingMappings = false
    @State private var existingMappings: [CorrectionMapping] = CorrectionMappingStorage.shared.mappings

    private var service: BatchCorrectionService { .shared }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 700, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .onDisappear {
            service.dismiss()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("AI 批量纠错")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Circle())
        }
        .padding(20)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch service.state {
        case .idle:
            configView

        case .correcting(let progress):
            progressView(progress: progress)

        case .reviewing:
            reviewList

        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Config (初始状态)

    private var configView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundColor(.accentColor.opacity(0.6))

            Text("使用 AI 大模型对历史记录进行纠错")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Text("纠错模型")
                    .font(.body)
                    .foregroundColor(.secondary)

                TextField("模型 ID", text: $correctionModelId)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onChange(of: correctionModelId) { _, newValue in
                        BatchCorrectionStorage.shared.correctionModelId = newValue
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("背景信息（可选）")
                    .font(.body)
                    .foregroundColor(.secondary)

                TextEditor(text: $correctionContext)
                    .font(.system(size: 13))
                    .frame(width: 450, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if correctionContext.isEmpty {
                            Text("例如：会议主题、专业领域、人名地名等，帮助 AI 更准确地纠错")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            // 已有纠错映射
            if !existingMappings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation { showExistingMappings.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showExistingMappings ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                            Text("纠错映射（\(existingMappings.count) 条，自动应用）")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showExistingMappings {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(existingMappings) { mapping in
                                    HStack(spacing: 8) {
                                        Text(mapping.wrongText)
                                            .font(.system(size: 12))
                                            .foregroundColor(.red.opacity(0.8))
                                            .strikethrough()
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(mapping.correctText)
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                        Spacer()
                                        Button {
                                            CorrectionMappingStorage.shared.removeMapping(id: mapping.id)
                                            existingMappings = CorrectionMappingStorage.shared.mappings
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                        .frame(width: 450, height: min(CGFloat(existingMappings.count) * 24, 80))
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            let candidateCount = records.filter {
                $0.actionType == .textInput && !$0.transcribedText.isEmpty && $0.correctedText == nil
            }.count

            Button {
                service.startCorrection(records: records, context: correctionContext)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("开始纠错（\(candidateCount) 条记录）")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(candidateCount == 0)

            if candidateCount == 0 {
                Text("没有需要纠错的记录（已全部纠正或无文本记录）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress

    private func progressView(progress: Double) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(value: progress, total: 1.0) {
                Text("正在纠错...")
                    .font(.body)
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 300)

            Button("取消") {
                service.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review List

    private var reviewList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(service.results) { result in
                    correctionRow(result)

                    if result.id != service.results.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                // 提炼的纠错映射
                if service.isExtractingMappings {
                    Divider().padding(.vertical, 8)
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在提炼纠错映射...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                } else if !service.extractedMappings.isEmpty {
                    Divider().padding(.vertical, 8)
                    extractedMappingsSection
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var extractedMappingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("提炼的纠错映射")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if service.mappingsSaved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)

            ForEach(Array(service.extractedMappings.enumerated()), id: \.offset) { index, mapping in
                HStack(spacing: 8) {
                    Text(mapping.wrongText)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .strikethrough()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(mapping.correctText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)

                    Spacer()

                    if !service.mappingsSaved {
                        Button {
                            service.removeExtractedMapping(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func correctionRow(_ result: CorrectionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 原文
            HStack(alignment: .top, spacing: 8) {
                Text("原文")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)

                Text(result.originalText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 纠正文本（或编辑框）
            HStack(alignment: .top, spacing: 8) {
                Text("纠正")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, alignment: .trailing)

                if editingId == result.id {
                    VStack(spacing: 6) {
                        TextEditor(text: $editText)
                            .font(.system(size: 13))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            )

                        HStack {
                            Button("确定") {
                                service.editCorrection(id: result.id, newText: editText)
                                editingId = nil
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("取消") {
                                editingId = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(result.correctedText)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // 操作按钮
            HStack(spacing: 8) {
                Spacer()
                    .frame(width: 32)

                statusBadge(result.status)

                Spacer()

                if result.status == .pending {
                    Button {
                        service.acceptCorrection(id: result.id)
                    } label: {
                        Label("接受", systemImage: "checkmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button {
                        service.rejectCorrection(id: result.id)
                    } label: {
                        Label("拒绝", systemImage: "xmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)

                    Button {
                        editText = result.correctedText
                        editingId = result.id
                    } label: {
                        Label("编辑", systemImage: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(result.status == .rejected ? 0.5 : 1.0)
    }

    @ViewBuilder
    private func statusBadge(_ status: CorrectionStatus) -> some View {
        switch status {
        case .pending:
            EmptyView()
        case .accepted:
            Label("已接受", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
        case .rejected:
            Label("已拒绝", systemImage: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.red)
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("重试") {
                    service.startCorrection(records: records, context: correctionContext)
                }
                .buttonStyle(.borderedProminent)

                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if service.state == .reviewing {
                Text("共 \(service.results.count) 条纠错")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if service.acceptedCount > 0 {
                    Text("· 已接受 \(service.acceptedCount)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if service.rejectedCount > 0 {
                    Text("· 已拒绝 \(service.rejectedCount)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if service.state == .reviewing {
                if service.pendingCount > 0 {
                    Button {
                        service.acceptAll()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("全部接受（\(service.pendingCount)）")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if service.acceptedCount > 0 && service.extractedMappings.isEmpty && !service.isExtractingMappings {
                    Button {
                        service.extractMappings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.book.closed")
                            Text("提炼映射")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if !service.extractedMappings.isEmpty && !service.mappingsSaved {
                    Button {
                        service.saveExtractedMappings()
                        existingMappings = CorrectionMappingStorage.shared.mappings
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存映射（\(service.extractedMappings.count)）")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.regular)
                }
            }

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(16)
    }
}
