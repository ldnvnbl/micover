import SwiftUI
import Shared

/// API 配置区块
struct APIKeySettingsSection: View {
    // 通用
    @State private var selectedProvider: SpeechProvider = .volcEngine
    @State private var isSaved: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showTestAlert: Bool = false

    // 火山引擎
    @State private var apiKey: String = ""
    @State private var selectedResourceId: VolcEngineResourceId = .default
    @State private var showKey: Bool = false
    @FocusState private var isApiKeyFocused: Bool

    // vLLM
    @State private var vllmBaseURL: String = ""
    @State private var vllmModelName: String = ""
    @State private var vllmAPIKey: String = ""
    @State private var vllmApiMode: VLLMApiMode = .audioTranscriptions
    @State private var showVllmKey: Bool = false
    @FocusState private var isVllmFieldFocused: Bool

    private let apiKeyStorage = APIKeyStorage.shared
    @Environment(SpeechRecognitionService.self) var speechService

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（卡片外）
            Text("语音 API")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .padding(.leading, 4)

            // 卡片
            VStack(spacing: 0) {
                // 服务商行
                HStack {
                    Text("服务商")
                        .font(.body)

                    Spacer()

                    Picker("", selection: $selectedProvider) {
                        ForEach(SpeechProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .frame(width: 200)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, 16)

                // Provider-specific fields
                switch selectedProvider {
                case .volcEngine:
                    volcEngineFields
                case .vllm:
                    vllmFields
                }

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
                    .disabled(!canTest || isTesting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
        .onChange(of: selectedProvider) { _, _ in
            saveSettingsIfNeeded()
        }
        .onChange(of: isApiKeyFocused) { _, isFocused in
            if !isFocused { saveSettingsIfNeeded() }
        }
        .onChange(of: selectedResourceId) { _, _ in
            saveSettingsIfNeeded()
        }
        .onChange(of: isVllmFieldFocused) { _, isFocused in
            if !isFocused { saveSettingsIfNeeded() }
        }
        .onChange(of: vllmApiMode) { _, _ in
            saveSettingsIfNeeded()
        }
        .alert("连接测试", isPresented: $showTestAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            switch testResult {
            case .success:
                Text("连接成功！")
            case .failure(let error):
                Text("连接失败：\(error)")
            case .none:
                Text("")
            }
        }
    }

    // MARK: - 火山引擎配置字段

    @ViewBuilder
    private var volcEngineFields: some View {
        // API Key 输入行
        HStack {
            Text("API Key")
                .font(.body)

            Spacer()

            HStack(spacing: 4) {
                Group {
                    if showKey {
                        TextField("请输入 API Key", text: $apiKey)
                            .onSubmit { saveSettingsIfNeeded() }
                    } else {
                        SecureField("请输入 API Key", text: $apiKey)
                            .onSubmit { saveSettingsIfNeeded() }
                    }
                }
                .textFieldStyle(.plain)
                .focused($isApiKeyFocused)

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

        // 模型版本行
        HStack {
            Text("模型版本")
                .font(.body)

            Spacer()

            Picker("", selection: $selectedResourceId) {
                ForEach(VolcEngineResourceId.allCases, id: \.self) { resourceId in
                    Text(resourceId.displayName).tag(resourceId)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)
            .frame(width: 160)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - vLLM 配置字段

    @ViewBuilder
    private var vllmFields: some View {
        // 服务地址行
        HStack {
            Text("服务地址")
                .font(.body)

            Spacer()

            TextField("http://localhost:8000/v1", text: $vllmBaseURL)
                .textFieldStyle(.plain)
                .focused($isVllmFieldFocused)
                .onSubmit { saveSettingsIfNeeded() }
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

        // 接口类型行
        HStack {
            Text("接口类型")
                .font(.body)

            Spacer()

            Picker("", selection: $vllmApiMode) {
                ForEach(VLLMApiMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)
            .frame(width: 280)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider()
            .padding(.horizontal, 16)

        // 模型名称行
        HStack {
            Text("模型名称")
                .font(.body)

            Spacer()

            TextField("openai/whisper-large-v3", text: $vllmModelName)
                .textFieldStyle(.plain)
                .focused($isVllmFieldFocused)
                .onSubmit { saveSettingsIfNeeded() }
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

        // API Key（选填）
        HStack {
            HStack(spacing: 4) {
                Text("API Key")
                    .font(.body)
                Text("(选填)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Group {
                    if showVllmKey {
                        TextField("本地部署可留空", text: $vllmAPIKey)
                            .onSubmit { saveSettingsIfNeeded() }
                    } else {
                        SecureField("本地部署可留空", text: $vllmAPIKey)
                            .onSubmit { saveSettingsIfNeeded() }
                    }
                }
                .textFieldStyle(.plain)
                .focused($isVllmFieldFocused)

                Button {
                    showVllmKey.toggle()
                } label: {
                    Image(systemName: showVllmKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help(showVllmKey ? "隐藏" : "显示")
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
    }

    // MARK: - Computed

    private var canTest: Bool {
        switch selectedProvider {
        case .volcEngine:
            return !apiKey.isEmpty
        case .vllm:
            return !vllmBaseURL.isEmpty
        }
    }

    // MARK: - Private Methods

    private func loadSettings() {
        selectedProvider = apiKeyStorage.selectedProvider
        // 火山引擎
        apiKey = apiKeyStorage.apiKey ?? ""
        selectedResourceId = apiKeyStorage.resourceId
        // vLLM
        vllmBaseURL = apiKeyStorage.vllmBaseURL
        vllmModelName = apiKeyStorage.vllmModelName
        vllmAPIKey = apiKeyStorage.vllmAPIKey ?? ""
        vllmApiMode = apiKeyStorage.vllmApiMode
    }

    private func saveSettingsIfNeeded() {
        let providerChanged = selectedProvider != apiKeyStorage.selectedProvider
        let volcChanged = apiKey != (apiKeyStorage.apiKey ?? "") || selectedResourceId != apiKeyStorage.resourceId
        let vllmChanged = vllmBaseURL != apiKeyStorage.vllmBaseURL
            || vllmModelName != apiKeyStorage.vllmModelName
            || vllmAPIKey != (apiKeyStorage.vllmAPIKey ?? "")
            || vllmApiMode != apiKeyStorage.vllmApiMode

        guard providerChanged || volcChanged || vllmChanged else { return }

        saveSettings()
    }

    private func saveSettings() {
        apiKeyStorage.selectedProvider = selectedProvider
        // 火山引擎
        apiKeyStorage.save(apiKey: apiKey)
        apiKeyStorage.save(resourceId: selectedResourceId)
        // vLLM
        apiKeyStorage.save(vllmBaseURL: vllmBaseURL)
        apiKeyStorage.save(vllmModelName: vllmModelName)
        apiKeyStorage.save(vllmAPIKey: vllmAPIKey.isEmpty ? nil : vllmAPIKey)
        apiKeyStorage.save(vllmApiMode: vllmApiMode)

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
        // 先保存当前配置
        saveSettings()

        isTesting = true

        Task {
            do {
                try await speechService.testConnection()
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
    APIKeySettingsSection()
        .environment(SpeechRecognitionService(
            apiKeyStorage: APIKeyStorage.shared,
            keychainManager: KeychainManager(service: "preview")
        ))
        .frame(width: 600)
        .padding()
}
