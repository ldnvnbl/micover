import Foundation

/// 阿里云千问 ASR Realtime 语音识别引擎
///
/// 使用 OpenAI Realtime 兼容协议，通过 WebSocket 收发 JSON 事件：
/// - 客户端发送 `session.update` 配置 → `input_audio_buffer.append` 推送音频 → `session.finish` 结束
/// - 服务端返回 `conversation.item.input_audio_transcription.text`（增量）/ `.completed`（句末）/ `session.finished`（最终）
@MainActor
final class QwenSpeechEngine: SpeechRecognitionEngine {
    private(set) var isConnected = false
    private(set) var connectionStatus = "未连接"

    /// Qwen ASR 不支持 corpus 上下文，此属性仅用于满足协议要求
    var corpusContextProvider: (() -> CorpusContext?)?

    private let apiKeyStorage: APIKeyStorage
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var resultContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private var receiveTask: Task<Void, Never>?
    private var sequence: Int32 = 0

    init(apiKeyStorage: APIKeyStorage) {
        self.apiKeyStorage = apiKeyStorage
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SpeechRecognitionEngine

    var isAPIKeyConfigured: Bool {
        apiKeyStorage.isQwenConfigured
    }

    func testConnection() async throws {
        guard isAPIKeyConfigured else {
            throw SpeechRecognitionError.notConfigured
        }

        try await connect()
        try await sendSessionUpdate()

        do {
            try await withTimeout(seconds: 10) {
                try await self.waitForSessionAck()
            }
        } catch {
            await disconnect()
            throw error
        }

        await disconnect()
    }

    func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        guard isAPIKeyConfigured else {
            throw SpeechRecognitionError.notConfigured
        }

        sequence = 0
        try await connect()
        try await sendSessionUpdate()

        return AsyncStream { continuation in
            self.resultContinuation = continuation
            self.receiveTask = Task {
                await self.receiveMessages()
            }
        }
    }

    func sendAudioData(_ data: Data, isLast: Bool = false) async throws {
        guard isConnected, let webSocketTask else {
            throw SpeechRecognitionError.notConnected
        }

        if isLast {
            let event: [String: Any] = [
                "event_id": Self.makeEventID(),
                "type": "session.finish"
            ]
            try await webSocketTask.send(.string(try Self.jsonString(event)))
            return
        }

        guard !data.isEmpty else { return }

        let event: [String: Any] = [
            "event_id": Self.makeEventID(),
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ]
        try await webSocketTask.send(.string(try Self.jsonString(event)))
    }

    func disconnect() async {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = "已断开"
        resultContinuation?.finish()
        resultContinuation = nil
    }

    // MARK: - Private

    private func connect() async throws {
        let apiKey = apiKeyStorage.qwenApiKey ?? ""
        let model = apiKeyStorage.qwenModel.rawValue
        let base = apiKeyStorage.qwenRegion.baseURL

        guard let url = URL(string: "\(base)?model=\(model)") else {
            throw SpeechRecognitionError.connectionFailed("无法构造 Qwen WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        connectionStatus = "已连接"
    }

    private func sendSessionUpdate() async throws {
        guard let webSocketTask else {
            throw SpeechRecognitionError.notConnected
        }

        // 使用服务端 VAD 模式，与官方推荐配置一致
        let event: [String: Any] = [
            "event_id": Self.makeEventID(),
            "type": "session.update",
            "session": [
                "modalities": ["text"],
                "input_audio_format": "pcm",
                "sample_rate": 16000,
                "input_audio_transcription": [
                    "language": "zh"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.0,
                    "silence_duration_ms": 400
                ]
            ]
        ]

        try await webSocketTask.send(.string(try Self.jsonString(event)))
    }

    /// 等待服务端确认 session 已就绪（`session.created` / `session.updated`），
    /// 若收到 `error` 事件则抛出对应错误
    private func waitForSessionAck() async throws {
        guard let task = webSocketTask else {
            throw SpeechRecognitionError.notConnected
        }

        while !Task.isCancelled {
            let message = try await task.receive()
            guard let event = Self.parseEvent(message) else { continue }

            let type = event["type"] as? String ?? ""
            switch type {
            case "session.created", "session.updated":
                return
            case "error":
                let info = event["error"] as? [String: Any]
                let message = info?["message"] as? String ?? "Qwen ASR 返回错误"
                let code = (info?["code"] as? Int) ?? -1
                throw SpeechRecognitionError.serverError(code: code, message: message)
            default:
                continue
            }
        }
        throw SpeechRecognitionError.cancelled
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }

        var lastText = ""

        do {
            while isConnected {
                let message = try await task.receive()
                guard let event = Self.parseEvent(message) else { continue }
                let type = event["type"] as? String ?? ""

                switch type {
                case "session.created", "session.updated", "input_audio_buffer.speech_started", "input_audio_buffer.speech_stopped":
                    continue

                case "conversation.item.input_audio_transcription.text":
                    let text = event["text"] as? String ?? ""
                    let stash = event["stash"] as? String ?? ""
                    let combined = text + stash
                    lastText = combined
                    sequence &+= 1
                    resultContinuation?.yield(
                        SpeechRecognitionResult(text: combined, isLastPackage: false, sequence: sequence)
                    )

                case "conversation.item.input_audio_transcription.completed":
                    if let transcript = event["transcript"] as? String, !transcript.isEmpty {
                        lastText = transcript
                        sequence &+= 1
                        resultContinuation?.yield(
                            SpeechRecognitionResult(text: transcript, isLastPackage: false, sequence: sequence)
                        )
                    }

                case "session.finished":
                    let transcript = (event["transcript"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? lastText
                    sequence &+= 1
                    resultContinuation?.yield(
                        SpeechRecognitionResult(text: transcript, isLastPackage: true, sequence: sequence)
                    )
                    resultContinuation?.finish()
                    resultContinuation = nil
                    Task { await self.disconnect() }
                    return

                case "error":
                    let info = event["error"] as? [String: Any]
                    let message = info?["message"] as? String ?? "Qwen ASR 返回错误"
                    let code = (info?["code"] as? Int) ?? -1
                    let err = SpeechRecognitionError.serverError(code: code, message: message)
                    resultContinuation?.yield(
                        SpeechRecognitionResult(text: "", isLastPackage: true, sequence: sequence, error: err)
                    )
                    resultContinuation?.finish()
                    resultContinuation = nil
                    Task { await self.disconnect() }
                    return

                default:
                    continue
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            print("❌ Qwen WebSocket receive error: \(error)")
            Task { await self.disconnect() }
        }
    }

    // MARK: - JSON helpers

    private static func makeEventID() -> String {
        "event_\(Int(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 0...9999))"
    }

    private static func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let str = String(data: data, encoding: .utf8) else {
            throw SpeechRecognitionError.protocolError("无法序列化事件 JSON")
        }
        return str
    }

    private static func parseEvent(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        let data: Data?
        switch message {
        case .string(let s): data = s.data(using: .utf8)
        case .data(let d): data = d
        @unknown default: data = nil
        }
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        return obj
    }

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
