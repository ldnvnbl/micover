import SwiftUI
import Shared

struct FloatingWindowView: View {
    @Environment(SpeechRecognitionService.self) var speechService
    @Environment(AudioService.self) var audioService
    @Environment(PushToTalkService.self) var pushToTalkService
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var initialWindowSize: CGSize = .zero
    
    var body: some View {
        Group {
            if audioService.isRecording {
                MusicPlayingIndicator(
                    barCount: 9,
                    barWidth: 2
                ).onAppear {
                    positionWindow(isActive: true)
                }
            } else if pushToTalkService.isWaitingForResult {
                LoadingDotsIndicator(
                    dotCount: 4,
                    dotSize: 4,
                    spacing: 6,
                    color: .gray,
                    animationDuration: 0.6
                ).onAppear {
                    positionWindow(isActive: true)
                }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16, height: 2)
                    .onAppear {
                        positionWindow(isActive: false)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            Capsule()
                .stroke(Color.gray.opacity(0.8), lineWidth: 0.5)
        )
        .padding(1)
        .onAppear {
            if let window = NSApplication.shared.windows.first(where: {
                $0.identifier?.rawValue == AppConstants.Window.floatingWindowID
            }) {
                initialWindowSize = window.frame.size
            }
            positionWindow(isActive: false)
        }
    }
    
    func positionWindow(isActive: Bool = false) {
        guard let window = NSApplication.shared.windows.first(where: {
            $0.identifier?.rawValue == AppConstants.Window.floatingWindowID
        }) else { return }
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let margin: CGFloat = 4
            let windowSize = window.frame.size
            
            let x: CGFloat
            var y: CGFloat
            
            if isActive {
                x = screenFrame.midX - (initialWindowSize.width + 18) / 2
                y = screenFrame.minY + margin
                if windowSize.height == initialWindowSize.height {
                    y += 14
                }
            } else {
                x = screenFrame.midX - initialWindowSize.width / 2
                y = screenFrame.minY + margin - (windowSize.height - initialWindowSize.height)
            }
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

#Preview {
    FloatingWindowView()
        .environment(SpeechRecognitionService(
            apiKeyStorage: APIKeyStorage.shared,
            keychainManager: KeychainManager(service: "preview")
        ))
        .environment(AudioService())
        .environment(PushToTalkService())
}
