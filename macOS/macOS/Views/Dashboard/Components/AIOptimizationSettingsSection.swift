import SwiftUI
import Shared

/// AI 文本优化设置区块
struct AIOptimizationSettingsSection: View {
    @State private var isEnabled: Bool = false
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var modelId: String = ""
    @State private var promptTemplate: String = ""
    @State private var disableThinking: Bool = true
    @State private var showKey: Bool = false
    @State private var isSaved: Bool = false
    @State private var isTesting: Bool = false
    @State private var promptTemplateSaveTask: Task<Void, Never>?
    @State private var testResult: TestResult?
    @State private var showTestAlert: Bool = false
    @FocusState private var focusedField: Field?

    private let storage = AIOptimizationStorage.shared

    private enum Field {
        case baseURL, apiKey, modelId
    }

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 文本优化")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                Text("支持所有 OpenAI 兼容服务（OpenAI、DeepSeek、豆包、Ollama 等）")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .padding(.leading, 4)

            // 卡片
            VStack(spacing: 0) {
                // 启用开关行
                HStack {
                    Text("启用 AI 优化")
                        .font(.body)

                    Spacer()

                    Toggle("", isOn: $isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if isEnabled {
                    Divider()
                        .padding(.horizontal, 16)

                    // Base URL 行
                    HStack {
                        Text("Base URL")
                            .font(.body)

                        Spacer()

                        TextField("https://api.openai.com/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                            .frame(width: 280)
                            .focused($focusedField, equals: .baseURL)
                            .onSubmit { saveIfNeeded() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // API Key 行
                    HStack {
                        Text("API Key")
                            .font(.body)

                        Spacer()

                        HStack(spacing: 4) {
                            Group {
                                if showKey {
                                    TextField("请输入 API Key", text: $apiKey)
                                        .onSubmit { saveIfNeeded() }
                                } else {
                                    SecureField("请输入 API Key", text: $apiKey)
                                        .onSubmit { saveIfNeeded() }
                                }
                            }
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .apiKey)

                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(showKey ? "隐藏" : "显示")
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .frame(width: 280)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // 模型 ID 行
                    HStack {
                        Text("模型 ID")
                            .font(.body)

                        Spacer()

                        TextField("gpt-4o-mini", text: $modelId)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                            .frame(width: 280)
                            .focused($focusedField, equals: .modelId)
                            .onSubmit { saveIfNeeded() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // 禁用深度思考行
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("禁用深度思考")
                                .font(.body)
                            Text("适用于 DeepSeek 等支持 thinking 的模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $disableThinking)
                            .toggleStyle(.switch)
                            .controlSize(.regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // 提示词模板行
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("提示词模板")
                                .font(.body)
                            Text("可用变量：{{current_input}} 当前语音输入、{{dictionary}} 个人词典、{{history}} 近期输入历史")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        TextEditor(text: $promptTemplate)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 200)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // 操作按钮行
                    HStack(spacing: 12) {
                        Spacer()

                        // 保存成功提示
                        if isSaved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已保存")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        // 测试连接按钮
                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 8) {
                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                }
                                Text("测试连接")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(apiKey.isEmpty || baseURL.isEmpty || isTesting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: isEnabled) { _, _ in
            saveIfNeeded()
        }
        .onChange(of: disableThinking) { _, _ in
            saveIfNeeded()
        }
        .onChange(of: promptTemplate) { _, _ in
            // 防抖：延迟 1 秒保存，避免每次击键都触发
            promptTemplateSaveTask?.cancel()
            promptTemplateSaveTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                saveIfNeeded()
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil {
                saveIfNeeded()
            }
        }
        .alert("连接测试", isPresented: $showTestAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            switch testResult {
            case .success:
                Text("连接成功！AI 服务可用。")
            case .failure(let error):
                Text("连接失败：\(error)")
            case .none:
                Text("")
            }
        }
    }

    // MARK: - Private Methods

    private func loadSettings() {
        isEnabled = storage.isEnabled
        baseURL = storage.baseURL
        apiKey = storage.apiKey ?? ""
        modelId = storage.modelId
        promptTemplate = storage.promptTemplate
        disableThinking = storage.disableThinking
    }

    private func saveIfNeeded() {
        let changed = isEnabled != storage.isEnabled
            || baseURL != storage.baseURL
            || apiKey != (storage.apiKey ?? "")
            || modelId != storage.modelId
            || promptTemplate != storage.promptTemplate
            || disableThinking != storage.disableThinking

        guard changed else { return }
        saveSettings()
    }

    private func saveSettings() {
        storage.isEnabled = isEnabled
        storage.baseURL = baseURL
        storage.apiKey = apiKey
        storage.modelId = modelId
        storage.promptTemplate = promptTemplate
        storage.disableThinking = disableThinking

        withAnimation(.spring(response: 0.3)) {
            isSaved = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    isSaved = false
                }
            }
        }
    }

    private func testConnection() {
        saveSettings()
        isTesting = true

        Task {
            do {
                try await AITextOptimizationService.shared.testConnection()
                await MainActor.run {
                    testResult = .success
                    showTestAlert = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    showTestAlert = true
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    AIOptimizationSettingsSection()
        .frame(width: 600)
        .padding()
}
