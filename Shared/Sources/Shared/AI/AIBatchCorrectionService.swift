import Foundation
import SwiftAISDK
import OpenAICompatibleProvider

/// 批量纠错输入
public struct BatchCorrectionInput: Sendable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}

/// AI 批量纠错服务 — 将历史记录分批发给大模型进行纠错
@MainActor
public final class AIBatchCorrectionService: Sendable {
    public static let shared = AIBatchCorrectionService()

    private let optimizationStorage = AIOptimizationStorage.shared
    private let correctionStorage = BatchCorrectionStorage.shared

    /// 每批记录数
    private static let chunkSize = 10

    public init() {}

    public var isAvailable: Bool {
        optimizationStorage.isConfigured
    }

    /// 批量纠错，返回 [UUID: correctedText]（仅包含需要修改的记录）
    /// - Parameters:
    ///   - inputs: 待纠错的记录列表
    ///   - onProgress: 进度回调 (0.0 ~ 1.0)
    public func correctBatch(
        _ inputs: [BatchCorrectionInput],
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> [UUID: String] {
        guard isAvailable else { return [:] }

        let baseURL = optimizationStorage.baseURL
        let apiKey = optimizationStorage.apiKey
        let modelId = correctionStorage.correctionModelId
        let disableThinking = optimizationStorage.disableThinking

        let chunks = stride(from: 0, to: inputs.count, by: Self.chunkSize).map {
            Array(inputs[$0..<min($0 + Self.chunkSize, inputs.count)])
        }

        var allResults: [UUID: String] = [:]
        let totalChunks = chunks.count

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            let prompt = buildPrompt(for: chunk)

            let chunkResult = await Task.detached {
                do {
                    let provider = Self.makeProvider(
                        baseURL: baseURL,
                        apiKey: apiKey,
                        disableThinking: disableThinking
                    )
                    let model = try provider.languageModel(modelId: modelId)

                    let result = try await generateText(
                        model: model,
                        prompt: prompt,
                        settings: CallSettings(maxOutputTokens: 4096)
                    )

                    return Self.parseResponse(result.text, inputs: chunk)
                } catch {
                    print("❌ Batch correction chunk \(index) failed: \(error)")
                    return [UUID: String]()
                }
            }.value

            allResults.merge(chunkResult) { _, new in new }

            let progress = Double(index + 1) / Double(totalChunks)
            onProgress?(progress)
        }

        return allResults
    }

    // MARK: - Prompt

    private func buildPrompt(for inputs: [BatchCorrectionInput]) -> String {
        var recordLines = ""
        for (index, input) in inputs.enumerated() {
            recordLines += "\(index): \(input.text)\n"
        }

        return """
        你是一个专业的语音识别文本纠错引擎。以下是多条语音识别的文本记录，请逐条进行纠错和润色。

        规则：
        1. 修复同音字、近音字错误（如"因有额"→"营业额"）
        2. 去除口水词（嗯、那个、就是说）和口吃造成的重复字词
        3. 修正英文术语拼写和中英文混排的空格
        4. 补全或修正标点符号
        5. 保持原意，不要擅自总结、缩写或添加内容
        6. 如果某条文本已经正确无需修改，请省略该条

        请以 JSON 数组格式返回结果，每个元素包含 index（从 0 开始的序号）和 correctedText 字段。
        只返回需要修改的记录，已正确的记录请省略。

        记录列表：
        \(recordLines)
        请只输出 JSON 数组，不要包含其他内容（不要包含 ```json 标记）。
        """
    }

    // MARK: - Response Parsing

    private nonisolated static func parseResponse(
        _ responseText: String,
        inputs: [BatchCorrectionInput]
    ) -> [UUID: String] {
        var results: [UUID: String] = [:]

        // 尝试提取 JSON 内容（处理可能的 markdown 代码块包裹）
        let jsonText: String
        if let range = responseText.range(of: "\\[[\\s\\S]*?\\]", options: .regularExpression) {
            jsonText = String(responseText[range])
        } else {
            jsonText = responseText
        }

        guard let data = jsonText.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("❌ Batch correction: failed to parse JSON response")
            return results
        }

        for item in array {
            guard let index = item["index"] as? Int,
                  let correctedText = item["correctedText"] as? String,
                  index >= 0, index < inputs.count else {
                continue
            }

            let input = inputs[index]
            let trimmed = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
            // 只保留实际有变化的
            if !trimmed.isEmpty && trimmed != input.text {
                results[input.id] = trimmed
            }
        }

        return results
    }

    // MARK: - Provider

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
