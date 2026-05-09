import Foundation

/// 存储火山引擎语音识别 API Key 和配置（使用 UserDefaults）
@MainActor
public final class APIKeyStorage: Sendable {
    public static let shared = APIKeyStorage()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let provider = "speech.provider"
        // 火山引擎
        static let apiKey = "volcengine.api.key"
        static let resourceId = "volcengine.resource.id"
        // 千问
        static let qwenApiKey = "qwen.api.key"
        static let qwenRegion = "qwen.region"
        static let qwenModel = "qwen.model"
    }

    public init() {}

    /// 当前选择的语音识别提供商
    public var provider: SpeechProvider {
        get {
            guard let raw = defaults.string(forKey: Keys.provider),
                  let value = SpeechProvider(rawValue: raw) else {
                return .default
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.provider)
        }
    }

    // MARK: - 火山引擎

    /// 火山引擎 API Key（向后兼容字段名 `apiKey`）
    public var apiKey: String? {
        get { defaults.string(forKey: Keys.apiKey) }
        set { defaults.set(newValue, forKey: Keys.apiKey) }
    }

    /// 火山引擎资源 ID（模型版本）
    public var resourceId: VolcEngineResourceId {
        get {
            guard let rawValue = defaults.string(forKey: Keys.resourceId),
                  let value = VolcEngineResourceId(rawValue: rawValue) else {
                return .default
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.resourceId)
        }
    }

    public var isVolcEngineConfigured: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty
    }

    // MARK: - 千问

    public var qwenApiKey: String? {
        get { defaults.string(forKey: Keys.qwenApiKey) }
        set { defaults.set(newValue, forKey: Keys.qwenApiKey) }
    }

    public var qwenRegion: QwenRegion {
        get {
            guard let raw = defaults.string(forKey: Keys.qwenRegion),
                  let value = QwenRegion(rawValue: raw) else {
                return .default
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.qwenRegion)
        }
    }

    public var qwenModel: QwenModel {
        get {
            guard let raw = defaults.string(forKey: Keys.qwenModel),
                  let value = QwenModel(rawValue: raw) else {
                return .default
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.qwenModel)
        }
    }

    public var isQwenConfigured: Bool {
        guard let key = qwenApiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - 通用

    /// 当前选择的提供商是否已配置
    public var isConfigured: Bool {
        switch provider {
        case .volcengine: return isVolcEngineConfigured
        case .qwen: return isQwenConfigured
        }
    }

    public func save(apiKey: String) {
        self.apiKey = apiKey
    }

    public func save(resourceId: VolcEngineResourceId) {
        self.resourceId = resourceId
    }

    public func save(provider: SpeechProvider) {
        self.provider = provider
    }

    public func save(qwenApiKey: String) {
        self.qwenApiKey = qwenApiKey
    }

    public func save(qwenRegion: QwenRegion) {
        self.qwenRegion = qwenRegion
    }

    public func save(qwenModel: QwenModel) {
        self.qwenModel = qwenModel
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.provider)
        defaults.removeObject(forKey: Keys.apiKey)
        defaults.removeObject(forKey: Keys.resourceId)
        defaults.removeObject(forKey: Keys.qwenApiKey)
        defaults.removeObject(forKey: Keys.qwenRegion)
        defaults.removeObject(forKey: Keys.qwenModel)
    }
}
