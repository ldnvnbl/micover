import AppKit
import Foundation
import Shared

@Observable
@MainActor
final class PushToTalkService {
    static let shared = PushToTalkService()

    private let hotkeyManager = HotkeyManager()
    private let recordingCoordinator = RecordingCoordinator()
    private let textInputService = TextInputService()

    private var audioService: AudioService?
    private var speechService: SpeechRecognitionService?
    private var appState: AppState?
    private var resultListenerTask: Task<Void, Never>?
    private var resultTimeoutTask: Task<Void, Never>?

    private(set) var isEnabled = false
    private(set) var isWaitingForResult = false
    
    /// 追踪快捷键释放状态，用于处理快速按下释放的竞态条件
    private var pendingStop = false
    
    /// 用于显示 API Key 未配置警告
    var showAPIKeyAlert = false
    var apiKeyAlertMessage = ""

    private var isConfigured = false

    init() {
        print("🚀 PushToTalkService singleton initialized")
        setupHotkeyCallbacks()
    }

    func configure(
        audioService: AudioService,
        speechService: SpeechRecognitionService,
        appState: AppState
    ) {
        guard !isConfigured else {
            print("⚠️ PushToTalkService already configured, skipping")
            return
        }

        print("⚙️ Configuring PushToTalkService...")
        self.audioService = audioService
        self.speechService = speechService
        self.appState = appState
        isConfigured = true

        // 配置 SmartPhraseService（共享 textInputService 实例）
        SmartPhraseService.shared.configure(appState: appState, textInputService: textInputService)

        // 配置热词提供者（直接从 UserDefaults 读取，避免 actor 隔离问题）
        speechService.hotwordsProvider = {
            // 直接从 UserDefaults 读取，绕过 @MainActor 隔离
            guard let data = UserDefaults.standard.data(forKey: "settings.customWords"),
                  let words = try? JSONDecoder().decode([CustomWord].self, from: data) else {
                return nil
            }

            let enabledWords = words.filter { $0.isEnabled }
            guard !enabledWords.isEmpty else { return nil }

            let hotwordsArray = enabledWords.map { ["word": $0.word] }
            let hotwordsDict: [String: Any] = ["hotwords": hotwordsArray]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: hotwordsDict),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }

            return jsonString
        }

        // 配置后自动启用（如果有权限）
        enableIfPossible()
        print("✅ PushToTalkService configured successfully")
    }

    func enableIfPossible() {
        guard !isEnabled else { return }

        // 检查权限
        if HotkeyManager.checkAccessibilityPermission() {
            enable()
        } else {
            print("⚠️ Push-to-Talk needs accessibility permission")
        }
    }

    func enable() {
        guard !isEnabled else { return }

        hotkeyManager.startMonitoring()
        isEnabled = true
        print("✅ Push-to-Talk enabled")
    }

    func disable() {
        guard isEnabled else { return }

        // 如果正在录音，先停止
        if isRecording {
            Task {
                await stopRecording()
            }
        }

        hotkeyManager.stopMonitoring()
        isEnabled = false
        print("Push-to-Talk disabled")
    }

    func requestPermissionAndEnable() {
        Task {
            let hasPermission = await HotkeyManager.checkAccessibilityPermissionAsync()
            if !hasPermission {
                await MainActor.run {
                    HotkeyManager.requestAccessibilityPermission()
                }
                // Check permission asynchronously with retry
                await checkPermissionWithRetry()
            } else {
                await MainActor.run {
                    enable()
                }
            }
        }
    }
    
    private func checkPermissionWithRetry() async {
        for _ in 0..<3000 { // Try for 3000 seconds
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let hasPermission = await HotkeyManager.checkAccessibilityPermissionAsync()
            if hasPermission {
                await MainActor.run {
                    enable()
                }
                break
            }
        }
    }

    private func setupHotkeyCallbacks() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.pendingStop = false
                await self.startRecording()
                
                if self.pendingStop {
                    self.pendingStop = false
                    await self.stopRecording()
                }
            }
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isRecording {
                    await self.stopRecording()
                } else {
                    self.pendingStop = true
                }
            }
        }
    }
    
    // 添加计算属性，从 AudioService 获取录音状态
    var isRecording: Bool {
        audioService?.isRecording ?? false
    }
    
    private func startRecording() async {
        // 检查 API Key 是否配置
        guard let speechService, speechService.isAPIKeyConfigured else {
            apiKeyAlertMessage = "请先在设置页面配置语音识别 API Key"
            showAPIKeyAlert = true
            return
        }
        
        guard !isRecording,
            let audioService,
            let appState
        else { return }

        // 播放开始录音提示音
        playStartSound()
        
        // 更新统计：录音开始
        appState.onRecordingStarted()

        do {
            let resultStream = try await recordingCoordinator.startRecording(
                audioService: audioService,
                speechService: speechService,
                appState: appState
            )
            
            // 开始监听识别结果
            startListeningForResults(resultStream)
            
            print("🎤 Push-to-Talk recording started")
        } catch let error as SpeechRecognitionError {
            print("❌ Failed to start recording: \(error)")
            apiKeyAlertMessage = error.localizedDescription ?? "语音识别服务连接失败"
            showAPIKeyAlert = true
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }

    private func stopRecording() async {
        print("🔴 stopRecording called")
        guard isRecording,
            let audioService,
            let speechService,
            let appState
        else {
            print("⚠️ stopRecording guard failed - isRecording: \(isRecording)")
            return
        }

        // 立即记录录音时长（在 recordingStartTime 被清空前）
        appState.onRecordingEnded()

        print("📤 Calling recordingCoordinator.stopRecording...")
        await recordingCoordinator.stopRecording(
            audioService: audioService,
            speechService: speechService,
            appState: appState
        )

        isWaitingForResult = true
        print("🛑 Push-to-Talk recording stopped")
        print("⏳ isWaitingForResult set to: \(isWaitingForResult)")
        print("🎯 Now waiting for recognition result...")

        // Start timeout task - 8 seconds timeout
        resultTimeoutTask?.cancel()
        resultTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)  // 8 seconds

            guard let self = self else { return }

            if self.isWaitingForResult {
                print("⏰ STT result timeout (8s), ending voice input flow...")
                self.isWaitingForResult = false
                self.resultListenerTask?.cancel()
                NSSound.beep()
            }
        }

        // 播放停止录音提示音
        playStopSound()
    }

    private func playStartSound() {
        NSSound.beep()
    }

    private func playStopSound() {
        NSSound.beep()
    }

    // MARK: - Recognition Result Handling

    private func startListeningForResults(_ stream: AsyncStream<SpeechRecognitionResult>) {
        print("🎧 Starting to listen for recognition results...")
        resultListenerTask?.cancel()
        
        resultListenerTask = Task { [weak self] in
            var finalText = ""
            
            for await result in stream {
                guard let self else { return }
                
                print("📨 Received result: text='\(result.text)', isLast=\(result.isLastPackage), hasError=\(result.hasError)")
                
                // 检查是否有错误
                if let error = result.error {
                    await self.handleError(error)
                    return
                }
                
                // 累积文本
                if !result.text.isEmpty {
                    finalText = result.text
                }
                
                // 如果是最后一个包，处理结果
                if result.isLastPackage {
                    await self.handleFinalResult(finalText)
                }
            }
            
            print("📭 Result stream ended")
        }
    }
    
    private func handleError(_ error: SpeechRecognitionError) async {
        print("❌ Recognition error: \(error.localizedDescription ?? "unknown")")
        
        // Cancel timeout task
        resultTimeoutTask?.cancel()
        resultTimeoutTask = nil
        
        // 停止录音（录音时长已在 stopRecording 中记录）
        if let audioService {
            await audioService.stopRecording()
        }
        
        // 显示错误 alert
        apiKeyAlertMessage = error.localizedDescription ?? "语音识别服务出错"
        showAPIKeyAlert = true
        
        isWaitingForResult = false
        
        // 播放错误提示音
        NSSound.beep()
    }

    private func handleFinalResult(_ text: String) async {
        print("📝 Final recognition result: '\(text)'")
        
        // Cancel timeout task
        resultTimeoutTask?.cancel()
        resultTimeoutTask = nil
        
        // 获取录音时长（在处理前获取，因为后面可能会重置）
        let duration = appState?.recordingDuration ?? 0
        let wordCount = WordCounter.countWords(text)
        
        // 统计转写字数（移到最前面，确保所有情况都统计，包括智能短语触发）
        if !text.isEmpty {
            appState?.onTranscriptionReceived(text)
        }
        
        // 先尝试匹配智能短语
        if let result = await SmartPhraseService.shared.tryExecute(text: text) {
            print("✅ Smart phrase executed")
            
            // 记录智能短语历史
            let actionType: HistoryActionType = result.actionType == .openApp ? .smartPhraseOpenApp : .smartPhraseTypeText
            addHistoryRecord(
                text: text,
                duration: duration,
                wordCount: wordCount,
                actionType: actionType,
                actionDetail: result.actionDetail
            )
            
            isWaitingForResult = false
            NSSound.beep()
            return
        }
        
        // 处理 "over" 结尾命令
        let (processedText, shouldSendEnter) = processOverCommand(text)
        
        // 粘贴处理后的文本
        if !processedText.isEmpty {
            textInputService.pasteTextAndSend(processedText, sendEnter: shouldSendEnter)
            print("✅ Text pasted successfully\(shouldSendEnter ? " with Enter" : "")")
        } else if shouldSendEnter {
            // 纯 "over" 的情况：只发送回车
            textInputService.sendEnterKey()
            print("✅ Enter key sent (over command)")
        }
        
        // 记录普通文本输入历史
        addHistoryRecord(
            text: text,
            duration: duration,
            wordCount: wordCount,
            actionType: .textInput,
            actionDetail: nil
        )
        
        isWaitingForResult = false
        
        // 播放成功提示音
        NSSound.beep()
    }
    
    /// 添加历史记录
    private func addHistoryRecord(
        text: String,
        duration: TimeInterval,
        wordCount: Int,
        actionType: HistoryActionType,
        actionDetail: String?
    ) {
        let record = HistoryRecord(
            transcribedText: text,
            duration: duration,
            wordCount: wordCount,
            actionType: actionType,
            actionDetail: actionDetail
        )
        HistoryStorage.shared.addRecord(record)
    }
    
    /// 处理 "over" 结尾命令
    /// - Parameter text: 原始识别文本
    /// - Returns: (处理后的文本, 是否需要发送回车)
    private func processOverCommand(_ text: String) -> (String, Bool) {
        // 检查配置是否启用
        guard SettingsStorage.shared.isOverCommandEnabled else {
            return (text, false)
        }
        
        guard endsWithOver(text) else {
            return (text, false)
        }
        
        // 去掉末尾标点和 "over"
        var result = text.trimmingCharacters(in: .whitespaces)
        
        // 去掉末尾所有标点
        while let last = result.last, last.isPunctuation {
            result.removeLast()
        }
        
        // 去掉 "over"（已确认以 over 结尾）
        result = String(result.dropLast(4))
        
        // 去除首尾空格
        result = result.trimmingCharacters(in: .whitespaces)
        
        // 逗号结尾替换为句号
        if result.hasSuffix(",") {
            result = String(result.dropLast()) + "."
        } else if result.hasSuffix("，") {
            result = String(result.dropLast()) + "。"
        }
        
        print("🔚 Detected 'over' command, processed: '\(result)'")
        return (result, true)
    }
    
    /// 检查文本是否以 "over" 结尾（忽略末尾标点，检查单词边界）
    private func endsWithOver(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // 去掉末尾所有标点符号
        let withoutTrailingPunctuation = String(trimmed.reversed().drop(while: { $0.isPunctuation }).reversed())
        let lowercased = withoutTrailingPunctuation.lowercased()
        
        // 检查是否正好等于 "over"
        if lowercased == "over" {
            return true
        }
        
        // 检查是否以 "over" 结尾，且前面不是 ASCII 字母（单词边界）
        if lowercased.hasSuffix("over") {
            let indexBeforeOver = lowercased.index(lowercased.endIndex, offsetBy: -5)
            let charBeforeOver = lowercased[indexBeforeOver]
            let isASCIILetter = charBeforeOver.isASCII && charBeforeOver.isLetter
            return !isASCIILetter
        }
        
        return false
    }

    func cleanup() {
        // Cancel listener task
        resultListenerTask?.cancel()
        resultListenerTask = nil

        // Cancel timeout task
        resultTimeoutTask?.cancel()
        resultTimeoutTask = nil

        // Clear service references
        audioService = nil
        speechService = nil
        appState = nil

        // Reset configuration flag
        isConfigured = false
        isWaitingForResult = false

        print("🧹 PushToTalkService cleaned up")
    }
}
