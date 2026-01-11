import Foundation
import SwiftUI
import AVFoundation
import Shared

@MainActor
class AppSessionCoordinator: ObservableObject {
    @Published var permissionsGranted = false
    @Published var isCheckingPermissions = true
    
    private var speechService: SpeechRecognitionService?
    private var pushToTalkService: PushToTalkService?
    private var audioService: AudioService?
    private var appState: AppState?
    private var dismissWindow: DismissWindowAction?
    
    init() {
        Task {
            await checkPermissions()
        }
    }
    
    func configure(
        speechService: SpeechRecognitionService,
        pushToTalkService: PushToTalkService,
        audioService: AudioService,
        appState: AppState,
        dismissWindow: DismissWindowAction? = nil
    ) {
        self.speechService = speechService
        self.pushToTalkService = pushToTalkService
        self.audioService = audioService
        self.appState = appState
        self.dismissWindow = dismissWindow
    }
    
    func checkPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }
        
        // Check microphone permission
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let hasMicrophonePermission = microphoneStatus == .authorized

        // Check accessibility permission using AXIsProcessTrusted
        let hasAccessibilityPermission = await Task.detached(priority: .userInitiated) {
            return AXIsProcessTrusted()
        }.value

        permissionsGranted = hasMicrophonePermission && hasAccessibilityPermission
    }
    
    func onPermissionsGranted() {
        permissionsGranted = true
    }
}
