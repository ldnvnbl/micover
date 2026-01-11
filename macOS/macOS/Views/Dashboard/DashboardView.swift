import SwiftUI
import Shared

/// Main dashboard view with sidebar navigation
struct DashboardView: View {
    @Environment(SpeechRecognitionService.self) var speechService
    @Environment(AudioService.self) var audioService
    @Environment(PushToTalkService.self) var pushToTalkService
    @Environment(AppState.self) var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var selectedTab: DashboardTab = .home
    @State private var isInitialized = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            DashboardSidebar(selectedTab: $selectedTab)
            
            Divider()
            
            // Content Area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            // Initialize services
            await initializeDashboard()
        }
        .alert("提示", isPresented: Binding(
            get: { pushToTalkService.showAPIKeyAlert },
            set: { pushToTalkService.showAPIKeyAlert = $0 }
        )) {
            Button("去设置") {
                selectedTab = .settings
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(pushToTalkService.apiKeyAlertMessage)
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .home:
            HomePage()
        case .history:
            HistoryPage()
        case .smartPhrases:
            SmartPhrasesPage()
        case .settings:
            SettingsPage()
        }
    }
    
    // MARK: - Initialization
    
    private func initializeDashboard() async {
        // Only initialize once
        guard !isInitialized else { 
            print("Dashboard already initialized, skipping")
            return 
        }
        isInitialized = true
        
        // Configure and enable Push-to-Talk
        configurePushToTalk()
        pushToTalkService.enableIfPossible()
        
        // Show floating window
        showFloatingWindow()
    }
    
    private func configurePushToTalk() {
        pushToTalkService.configure(
            audioService: audioService,
            speechService: speechService,
            appState: appState
        )
    }
    
    private func showFloatingWindow() {
        if !appState.isFloatingWindowVisible {
            openWindow(id: AppConstants.Window.floatingWindowID)
            appState.isFloatingWindowVisible = true
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(SpeechRecognitionService(
            apiKeyStorage: APIKeyStorage.shared,
            keychainManager: KeychainManager(service: "preview")
        ))
        .environment(AudioService())
        .environment(PushToTalkService())
        .environment(AppState())
}
