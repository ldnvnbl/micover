import Foundation

/// 语音识别后端协议（内部使用）
/// 每个后端负责将其原生响应转换为统一的 SpeechRecognitionResult。
/// 后端实例在 @MainActor 的 SpeechRecognitionService 内创建和持有。
@MainActor
protocol SpeechBackend {
    /// 开始识别会话，返回结果流
    func startSession() async throws -> AsyncStream<SpeechRecognitionResult>

    /// 发送音频数据
    /// - 流式后端（火山引擎）：立即通过 WebSocket 发送
    /// - 批量后端（vLLM）：缓存到内存 buffer
    func sendAudioData(_ data: Data) async throws

    /// 完成音频输入
    /// - 流式后端：发送结束包
    /// - 批量后端：组装 WAV，POST 到服务器，将结果 yield 到 stream
    func finishAudio() async throws

    /// 测试连接是否可用
    func testConnection() async throws

    /// 断开/清理
    func disconnect() async
}
