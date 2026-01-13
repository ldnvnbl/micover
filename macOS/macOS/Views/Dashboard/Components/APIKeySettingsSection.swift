import SwiftUI
import Shared

/// API 配置区块
struct APIKeySettingsSection: View {
    @State private var apiKey: String = ""
    @State private var selectedResourceId: VolcEngineResourceId = .default
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
                    
                    // 目前只有一个选项，为后续扩展预留
                    Picker("", selection: .constant("volcengine")) {
                        Text("火山引擎豆包").tag("volcengine")
                    }
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .frame(width: 160)
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
                    
                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("请输入 API Key", text: $apiKey)
                                    .onSubmit { saveKeyIfNeeded() }
                            } else {
                                SecureField("请输入 API Key", text: $apiKey)
                                    .onSubmit { saveKeyIfNeeded() }
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .frame(width: 280)
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
                    .disabled(apiKey.isEmpty || isTesting)
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
            loadKey()
        }
        .onChange(of: isApiKeyFocused) { _, isFocused in
            if !isFocused {
                saveKeyIfNeeded()
            }
        }
        .onChange(of: selectedResourceId) { _, _ in
            saveKeyIfNeeded()
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
    
    // MARK: - Private Methods
    
    private func loadKey() {
        apiKey = apiKeyStorage.apiKey ?? ""
        selectedResourceId = apiKeyStorage.resourceId
    }
    
    private func saveKeyIfNeeded() {
        let storedApiKey = apiKeyStorage.apiKey ?? ""
        let storedResourceId = apiKeyStorage.resourceId
        
        guard apiKey != storedApiKey || selectedResourceId != storedResourceId else {
            return
        }
        
        saveKey()
    }
    
    private func saveKey() {
        apiKeyStorage.save(apiKey: apiKey)
        apiKeyStorage.save(resourceId: selectedResourceId)
        
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
        apiKeyStorage.save(apiKey: apiKey)
        
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
