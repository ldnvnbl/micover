import SwiftUI
import Shared

/// Root view that handles navigation between different app states
/// (permissions check, then dashboard)
struct RootView: View {
    @Environment(SpeechRecognitionService.self) var speechService
    @Environment(AudioService.self) var audioService
    @Environment(PushToTalkService.self) var pushToTalkService
    @Environment(AppState.self) var appState
    @Environment(\.dismissWindow) private var dismissWindow
    
    @StateObject private var sessionCoordinator = AppSessionCoordinator()
    
    init() {
        print("RootView init")
    }
    
    var body: some View {
        Group {
            if sessionCoordinator.isCheckingPermissions {
                // Loading view while checking permissions
                LoadingView(message: "检查权限中...")
            } else if !sessionCoordinator.permissionsGranted {
                // Permission request view for first-time users
                PermissionRequestView(
                    onPermissionsGranted: sessionCoordinator.onPermissionsGranted
                )
            } else {
                // Main dashboard
                DashboardView()
            }
        }
        .onAppear {
            // Configure the AppSessionCoordinator with the services
            sessionCoordinator.configure(
                speechService: speechService,
                pushToTalkService: pushToTalkService,
                audioService: audioService,
                appState: appState,
                dismissWindow: dismissWindow
            )
        }
    }
}

/// Simple loading view component
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

#Preview {
    RootView()
        .environment(SpeechRecognitionService(
            apiKeyStorage: APIKeyStorage.shared,
            keychainManager: KeychainManager(service: "preview")
        ))
        .environment(AudioService())
        .environment(PushToTalkService())
        .environment(AppState())
}
