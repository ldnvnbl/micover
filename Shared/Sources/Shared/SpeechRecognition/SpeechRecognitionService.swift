import Foundation
import Observation

/// 语音识别服务的对外门面，根据用户在 `APIKeyStorage` 中选择的服务商
/// 自动路由到对应的引擎实现（火山引擎豆包 / 阿里云千问）
@Observable
@MainActor
public final class SpeechRecognitionService {
    public private(set) var isConnected = false
    public private(set) var connectionStatus = "未连接"

    /// Corpus 上下文提供者（热词 + 对话上下文）
    /// 当前仅火山引擎引擎使用；千问引擎会忽略
    public var corpusContextProvider: (() -> CorpusContext?)? {
        didSet { volcEngine.corpusContextProvider = corpusContextProvider }
    }

    private let apiKeyStorage: APIKeyStorage
    private let volcEngine: VolcEngineSpeechEngine
    private let qwenEngine: QwenSpeechEngine
    private var activeEngine: SpeechRecognitionEngine?
    private var bridgeTask: Task<Void, Never>?

    public init(apiKeyStorage: APIKeyStorage, keychainManager: KeychainManager) {
        self.apiKeyStorage = apiKeyStorage
        self.volcEngine = VolcEngineSpeechEngine(apiKeyStorage: apiKeyStorage, keychainManager: keychainManager)
        self.qwenEngine = QwenSpeechEngine(apiKeyStorage: apiKeyStorage)
    }

    // MARK: - Public API

    /// 当前选择的服务商对应的 API Key 是否已配置
    public var isAPIKeyConfigured: Bool {
        currentEngine.isAPIKeyConfigured
    }

    /// 测试当前服务商的连接
    public func testConnection() async throws {
        let engine = currentEngine
        activeEngine = engine
        try await engine.testConnection()
    }

    /// 开始语音识别会话
    public func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        let engine = currentEngine
        activeEngine = engine

        let upstream = try await engine.startSession()
        isConnected = true
        connectionStatus = "已连接"

        return AsyncStream { continuation in
            self.bridgeTask?.cancel()
            self.bridgeTask = Task { [weak self] in
                for await result in upstream {
                    continuation.yield(result)
                }
                continuation.finish()
                await MainActor.run {
                    guard let self else { return }
                    self.isConnected = false
                    self.connectionStatus = "已断开"
                }
            }
        }
    }

    /// 发送音频数据
    public func sendAudioData(_ data: Data, isLast: Bool = false) async throws {
        guard let activeEngine else {
            throw SpeechRecognitionError.notConnected
        }
        try await activeEngine.sendAudioData(data, isLast: isLast)
    }

    /// 断开连接
    public func disconnect() async {
        await activeEngine?.disconnect()
        bridgeTask?.cancel()
        bridgeTask = nil
        activeEngine = nil
        isConnected = false
        connectionStatus = "已断开"
    }

    // MARK: - Private

    private var currentEngine: SpeechRecognitionEngine {
        switch apiKeyStorage.provider {
        case .volcengine: return volcEngine
        case .qwen: return qwenEngine
        }
    }
}
