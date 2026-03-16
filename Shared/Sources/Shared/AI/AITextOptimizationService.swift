import Foundation
import SwiftAISDK
import OpenAICompatibleProvider

/// AI 文本优化服务 — 调用 OpenAI 兼容 API 优化语音识别文本
@MainActor
public final class AITextOptimizationService: Sendable {
    public static let shared = AITextOptimizationService()

    private let storage = AIOptimizationStorage.shared

    public init() {}

    /// 是否可用（已启用且配置完整）
    public var isAvailable: Bool {
        storage.isConfigured
    }

    /// 优化文本，失败时静默返回原文
    /// - Parameters:
    ///   - text: 原始语音识别文本
    ///   - dictionary: 用户词典内容（换行分隔的词条列表）
    ///   - history: 最近的转写历史记录
    public func optimize(_ text: String, dictionary: String, history: String) async -> String {
        guard isAvailable else { return text }
        // 跳过单字符文本
        guard text.count > 1 else { return text }

        // 在 MainActor 上提前捕获配置值
        let baseURL = storage.baseURL
        let apiKey = storage.apiKey
        let modelId = storage.modelId
        let disableThinking = storage.disableThinking

        // 构建 user prompt：模板替换
        let userPrompt = storage.promptTemplate
            .replacingOccurrences(of: "{{dictionary}}", with: dictionary)
            .replacingOccurrences(of: "{{history}}", with: history)
            .replacingOccurrences(of: "{{current_input}}", with: text)

        let startTime = CFAbsoluteTimeGetCurrent()

        // 使用 Task.detached 避免父 Task 取消传播到网络请求
        let result = await Task.detached {
            do {
                let provider = Self.makeProvider(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    disableThinking: disableThinking
                )
                let model = try provider.languageModel(modelId: modelId)

                let result = try await generateText(
                    model: model,
                    prompt: userPrompt,
                    settings: CallSettings(maxOutputTokens: 1024)
                )

                let optimized = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return optimized.isEmpty ? text : optimized
            } catch {
                print("❌ AI optimization failed: \(error)")
                return text
            }
        }.value

        let elapsed = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - startTime)
        print("🤖 AI优化 [\(elapsed)s] 原文: \(text)")
        print("🤖 AI优化 [\(elapsed)s] 结果: \(result)")

        return result
    }

    /// 测试连接有效性
    public func testConnection() async throws {
        let provider = Self.makeProvider(
            baseURL: storage.baseURL,
            apiKey: storage.apiKey,
            disableThinking: storage.disableThinking
        )
        let model = try provider.languageModel(modelId: storage.modelId)

        _ = try await generateText(
            model: model,
            prompt: "Hello",
            settings: CallSettings(maxOutputTokens: 16)
        )
    }

    private nonisolated static func makeProvider(
        baseURL: String,
        apiKey: String?,
        disableThinking: Bool
    ) -> OpenAICompatibleProvider {
        var transform: (@Sendable (_ body: [String: JSONValue]) -> [String: JSONValue])? = nil
        if disableThinking {
            transform = { (body: [String: JSONValue]) -> [String: JSONValue] in
                var body = body
                body["thinking"] = .object(["type": .string("disabled")])
                return body
            }
        }

        return createOpenAICompatibleProvider(
            settings: OpenAICompatibleProviderSettings(
                baseURL: baseURL,
                name: "openai-compatible",
                apiKey: apiKey,
                transformRequestBody: transform
            )
        )
    }
}
