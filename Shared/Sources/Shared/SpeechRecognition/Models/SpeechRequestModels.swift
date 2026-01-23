import Foundation

/// 用户元信息
public struct UserMeta: Codable, Sendable {
    public let uid: String
    public let did: String?
    public let platform: String?
    public let sdkVersion: String?
    public let appVersion: String?
    
    public init(
        uid: String,
        did: String? = nil,
        platform: String? = nil,
        sdkVersion: String? = nil,
        appVersion: String? = nil
    ) {
        self.uid = uid
        self.did = did
        self.platform = platform
        self.sdkVersion = sdkVersion
        self.appVersion = appVersion
    }
    
    enum CodingKeys: String, CodingKey {
        case uid
        case did
        case platform
        case sdkVersion = "sdk_version"
        case appVersion = "app_version"
    }
}

/// 音频元信息
public struct AudioMeta: Codable, Sendable {
    public let format: String
    public let codec: String
    public let rate: Int
    public let bits: Int
    public let channel: Int
    
    public init(format: String, codec: String, rate: Int, bits: Int, channel: Int) {
        self.format = format
        self.codec = codec
        self.rate = rate
        self.bits = bits
        self.channel = channel
    }
    
    /// 默认 PCM 16kHz 16bit 单声道配置
    public static let defaultPCM = AudioMeta(
        format: "pcm",
        codec: "raw",
        rate: 16000,
        bits: 16,
        channel: 1
    )
}

/// 语料库元信息（可选）
public struct CorpusMeta: Codable, Sendable {
    public let boostingTableName: String?
    public let correctTableName: String?
    public let context: String?
    
    public init(
        boostingTableName: String? = nil,
        correctTableName: String? = nil,
        context: String? = nil
    ) {
        self.boostingTableName = boostingTableName
        self.correctTableName = correctTableName
        self.context = context
    }
    
    enum CodingKeys: String, CodingKey {
        case boostingTableName = "boosting_table_name"
        case correctTableName = "correct_table_name"
        case context
    }
}

/// 请求元信息
public struct RequestMeta: Codable, Sendable {
    public let modelName: String
    public let enableItn: Bool
    public let enablePunc: Bool
    public let enableDdc: Bool
    public let showUtterances: Bool
    public let enableNonstream: Bool
    public let corpus: CorpusMeta?
    
    public init(
        modelName: String,
        enableItn: Bool,
        enablePunc: Bool,
        enableDdc: Bool,
        showUtterances: Bool,
        enableNonstream: Bool,
        corpus: CorpusMeta? = nil
    ) {
        self.modelName = modelName
        self.enableItn = enableItn
        self.enablePunc = enablePunc
        self.enableDdc = enableDdc
        self.showUtterances = showUtterances
        self.enableNonstream = enableNonstream
        self.corpus = corpus
    }
    
    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case enableItn = "enable_itn"
        case enablePunc = "enable_punc"
        case enableDdc = "enable_ddc"
        case showUtterances = "show_utterances"
        case enableNonstream = "enable_nonstream"
        case corpus
    }
    
    /// 默认大模型配置
    public static let defaultBigModel = RequestMeta(
        modelName: "bigmodel",
        enableItn: true,
        enablePunc: true,
        enableDdc: false,
        showUtterances: true,
        enableNonstream: false,
        corpus: nil
    )

    /// 创建带热词的大模型配置
    /// - Parameter hotwordsJSON: 热词 JSON 字符串，格式：{"hotwords":[{"word":"词条1"}, {"word":"词条2"}]}
    public static func bigModelWithHotwords(_ hotwordsJSON: String?) -> RequestMeta {
        guard let hotwordsJSON = hotwordsJSON, !hotwordsJSON.isEmpty else {
            return defaultBigModel
        }
        return RequestMeta(
            modelName: "bigmodel",
            enableItn: true,
            enablePunc: true,
            enableDdc: false,
            showUtterances: true,
            enableNonstream: false,
            corpus: CorpusMeta(context: hotwordsJSON)
        )
    }
}

/// 完整客户端请求 Payload
public struct FullClientRequestPayload: Codable, Sendable {
    public let user: UserMeta
    public let audio: AudioMeta
    public let request: RequestMeta
    
    public init(user: UserMeta, audio: AudioMeta, request: RequestMeta) {
        self.user = user
        self.audio = audio
        self.request = request
    }
}
