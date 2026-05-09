import Foundation

/// 语音识别服务提供商
public enum SpeechProvider: String, CaseIterable, Sendable {
    case volcengine
    case qwen

    public static let `default`: SpeechProvider = .volcengine

    public var displayName: String {
        switch self {
        case .volcengine: return "火山引擎豆包"
        case .qwen: return "阿里云千问"
        }
    }
}

/// 千问语音识别接入地域
public enum QwenRegion: String, CaseIterable, Sendable {
    /// 中国内地（北京）
    case beijing
    /// 国际（新加坡）
    case singapore

    public static let `default`: QwenRegion = .beijing

    public var displayName: String {
        switch self {
        case .beijing: return "中国内地（北京）"
        case .singapore: return "国际（新加坡）"
        }
    }

    public var baseURL: String {
        switch self {
        case .beijing: return "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
        case .singapore: return "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime"
        }
    }
}

/// 千问 ASR 模型
public enum QwenModel: String, CaseIterable, Sendable {
    /// 稳定版
    case qwen3AsrFlashRealtime = "qwen3-asr-flash-realtime"
    /// 最新快照版
    case qwen3AsrFlashRealtime20260210 = "qwen3-asr-flash-realtime-2026-02-10"
    /// 历史快照版
    case qwen3AsrFlashRealtime20251027 = "qwen3-asr-flash-realtime-2025-10-27"

    public static let `default`: QwenModel = .qwen3AsrFlashRealtime

    public var displayName: String {
        switch self {
        case .qwen3AsrFlashRealtime: return "qwen3-asr-flash-realtime（稳定版）"
        case .qwen3AsrFlashRealtime20260210: return "qwen3-asr-flash-realtime-2026-02-10"
        case .qwen3AsrFlashRealtime20251027: return "qwen3-asr-flash-realtime-2025-10-27"
        }
    }
}
