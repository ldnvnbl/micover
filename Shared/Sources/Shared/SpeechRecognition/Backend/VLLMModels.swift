import Foundation

/// vLLM OpenAI 兼容 API 的请求/响应模型

/// Transcription 响应（OpenAI 格式）
struct VLLMTranscriptionResponse: Codable, Sendable {
    let text: String
}

/// Models 列表响应（用于测试连接）
struct VLLMModelsResponse: Codable, Sendable {
    let object: String?
    let data: [VLLMModel]?
}

struct VLLMModel: Codable, Sendable {
    let id: String
    let object: String?
}

/// OpenAI 风格的错误响应
struct VLLMErrorResponse: Codable, Sendable {
    let error: VLLMErrorDetail?
}

struct VLLMErrorDetail: Codable, Sendable {
    let message: String?
    let type: String?
    let code: String?
}
