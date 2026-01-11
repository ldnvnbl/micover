import Foundation

/// 语音识别错误类型
public enum SpeechRecognitionError: LocalizedError, Sendable {
    case notConfigured
    case connectionFailed(String)
    case protocolError(String)
    case notConnected
    case compressionFailed
    case serverError(code: Int, message: String?)
    case timeout
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置 API Key"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .protocolError(let message):
            return "协议错误: \(message)"
        case .notConnected:
            return "未连接到服务器"
        case .compressionFailed:
            return "数据压缩失败"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message ?? "未知错误")"
        case .timeout:
            return "请求超时"
        case .cancelled:
            return "操作已取消"
        }
    }
}
