import Foundation

/// 存储火山引擎语音识别 API Key 和配置（使用 UserDefaults）
@MainActor
public final class APIKeyStorage: Sendable {
    public static let shared = APIKeyStorage()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let apiKey = "volcengine.api.key"
        static let resourceId = "volcengine.resource.id"
    }
    
    public init() {}
    
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
    
    public var isConfigured: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty
    }
    
    public func save(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func save(resourceId: VolcEngineResourceId) {
        self.resourceId = resourceId
    }
    
    public func clear() {
        defaults.removeObject(forKey: Keys.apiKey)
        defaults.removeObject(forKey: Keys.resourceId)
    }
}
