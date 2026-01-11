import Foundation

/// 语音识别结果
public struct SpeechRecognitionResult: Sendable {
    public let text: String
    public let isLastPackage: Bool
    public let sequence: Int32
    /// 服务端错误信息（如果有）
    public let error: SpeechRecognitionError?
    
    public init(text: String, isLastPackage: Bool, sequence: Int32, error: SpeechRecognitionError? = nil) {
        self.text = text
        self.isLastPackage = isLastPackage
        self.sequence = sequence
        self.error = error
    }
    
    /// 是否包含错误
    public var hasError: Bool {
        error != nil
    }
}

/// 服务端响应 Payload
public struct SpeechResponsePayload: Codable, Sendable {
    public let audioInfo: AudioInfo?
    public let result: ResultInfo?
    public let error: String?
    
    /// 音频信息
    public struct AudioInfo: Codable, Sendable {
        public let duration: Int?
    }
    
    /// 识别结果信息
    public struct ResultInfo: Codable, Sendable {
        public let text: String?
        public let utterances: [Utterance]?
    }
    
    /// 语句信息
    public struct Utterance: Codable, Sendable {
        public let text: String?
        public let definite: Bool?
        public let startTime: Int?
        public let endTime: Int?
        public let words: [Word]?
        
        enum CodingKeys: String, CodingKey {
            case text, definite, words
            case startTime = "start_time"
            case endTime = "end_time"
        }
    }
    
    /// 词信息
    public struct Word: Codable, Sendable {
        public let text: String?
        public let startTime: Int?
        public let endTime: Int?
        
        enum CodingKeys: String, CodingKey {
            case text
            case startTime = "start_time"
            case endTime = "end_time"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case audioInfo = "audio_info"
        case result
        case error
    }
}
