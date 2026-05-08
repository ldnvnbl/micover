import Foundation

/// 内部统一的语音识别引擎抽象，用于支持多家服务商
@MainActor
protocol SpeechRecognitionEngine: AnyObject {
    var isConnected: Bool { get }
    var connectionStatus: String { get }
    var isAPIKeyConfigured: Bool { get }
    var corpusContextProvider: (() -> CorpusContext?)? { get set }

    func testConnection() async throws
    func startSession() async throws -> AsyncStream<SpeechRecognitionResult>
    func sendAudioData(_ data: Data, isLast: Bool) async throws
    func disconnect() async
}
