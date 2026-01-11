import Shared
import SwiftUI

@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var speechService = SpeechRecognitionService(
        apiKeyStorage: APIKeyStorage.shared,
        keychainManager: KeychainManager(service: AppConstants.Storage.keychainService)
    )
    @State private var audioService = AudioService()
    @State private var pushToTalkService = PushToTalkService()
    @State private var appState = AppState()

    init() {
        print("macOSApp init")
    }
    
    var body: some Scene {
        Window("", id: AppConstants.Window.mainWindowID) {
            RootView()
                .environment(speechService)
                .environment(audioService)
                .environment(pushToTalkService)
                .environment(appState)
        }
        .defaultSize(width: AppConstants.Window.defaultWidth, height: AppConstants.Window.defaultHeight)

        Window("Floating", id: AppConstants.Window.floatingWindowID) {
            FloatingWindowView()
                .environment(speechService)
                .environment(audioService)
                .environment(pushToTalkService)
                .onReceive(
                    NotificationCenter.default.publisher(for: .reopenMainWindow)
                ) { _ in
                    print("FloatingWindowView onReceive - reopening main window")
                    openWindow(id: AppConstants.Window.mainWindowID)
                }
        }
        .windowLevel(.floating)
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
    }
}
