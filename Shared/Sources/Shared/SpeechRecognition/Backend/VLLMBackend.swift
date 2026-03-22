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

    private var audioBuffer = Data()
    private var continuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private let session: URLSession
    private var sequenceCounter: Int32 = 0

    init(baseURL: String, modelName: String, apiKey: String?) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.apiKey = apiKey
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
            let text = try await postTranscription(wavData: wavData)
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
        // 构建 URL: {baseURL}/audio/transcriptions
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            throw SpeechRecognitionError.invalidBaseURL
        }

        // 构建 multipart 请求体
        var form = MultipartFormData()
        form.addFile(name: "file", fileName: "audio.wav", mimeType: "audio/wav", data: wavData)
        form.addField(name: "model", value: modelName)
        // response_format: 默认使用 json（简单格式 {"text": "..."}）

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // 长音频可能需要较长处理时间

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = form.finalize()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.connectionFailed("无效的服务器响应")
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw SpeechRecognitionError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        // 解析 OpenAI 格式响应
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
