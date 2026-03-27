import Foundation

/// AI 文本优化配置存储（使用 UserDefaults）
@MainActor
public final class AIOptimizationStorage: Sendable {
    public static let shared = AIOptimizationStorage()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "ai.optimization.enabled"
        static let apiKey = "ai.optimization.apiKey"
        static let baseURL = "ai.optimization.baseURL"
        static let modelId = "ai.optimization.modelId"
        static let systemPrompt = "ai.optimization.systemPrompt"
        static let disableThinking = "ai.optimization.disableThinking"
    }

    public static let defaultBaseURL = "https://api.openai.com/v1"
    public static let defaultModelId = "gpt-4o-mini"
    // swiftlint:disable:next line_length
    public static let defaultPromptTemplate = """
        <system_role>
        你是一个内嵌在语音输入法中的专业文本优化引擎。
        </system_role>

        <task>
        结合 <history> 和 <dictionary>，对 <current_input> 进行纠错和润色，将其转化为通顺、专业的书面表达。
        </task>

        <guidelines>
        1. 智能词典匹配：参考 <dictionary> 提供的高频词和专有名词。当 <current_input> 中出现发音相近或容易识别错误的词汇时，请务必结合上下文语境进行合理推断。只有在语义完全契合的情况下，才将其修正为词典中的拼法，切忌生搬硬套。
        2. 纠错映射：<correction_mappings> 包含已知的「错误写法 → 正确写法」对照表。遇到左侧错误时，直接替换为右侧正确写法。
        3. 语境参考：利用 <history> 理解当前对话的语境，推断代词的指代，解决同音词歧义。绝对不要将历史记录合并到最终输出中。
        4. 去除冗余：精准删除无意义的口水词和口吃造成的重复字词。
        5. 英文与术语纠错：修复中英夹杂时的同音字、近音字或单个字母的识别错误（结合语境判断，例如判断"K"是代表"Key"还是普通的"OK"）。
        6. 句式与标点：还原口语倒装句的正常语序，并根据语气补全或修正标点符号。
        7. 最高原则：保持原意，绝对不能改变用户的核心意思，不要擅自总结、缩写或添加内容。
        </guidelines>

        <output_format>
        严格遵守：只输出对 <current_input> 优化后的最终文本，绝对不要包含任何多余的解释、问候语或 XML 标签。
        </output_format>

        <dictionary>
        {{dictionary}}
        </dictionary>

        <correction_mappings>
        {{correction_mappings}}
        </correction_mappings>

        <history>
        {{history}}
        </history>

        <current_input>
        {{current_input}}
        </current_input>
        """

    public init() {}

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    public var apiKey: String? {
        get { defaults.string(forKey: Keys.apiKey) }
        set { defaults.set(newValue, forKey: Keys.apiKey) }
    }

    public var baseURL: String {
        get { defaults.string(forKey: Keys.baseURL) ?? Self.defaultBaseURL }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }

    public var modelId: String {
        get { defaults.string(forKey: Keys.modelId) ?? Self.defaultModelId }
        set { defaults.set(newValue, forKey: Keys.modelId) }
    }

    public var promptTemplate: String {
        get { defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultPromptTemplate }
        set { defaults.set(newValue, forKey: Keys.systemPrompt) }
    }

    /// 禁用深度思考（适用于 DeepSeek 等支持 thinking 的模型）
    public var disableThinking: Bool {
        get {
            if defaults.object(forKey: Keys.disableThinking) == nil {
                return true // 默认禁用
            }
            return defaults.bool(forKey: Keys.disableThinking)
        }
        set { defaults.set(newValue, forKey: Keys.disableThinking) }
    }

    /// 是否已完整配置（启用 + API Key 非空 + Base URL 非空）
    public var isConfigured: Bool {
        guard isEnabled else { return false }
        guard let key = apiKey, !key.isEmpty else { return false }
        return !baseURL.isEmpty
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.isEnabled)
        defaults.removeObject(forKey: Keys.apiKey)
        defaults.removeObject(forKey: Keys.baseURL)
        defaults.removeObject(forKey: Keys.modelId)
        defaults.removeObject(forKey: Keys.systemPrompt)
        defaults.removeObject(forKey: Keys.disableThinking)
    }
}
