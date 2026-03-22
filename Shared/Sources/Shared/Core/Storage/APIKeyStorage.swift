import Foundation

/// 语音识别服务提供商
public enum SpeechProvider: String, CaseIterable, Identifiable, Sendable {
    case volcEngine = "volcengine"
    case vllm = "vllm"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .volcEngine: return "火山引擎豆包"
        case .vllm: return "vLLM (OpenAI 兼容)"
        }
    }
}

/// 存储语音识别 API 配置（使用 UserDefaults）
@MainActor
public final class APIKeyStorage: Sendable {
    public static let shared = APIKeyStorage()

    private let defaults = UserDefaults.standard

    private enum Keys {
        // 通用
        static let provider = "speech.provider"
        // 火山引擎
        static let apiKey = "volcengine.api.key"
        static let resourceId = "volcengine.resource.id"
        // vLLM
        static let vllmBaseURL = "vllm.base.url"
        static let vllmModelName = "vllm.model.name"
        static let vllmAPIKey = "vllm.api.key"
    }

    public init() {}

    // MARK: - Provider 选择

    public var selectedProvider: SpeechProvider {
        get {
            guard let rawValue = defaults.string(forKey: Keys.provider),
                  let value = SpeechProvider(rawValue: rawValue) else {
                return .volcEngine
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.provider)
        }
    }

    // MARK: - 火山引擎配置

    public var apiKey: String? {
        get { defaults.string(forKey: Keys.apiKey) }
        set { defaults.set(newValue, forKey: Keys.apiKey) }
    }

    /// 资源 ID（模型版本）
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

    // MARK: - vLLM 配置

    public var vllmBaseURL: String {
        get { defaults.string(forKey: Keys.vllmBaseURL) ?? "http://localhost:8000/v1" }
        set { defaults.set(newValue, forKey: Keys.vllmBaseURL) }
    }

    public var vllmModelName: String {
        get { defaults.string(forKey: Keys.vllmModelName) ?? "openai/whisper-large-v3" }
        set { defaults.set(newValue, forKey: Keys.vllmModelName) }
    }

    public var vllmAPIKey: String? {
        get { defaults.string(forKey: Keys.vllmAPIKey) }
        set { defaults.set(newValue, forKey: Keys.vllmAPIKey) }
    }

    // MARK: - 状态检查

    public var isConfigured: Bool {
        switch selectedProvider {
        case .volcEngine:
            guard let apiKey else { return false }
            return !apiKey.isEmpty
        case .vllm:
            return !vllmBaseURL.isEmpty && !vllmModelName.isEmpty
        }
    }

    // MARK: - 保存

    public func save(apiKey: String) {
        self.apiKey = apiKey
    }

    public func save(resourceId: VolcEngineResourceId) {
        self.resourceId = resourceId
    }

    public func save(vllmBaseURL: String) {
        self.vllmBaseURL = vllmBaseURL
    }

    public func save(vllmModelName: String) {
        self.vllmModelName = vllmModelName
    }

    public func save(vllmAPIKey: String?) {
        self.vllmAPIKey = vllmAPIKey
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.apiKey)
        defaults.removeObject(forKey: Keys.resourceId)
        defaults.removeObject(forKey: Keys.vllmBaseURL)
        defaults.removeObject(forKey: Keys.vllmModelName)
        defaults.removeObject(forKey: Keys.vllmAPIKey)
    }
}
