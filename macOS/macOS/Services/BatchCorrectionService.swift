import Foundation
import Shared

/// 纠错结果状态
enum CorrectionStatus {
    case pending
    case accepted
    case rejected
}

/// 单条纠错结果
struct CorrectionResult: Identifiable {
    let id: UUID
    let originalText: String
    var correctedText: String
    let timestamp: Date
    var status: CorrectionStatus = .pending
}

/// 批量纠错编排服务 — 协调 AI 服务、存储和 UI 状态
@Observable
@MainActor
final class BatchCorrectionService {
    static let shared = BatchCorrectionService()

    enum State: Equatable {
        case idle
        case correcting(progress: Double)
        case reviewing
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.correcting(let a), .correcting(let b)): return a == b
            case (.reviewing, .reviewing): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var results: [CorrectionResult] = []
    private(set) var extractedMappings: [CorrectionMappingResult] = []
    private(set) var isExtractingMappings = false
    private(set) var mappingsSaved = false
    private var correctionTask: Task<Void, Never>?
    private var sourceRecords: [HistoryRecord] = []

    private init() {}

    /// 开始批量纠错
    func startCorrection(records: [HistoryRecord], context: String = "") {
        // 只纠错 textInput 类型、有文本、尚未纠错的记录
        let candidates = records.filter {
            $0.actionType == .textInput
            && !$0.transcribedText.isEmpty
            && $0.correctedText == nil
        }

        guard !candidates.isEmpty else {
            state = .error("没有需要纠错的记录")
            return
        }

        sourceRecords = candidates
        state = .correcting(progress: 0)

        let inputs = candidates.map {
            BatchCorrectionInput(id: $0.id, text: $0.transcribedText)
        }

        let dictionary = CustomWordStorage.shared.getEnabledWords()
        let existingMappings = CorrectionMappingStorage.shared.mappings.map {
            (wrong: $0.wrongText, correct: $0.correctText)
        }

        correctionTask = Task {
            do {
                let corrections = try await AIBatchCorrectionService.shared.correctBatch(inputs, context: context, dictionary: dictionary, mappings: existingMappings) { [weak self] progress in
                    self?.state = .correcting(progress: progress)
                }

                if corrections.isEmpty {
                    state = .error("所有记录已经正确，无需纠错")
                    return
                }

                // 构建审核列表（仅包含有变化的记录）
                results = candidates.compactMap { record in
                    guard let corrected = corrections[record.id] else { return nil }
                    return CorrectionResult(
                        id: record.id,
                        originalText: record.transcribedText,
                        correctedText: corrected,
                        timestamp: record.timestamp
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }

                state = .reviewing
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error("纠错失败: \(error.localizedDescription)")
            }
        }
    }

    /// 取消纠错
    func cancel() {
        correctionTask?.cancel()
        correctionTask = nil
        state = .idle
        results = []
        sourceRecords = []
        extractedMappings = []
        isExtractingMappings = false
        mappingsSaved = false
    }

    /// 接受单条纠错
    func acceptCorrection(id: UUID) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].status = .accepted

        // 持久化到存储并通知刷新
        if var record = sourceRecords.first(where: { $0.id == id }) {
            record.correctedText = results[index].correctedText
            HistoryStorage.shared.updateRecord(record)
            NotificationCenter.default.post(name: .historyRecordsUpdated, object: nil)
        }
    }

    /// 拒绝单条纠错
    func rejectCorrection(id: UUID) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].status = .rejected
    }

    /// 编辑纠错文本
    func editCorrection(id: UUID, newText: String) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].correctedText = newText
    }

    /// 全部接受
    func acceptAll() {
        var updatedRecords: [HistoryRecord] = []

        for i in results.indices where results[i].status == .pending {
            results[i].status = .accepted

            if var record = sourceRecords.first(where: { $0.id == results[i].id }) {
                record.correctedText = results[i].correctedText
                updatedRecords.append(record)
            }
        }

        if !updatedRecords.isEmpty {
            HistoryStorage.shared.updateRecords(updatedRecords)
        }
    }

    /// 关闭审核（重置状态）
    func dismiss() {
        correctionTask?.cancel()
        correctionTask = nil
        state = .idle
        results = []
        sourceRecords = []
        extractedMappings = []
        isExtractingMappings = false
        mappingsSaved = false
    }

    // MARK: - 映射提炼

    /// 从已接受的纠错中提炼映射
    func extractMappings() {
        let acceptedPairs = results
            .filter { $0.status == .accepted }
            .map { (original: $0.originalText, corrected: $0.correctedText) }

        guard !acceptedPairs.isEmpty else { return }

        isExtractingMappings = true
        mappingsSaved = false

        Task {
            do {
                let mappings = try await AIBatchCorrectionService.shared.extractMappings(from: acceptedPairs)
                extractedMappings = mappings
            } catch {
                extractedMappings = []
            }
            isExtractingMappings = false
        }
    }

    /// 保存提炼的映射到存储
    func saveExtractedMappings() {
        let toSave = extractedMappings.map {
            CorrectionMapping(wrongText: $0.wrongText, correctText: $0.correctText)
        }
        CorrectionMappingStorage.shared.addMappings(toSave)
        mappingsSaved = true
    }

    /// 移除单条提炼的映射
    func removeExtractedMapping(at index: Int) {
        guard index >= 0, index < extractedMappings.count else { return }
        extractedMappings.remove(at: index)
    }

    // MARK: - 统计

    var pendingCount: Int { results.filter { $0.status == .pending }.count }
    var acceptedCount: Int { results.filter { $0.status == .accepted }.count }
    var rejectedCount: Int { results.filter { $0.status == .rejected }.count }
}
