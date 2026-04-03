import Foundation

/// vLLM OpenAI 兼容 API 的请求/响应模型

// MARK: - Chat Completions 请求

/// POST /chat/completions 请求体
struct VLLMChatRequest: Encodable {
    let model: String
    let messages: [VLLMChatMessage]
    let stream: Bool
}

struct VLLMChatMessage: Encodable {
    let role: String
    let content: [VLLMChatContent]
}

struct VLLMChatContent: Encodable {
    let type: String
    let audioUrl: VLLMAudioURL?

    enum CodingKeys: String, CodingKey {
        case type
        case audioUrl = "audio_url"
    }
}

struct VLLMAudioURL: Encodable {
    let url: String
}

// MARK: - Chat Completions 流式响应（SSE）

/// SSE 数据行对应的 JSON chunk
struct VLLMChatStreamChunk: Decodable {
    let choices: [VLLMChatChoice]
}

struct VLLMChatChoice: Decodable {
    let delta: VLLMChatDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct VLLMChatDelta: Decodable {
    let content: String?
    let role: String?
}

// MARK: - Models 列表响应（用于测试连接）

struct VLLMModelsResponse: Codable, Sendable {
    let object: String?
    let data: [VLLMModel]?
}

struct VLLMModel: Codable, Sendable {
    let id: String
    let object: String?
}

// MARK: - Audio Transcriptions 响应

/// POST /audio/transcriptions 响应体
struct VLLMTranscriptionResponse: Decodable {
    let text: String
}

// MARK: - OpenAI 风格错误响应

struct VLLMErrorResponse: Codable, Sendable {
    let error: VLLMErrorDetail?
}

struct VLLMErrorDetail: Codable, Sendable {
    let message: String?
    let type: String?
    let code: String?
}
