import Foundation

/// 火山引擎豆包语音识别后端（WebSocket 实时流式）
/// 从 SpeechRecognitionService 提取的原有逻辑，行为完全不变。
@MainActor
final class VolcEngineBackend: SpeechBackend {
    private let apiKeyStorage: APIKeyStorage
    private let keychainManager: KeychainManager
    private let corpusContextProvider: (() -> CorpusContext?)?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var resultContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private var currentSeq: Int32 = 1

    init(
        apiKeyStorage: APIKeyStorage,
        keychainManager: KeychainManager,
        corpusContextProvider: (() -> CorpusContext?)?
    ) {
        self.apiKeyStorage = apiKeyStorage
        self.keychainManager = keychainManager
        self.corpusContextProvider = corpusContextProvider
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SpeechBackend

    func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        guard apiKeyStorage.isConfigured else {
            throw SpeechRecognitionError.notConfigured
        }

        currentSeq = 1

        try await connect()
        try await sendFullClientRequest()

        // 等待服务端确认
        _ = try await receiveOneMessage()

        return AsyncStream { continuation in
            self.resultContinuation = continuation
            Task { @MainActor in
                await self.receiveMessages()
            }
        }
    }

    func sendAudioData(_ data: Data) async throws {
        guard webSocketTask != nil else {
            throw SpeechRecognitionError.notConnected
        }

        let seq = currentSeq
        currentSeq += 1

        guard let requestData = SpeechProtocolCodec.buildAudioOnlyRequest(
            seq: seq,
            audioData: data
        ) else {
            throw SpeechRecognitionError.compressionFailed
        }

        try await webSocketTask?.send(.data(requestData))
    }

    func finishAudio() async throws {
        guard webSocketTask != nil else {
            throw SpeechRecognitionError.notConnected
        }

        let seq = -currentSeq

        guard let requestData = SpeechProtocolCodec.buildAudioOnlyRequest(
            seq: seq,
            audioData: Data()
        ) else {
            throw SpeechRecognitionError.compressionFailed
        }

        try await webSocketTask?.send(.data(requestData))
    }

    func testConnection() async throws {
        guard apiKeyStorage.isConfigured else {
            throw SpeechRecognitionError.notConfigured
        }

        currentSeq = 1

        try await connect()
        try await sendFullClientRequest()

        let response = try await withTimeout(seconds: 10) {
            try await self.receiveOneMessage()
        }

        await disconnect()

        if response.code != 0 {
            throw SpeechRecognitionError.serverError(
                code: response.code,
                message: response.payload?.error
            )
        }
    }

    func disconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        resultContinuation?.finish()
        resultContinuation = nil
    }

    // MARK: - Private: WebSocket

    private func connect() async throws {
        let url = SpeechProtocol.apiURL
        var request = URLRequest(url: url)

        request.setValue(apiKeyStorage.resourceId.rawValue, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue(apiKeyStorage.apiKey ?? "", forHTTPHeaderField: "X-Api-Key")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
    }

    private func sendFullClientRequest() async throws {
        let deviceId = try keychainManager.getOrCreateDeviceID()
        let corpusContext = corpusContextProvider?()
        let requestMeta = RequestMeta.bigModelWithContext(corpusContext)

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
            return response
        case .string(let text):
            print("❌ Received unexpected text message: \(text)")
            throw SpeechRecognitionError.protocolError("收到意外的文本消息")
        @unknown default:
            throw SpeechRecognitionError.protocolError("未知消息类型")
        }
    }

    nonisolated private func receiveMessages() async {
        let task = await webSocketTask
        guard let task else { return }

        do {
            while true {
                let message = try await task.receive()

                switch message {
                case .data(let data):
                    if let response = SpeechProtocolCodec.parseResponse(data) {
                        await handleResponse(response)
                    }
                default:
                    break
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            print("❌ WebSocket receive error: \(error)")
            await disconnect()
        }
    }

    private func handleResponse(_ response: SpeechProtocolCodec.ParsedResponse) {
        if response.code != 0 {
            let errorMessage = response.payload?.error ?? "未知错误"
            print("❌ Server error: code=\(response.code), message=\(errorMessage)")

            let error = SpeechRecognitionError.serverError(code: response.code, message: errorMessage)
            let errorResult = SpeechRecognitionResult(
                text: "",
                isLastPackage: true,
                sequence: response.sequence,
                error: error
            )

            resultContinuation?.yield(errorResult)
            resultContinuation?.finish()

            Task {
                await disconnect()
            }
            return
        }

        let text = response.payload?.result?.text ?? ""

        let result = SpeechRecognitionResult(
            text: text,
            isLastPackage: response.isLastPackage,
            sequence: response.sequence
        )

        resultContinuation?.yield(result)

        if response.isLastPackage {
            resultContinuation?.finish()
            Task {
                await disconnect()
            }
        }
    }

    // MARK: - Utility

    nonisolated private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
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
