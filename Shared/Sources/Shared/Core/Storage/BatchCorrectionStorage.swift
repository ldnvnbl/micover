import Foundation

/// 批量纠错配置存储 — 仅存储纠错专用模型 ID，其余复用 AIOptimizationStorage
@MainActor
public final class BatchCorrectionStorage: Sendable {
    public static let shared = BatchCorrectionStorage()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let correctionModelId = "ai.batchCorrection.modelId"
    }

    public init() {}

    /// 纠错模型 ID，默认回退到 AI 优化模型
    public var correctionModelId: String {
        get { defaults.string(forKey: Keys.correctionModelId) ?? AIOptimizationStorage.shared.modelId }
        set { defaults.set(newValue, forKey: Keys.correctionModelId) }
    }
}
