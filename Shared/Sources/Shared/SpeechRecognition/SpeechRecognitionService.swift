import Foundation
import Observation

/// 语音识别服务（统一入口）
/// 内部根据所选 provider 委托给不同的后端实现。
@Observable
@MainActor
public final class SpeechRecognitionService {
    public private(set) var isConnected = false
    public private(set) var connectionStatus = "未连接"
    /// vLLM 批处理模式下，录音结束后正在等待识别结果
    public private(set) var isTranscribing = false

    private let apiKeyStorage: APIKeyStorage
    private let keychainManager: KeychainManager
    private var currentBackend: (any SpeechBackend)?

    /// Corpus 上下文提供者（热词 + 对话上下文）
    /// 仅火山引擎后端使用
    public var corpusContextProvider: (() -> CorpusContext?)?

    public init(apiKeyStorage: APIKeyStorage, keychainManager: KeychainManager) {
        self.apiKeyStorage = apiKeyStorage
        self.keychainManager = keychainManager
    }

    // MARK: - Public API

    /// 检查是否已配置
    public var isAPIKeyConfigured: Bool {
        apiKeyStorage.isConfigured
    }

    /// 当前选择的 provider
    public var selectedProvider: SpeechProvider {
        apiKeyStorage.selectedProvider
    }

    /// 测试连接是否有效
    public func testConnection() async throws {
        let backend = createBackend()
        try await backend.testConnection()
    }

    /// 开始语音识别会话
    public func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        guard apiKeyStorage.isConfigured else {
            throw SpeechRecognitionError.notConfigured
        }

        let backend = createBackend()
        currentBackend = backend

        let stream = try await backend.startSession()

        isConnected = true
        connectionStatus = "已连接"

        return stream
    }

    /// 发送音频数据
    public func sendAudioData(_ data: Data, isLast: Bool = false) async throws {
        guard let backend = currentBackend else {
            throw SpeechRecognitionError.notConnected
        }

        if isLast {
            isTranscribing = selectedProvider == .vllm
            try await backend.finishAudio()
            isTranscribing = false
        } else {
            try await backend.sendAudioData(data)
        }
    }

    /// 断开连接
    public func disconnect() async {
        await currentBackend?.disconnect()
        currentBackend = nil
        isConnected = false
        isTranscribing = false
        connectionStatus = "已断开"
    }

    // MARK: - Private

    private func createBackend() -> any SpeechBackend {
        switch apiKeyStorage.selectedProvider {
        case .volcEngine:
            return VolcEngineBackend(
                apiKeyStorage: apiKeyStorage,
                keychainManager: keychainManager,
                corpusContextProvider: corpusContextProvider
            )
        case .vllm:
            return VLLMBackend(
                baseURL: apiKeyStorage.vllmBaseURL,
                modelName: apiKeyStorage.vllmModelName,
                apiKey: apiKeyStorage.vllmAPIKey,
                apiMode: apiKeyStorage.vllmApiMode
            )
        }
    }
}
