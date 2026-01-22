import Foundation
import Observation

/// 字节跳动语音识别服务
@Observable
@MainActor
public final class SpeechRecognitionService {
    public private(set) var isConnected = false
    public private(set) var connectionStatus = "未连接"

    private let apiKeyStorage: APIKeyStorage
    private let keychainManager: KeychainManager
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var resultContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private var currentSeq: Int32 = 1

    /// 热词 JSON 字符串提供者
    /// 外部可以设置此闭包来动态提供热词
    public var hotwordsProvider: (() -> String?)?
    
    public init(apiKeyStorage: APIKeyStorage, keychainManager: KeychainManager) {
        self.apiKeyStorage = apiKeyStorage
        self.keychainManager = keychainManager
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Public API
    
    /// 检查是否已配置 API Key
    public var isAPIKeyConfigured: Bool {
        apiKeyStorage.isConfigured
    }
    
    /// 测试 API Key 是否有效
    public func testConnection() async throws {
        guard apiKeyStorage.isConfigured else {
            throw SpeechRecognitionError.notConfigured
        }
        
        // 重置序号
        currentSeq = 1
        
        // 建立连接
        try await connect()
        
        // 发送 FullClientRequest
        try await sendFullClientRequest()
        
        // 等待服务端确认响应（带超时）
        let response = try await withTimeout(seconds: 10) {
            try await self.receiveOneMessage()
        }
        
        // 断开连接
        await disconnect()
        
        // 检查响应
        if response.code != 0 {
            throw SpeechRecognitionError.serverError(
                code: response.code,
                message: response.payload?.error
            )
        }
    }
    
    /// 开始语音识别会话
    public func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        guard apiKeyStorage.isConfigured else {
            throw SpeechRecognitionError.notConfigured
        }
        
        // 重置序号
        currentSeq = 1
        
        // 连接
        try await connect()
        
        // 发送 FullClientRequest
        try await sendFullClientRequest()
        
        // 等待确认
        _ = try await receiveOneMessage()
        
        // 创建结果流
        return AsyncStream { continuation in
            self.resultContinuation = continuation
            
            // 开始接收消息
            Task {
                await self.receiveMessages()
            }
        }
    }
    
    /// 发送音频数据
    public func sendAudioData(_ data: Data, isLast: Bool = false) async throws {
        guard isConnected else {
            throw SpeechRecognitionError.notConnected
        }
        
        let seq = isLast ? -currentSeq : currentSeq
        if !isLast {
            currentSeq += 1
        }
        
        guard let requestData = SpeechProtocolCodec.buildAudioOnlyRequest(
            seq: seq,
            audioData: data
        ) else {
            throw SpeechRecognitionError.compressionFailed
        }
        
        try await webSocketTask?.send(.data(requestData))
        
        if isLast {
            print("📤 Sent final audio packet (seq=\(seq))")
        }
    }
    
    /// 断开连接
    public func disconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = "已断开"
        resultContinuation?.finish()
        resultContinuation = nil
    }
    
    // MARK: - Private
    
    private func connect() async throws {
        let url = SpeechProtocol.apiURL
        var request = URLRequest(url: url)
        
        // 添加认证 headers
        request.setValue(apiKeyStorage.resourceId.rawValue, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue(apiKeyStorage.apiKey ?? "", forHTTPHeaderField: "X-Api-Key")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isConnected = true
        connectionStatus = "已连接"
        
        print("🔌 WebSocket connected to \(url)")
    }
    
    private func sendFullClientRequest() async throws {
        let deviceId = try keychainManager.getOrCreateDeviceID()

        // 获取热词 JSON（如果有提供者）
        let hotwordsJSON = hotwordsProvider?()

        // Debug: 打印热词配置状态
        if let hotwords = hotwordsJSON {
            print("🔥 Hotwords JSON from provider: \(hotwords)")
        } else {
            print("🔥 No hotwords configured")
        }

        let requestMeta = RequestMeta.bigModelWithHotwords(hotwordsJSON)

        let payload = FullClientRequestPayload(
            user: UserMeta(uid: deviceId, platform: "macOS"),
            audio: .defaultPCM,
            request: requestMeta
        )

        let seq = currentSeq
        currentSeq += 1

        let requestData = try SpeechProtocolCodec.buildFullClientRequest(
            seq: seq,
            payload: payload
        )

        try await webSocketTask?.send(.data(requestData))
        if let hotwords = hotwordsJSON {
            print("📤 Sent FullClientRequest with hotwords (seq=\(seq)): \(hotwords)")
        } else {
            print("📤 Sent FullClientRequest (seq=\(seq))")
        }
    }
    
    private func receiveOneMessage() async throws -> SpeechProtocolCodec.ParsedResponse {
        guard let task = webSocketTask else {
            throw SpeechRecognitionError.notConnected
        }
        
        let message = try await task.receive()
        
        switch message {
        case .data(let data):
            guard let response = SpeechProtocolCodec.parseResponse(data) else {
                throw SpeechRecognitionError.protocolError("无法解析响应")
            }
            print("📥 Received response: code=\(response.code), isLast=\(response.isLastPackage)")
            return response
        case .string(let text):
            print("⚠️ Received unexpected text message: \(text)")
            throw SpeechRecognitionError.protocolError("收到意外的文本消息")
        @unknown default:
            throw SpeechRecognitionError.protocolError("未知消息类型")
        }
    }
    
    private func receiveMessages() async {
        guard let task = webSocketTask else { return }
        
        do {
            while isConnected {
                let message = try await task.receive()
                
                switch message {
                case .data(let data):
                    if let response = SpeechProtocolCodec.parseResponse(data) {
                        handleResponse(response)
                    }
                default:
                    break
                }
            }
        } catch {
            // 忽略主动取消导致的错误
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("🔌 WebSocket connection closed")
                return
            }
            
            print("❌ WebSocket receive error: \(error)")
            Task {
                await self.disconnect()
            }
        }
    }
    
    private func handleResponse(_ response: SpeechProtocolCodec.ParsedResponse) {
        // 检查错误
        if response.code != 0 {
            let errorMessage = response.payload?.error ?? "未知错误"
            print("❌ Server error: code=\(response.code), message=\(errorMessage)")
            
            // 创建包含错误的结果
            let error = SpeechRecognitionError.serverError(code: response.code, message: errorMessage)
            let errorResult = SpeechRecognitionResult(
                text: "",
                isLastPackage: true,
                sequence: response.sequence,
                error: error
            )
            
            // 发送错误结果并结束流
            resultContinuation?.yield(errorResult)
            resultContinuation?.finish()
            
            // 断开连接
            Task {
                await disconnect()
            }
            return
        }
        
        // 提取识别文本
        let text = response.payload?.result?.text ?? ""
        
        let result = SpeechRecognitionResult(
            text: text,
            isLastPackage: response.isLastPackage,
            sequence: response.sequence
        )
        
        if !text.isEmpty || response.isLastPackage {
            print("📝 Recognition result: \"\(text)\" (isLast=\(response.isLastPackage))")
        }
        
        resultContinuation?.yield(result)
        
        // 如果是最后一个包，结束流
        if response.isLastPackage {
            resultContinuation?.finish()
            Task {
                await disconnect()
            }
        }
    }
    
    // MARK: - Utility
    
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SpeechRecognitionError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
