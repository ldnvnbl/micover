import SwiftUI
import Shared

/// API 配置区块
struct APIKeySettingsSection: View {
    // 当前选择的服务商
    @State private var selectedProvider: SpeechProvider = .default

    // 火山引擎
    @State private var apiKey: String = ""
    @State private var selectedResourceId: VolcEngineResourceId = .default

    // 千问
    @State private var qwenApiKey: String = ""
    @State private var selectedQwenRegion: QwenRegion = .default
    @State private var selectedQwenModel: QwenModel = .default

    @State private var showKey: Bool = false
    @State private var isSaved: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showTestAlert: Bool = false
    @FocusState private var isApiKeyFocused: Bool

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
                        ForEach(SpeechProvider.allCases, id: \.self) { provider in
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

                // API Key 输入行
                HStack {
                    Text("API Key")
                        .font(.body)

                    Spacer()

                    HStack(spacing: 4) {
                        Group {
                            if showKey {
                                TextField("请输入 API Key", text: currentKeyBinding)
                                    .onSubmit { saveIfNeeded() }
                            } else {
                                SecureField("请输入 API Key", text: currentKeyBinding)
                                    .onSubmit { saveIfNeeded() }
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

                // 服务商相关字段
                providerSpecificFields

                Divider()
                    .padding(.horizontal, 16)

                // 操作按钮行
                HStack(spacing: 12) {
                    Spacer()

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
                    .disabled(currentKey.isEmpty || isTesting)
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
        .onChange(of: isApiKeyFocused) { _, isFocused in
            if !isFocused {
                saveIfNeeded()
            }
        }
        .onChange(of: selectedProvider) { _, _ in
            saveIfNeeded()
        }
        .onChange(of: selectedResourceId) { _, _ in
            saveIfNeeded()
        }
        .onChange(of: selectedQwenRegion) { _, _ in
            saveIfNeeded()
        }
        .onChange(of: selectedQwenModel) { _, _ in
            saveIfNeeded()
        }
        .alert("连接测试", isPresented: $showTestAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            switch testResult {
            case .success:
                Text("连接成功！API Key 有效。")
            case .failure(let error):
                Text("连接失败：\(error)")
            case .none:
                Text("")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var providerSpecificFields: some View {
        switch selectedProvider {
        case .volcengine:
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
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        case .qwen:
            HStack {
                Text("接入地域")
                    .font(.body)
                Spacer()
                Picker("", selection: $selectedQwenRegion) {
                    ForEach(QwenRegion.allCases, id: \.self) { region in
                        Text(region.displayName).tag(region)
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

            HStack {
                Text("模型版本")
                    .font(.body)
                Spacer()
                Picker("", selection: $selectedQwenModel) {
                    ForEach(QwenModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: 280)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private var currentKeyBinding: Binding<String> {
        switch selectedProvider {
        case .volcengine:
            return $apiKey
        case .qwen:
            return $qwenApiKey
        }
    }

    private var currentKey: String {
        switch selectedProvider {
        case .volcengine: return apiKey
        case .qwen: return qwenApiKey
        }
    }

    private func loadSettings() {
        selectedProvider = apiKeyStorage.provider
        apiKey = apiKeyStorage.apiKey ?? ""
        selectedResourceId = apiKeyStorage.resourceId
        qwenApiKey = apiKeyStorage.qwenApiKey ?? ""
        selectedQwenRegion = apiKeyStorage.qwenRegion
        selectedQwenModel = apiKeyStorage.qwenModel
    }

    private func saveIfNeeded() {
        let providerChanged = selectedProvider != apiKeyStorage.provider
        let volcChanged =
            apiKey != (apiKeyStorage.apiKey ?? "") ||
            selectedResourceId != apiKeyStorage.resourceId
        let qwenChanged =
            qwenApiKey != (apiKeyStorage.qwenApiKey ?? "") ||
            selectedQwenRegion != apiKeyStorage.qwenRegion ||
            selectedQwenModel != apiKeyStorage.qwenModel

        guard providerChanged || volcChanged || qwenChanged else {
            return
        }

        save()
    }

    private func save() {
        apiKeyStorage.save(provider: selectedProvider)
        apiKeyStorage.save(apiKey: apiKey)
        apiKeyStorage.save(resourceId: selectedResourceId)
        apiKeyStorage.save(qwenApiKey: qwenApiKey)
        apiKeyStorage.save(qwenRegion: selectedQwenRegion)
        apiKeyStorage.save(qwenModel: selectedQwenModel)

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
        // 在测试前先持久化所有当前设置，确保引擎读取到正确的配置
        save()

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
