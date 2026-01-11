import Foundation

/// 火山引擎豆包语音识别模型资源 ID
public enum VolcEngineResourceId: String, CaseIterable, Sendable {
    /// 豆包 1.0 小时版
    case bigasr_duration = "volc.bigasr.sauc.duration"
    /// 豆包 1.0 并发版
    case bigasr_concurrent = "volc.bigasr.sauc.concurrent"
    /// 豆包 2.0 小时版
    case seedasr_duration = "volc.seedasr.sauc.duration"
    /// 豆包 2.0 并发版
    case seedasr_concurrent = "volc.seedasr.sauc.concurrent"
    
    /// 默认值
    public static let `default`: VolcEngineResourceId = .seedasr_duration
    
    /// 显示名称
    public var displayName: String {
        switch self {
        case .bigasr_duration: return "豆包 1.0 小时版"
        case .bigasr_concurrent: return "豆包 1.0 并发版"
        case .seedasr_duration: return "豆包 2.0 小时版"
        case .seedasr_concurrent: return "豆包 2.0 并发版"
        }
    }
}

/// 字节跳动语音识别二进制协议常量
public enum SpeechProtocol {
    public static let protocolVersion: UInt8 = 0x01
    public static let headerSize: UInt8 = 0x01  // 1 个 4-byte 单位
    
    /// WebSocket API URL
    public static let apiURL = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream")!
    
    /// 音频分段间隔（毫秒）
    public static let segmentDurationMs: Int = 200
    
    /// 消息类型
    public enum MessageType: UInt8 {
        case fullClientRequest = 0x01
        case audioOnlyRequest = 0x02
        case fullServerResponse = 0x09
        case serverErrorResponse = 0x0F
    }
    
    /// 消息标志位
    public enum MessageFlags: UInt8 {
        case none = 0x00
        case positiveSequence = 0x01
        case negativeSequence = 0x02
        case negativeWithSequence = 0x03
    }
    
    /// 序列化类型
    public enum SerializationType: UInt8 {
        case none = 0x00
        case json = 0x01
    }
    
    /// 压缩类型
    public enum CompressionType: UInt8 {
        case none = 0x00
        case gzip = 0x01
    }
}
