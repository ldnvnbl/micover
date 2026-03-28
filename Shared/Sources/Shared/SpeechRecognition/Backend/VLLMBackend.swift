import Foundation

// ┌──────────────────────────────────────────────────────────────────┐
// │ Phase 2: vLLM Real-time Streaming via WebSocket                 │
// │                                                                  │
// │ vLLM 正在开发 WebSocket 实时流式 ASR 端点。当该功能可用时，       │
// │ 可创建 VLLMStreamingBackend: SpeechBackend，模式与                │
// │ VolcEngineBackend 相同：                                         │
// │                                                                  │
// │ - startSession() 打开 ws://{baseURL}/v1/realtime                │
// │ - sendAudioData() 通过 WebSocket 实时发送 PCM chunk             │
// │ - AsyncStream 逐步 yield 部分识别结果                            │
// │ - finishAudio() 发送 EOF 帧，等待最终结果                        │
// │                                                                  │
// │ 当前的 SpeechBackend protocol 已完全支持此模式，无需修改          │
// │ SpeechRecognitionService 或 RecordingCoordinator。               │
// │ 只需在 SpeechProvider 中添加新 case 并实例化流式后端即可。       │
// │                                                                  │
// │ 支持的实时模型示例:                                               │
// │ - Voxtral-Mini-4B-Realtime (Mistral, 13 种语言)                 │
// │ - Qwen3-ASR (0.6B/1.7B, 52 种语言, 统一流式/离线)              │
// │                                                                  │
// │ 决策点: 作为独立 provider 选项，还是通过 GET /v1/models          │
// │ 自动检测能力后静默升级为流式模式？                                │
// └──────────────────────────────────────────────────────────────────┘

/// vLLM 语音识别后端（OpenAI 兼容 REST API，批量模式）
///
/// 工作流程：
/// 1. sendAudioData() — 将 PCM chunk 追加到内存 buffer
/// 2. finishAudio()   — buffer → WAV → POST multipart/form-data → 解析结果
/// 3. 结果通过 AsyncStream 以单个 SpeechRecognitionResult yield
@MainActor
final class VLLMBackend: SpeechBackend {
    private let baseURL: String
    private let modelName: String
    private let apiKey: String?
    private let apiMode: VLLMApiMode

    private var audioBuffer = Data()
    private var continuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private let session: URLSession
    private var sequenceCounter: Int32 = 0

    init(baseURL: String, modelName: String, apiKey: String?, apiMode: VLLMApiMode = .audioTranscriptions) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.apiKey = apiKey
        self.apiMode = apiMode
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SpeechBackend

    func startSession() async throws -> AsyncStream<SpeechRecognitionResult> {
        audioBuffer = Data()
        sequenceCounter = 0

        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func sendAudioData(_ data: Data) async throws {
        audioBuffer.append(data)
    }

    func finishAudio() async throws {
        guard !audioBuffer.isEmpty else {
            throw SpeechRecognitionError.audioBufferEmpty
        }

        // PCM S16LE 16kHz mono → WAV
        let wavData = WAVEncoder.encode(
            pcmData: audioBuffer,
            sampleRate: 16000,
            channels: 1,
            bitsPerSample: 16
        )
        audioBuffer = Data()

        do {
            let text: String
            switch apiMode {
            case .audioTranscriptions:
                text = try await postTranscriptionStandard(wavData: wavData)
            case .chatCompletions:
                text = try await postTranscription(wavData: wavData)
            }
            sequenceCounter += 1

            let result = SpeechRecognitionResult(
                text: text,
                isLastPackage: true,
                sequence: sequenceCounter
            )
            continuation?.yield(result)
        } catch {
            let errorResult = SpeechRecognitionResult(
                text: "",
                isLastPackage: true,
                sequence: sequenceCounter,
                error: error as? SpeechRecognitionError ?? .connectionFailed(error.localizedDescription)
            )
            continuation?.yield(errorResult)
        }

        continuation?.finish()
        continuation = nil
    }

    func testConnection() async throws {
        // GET {baseURL}/models 验证连通性
        guard let url = URL(string: "\(baseURL)/models") else {
            throw SpeechRecognitionError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.connectionFailed("无效的服务器响应")
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw SpeechRecognitionError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        // 尝试解析 models 列表以确认是有效的 OpenAI 兼容端点
        let _ = try? JSONDecoder().decode(VLLMModelsResponse.self, from: data)
    }

    func disconnect() async {
        audioBuffer = Data()
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Private: HTTP

    private func postTranscription(wavData: Data) async throws -> String {
        // 构建 URL: {baseURL}/chat/completions
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw SpeechRecognitionError.invalidBaseURL
        }

        // WAV 数据 base64 编码，构建 data URL
        let audioBase64 = wavData.base64EncodedString()
        let audioDataURL = "data:audio/wav;base64,\(audioBase64)"

        // 构建 Chat Completions 请求体
        let chatRequest = VLLMChatRequest(
            model: modelName,
            messages: [
                VLLMChatMessage(
                    role: "user",
                    content: [
                        VLLMChatContent(
                            type: "audio_url",
                            audioUrl: VLLMAudioURL(url: audioDataURL)
                        )
                    ]
                )
            ],
            stream: true
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.connectionFailed("无效的服务器响应")
        }

        guard httpResponse.statusCode == 200 else {
            // 读取全部错误体
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = parseErrorMessage(from: errorData) ?? "HTTP \(httpResponse.statusCode)"
            throw SpeechRecognitionError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        // 解析 SSE 流：每行 "data: {...}" 或 "data: [DONE]"
        var fullText = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard jsonStr != "[DONE]" else { break }
            guard let jsonData = jsonStr.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(VLLMChatStreamChunk.self, from: jsonData)
            else { continue }
            if let content = chunk.choices.first?.delta.content {
                fullText += content
            }
        }

        return fullText
    }

    /// 标准 OpenAI Audio Transcriptions 接口 (POST /audio/transcriptions, multipart/form-data)
    private func postTranscriptionStandard(wavData: Data) async throws -> String {
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            throw SpeechRecognitionError.invalidBaseURL
        }

        var formData = MultipartFormData()
        formData.addFile(name: "file", fileName: "audio.wav", mimeType: "audio/wav", data: wavData)
        formData.addField(name: "model", value: modelName)
        formData.addField(name: "response_format", value: "json")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = formData.finalize()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.connectionFailed("无效的服务器响应")
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw SpeechRecognitionError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let transcription = try JSONDecoder().decode(VLLMTranscriptionResponse.self, from: data)
        return transcription.text
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let errorResponse = try? JSONDecoder().decode(VLLMErrorResponse.self, from: data) {
            return errorResponse.error?.message
        }
        return String(data: data, encoding: .utf8)
    }
}
