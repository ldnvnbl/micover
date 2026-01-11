# macOS App

Native macOS app for Push-to-Talk with global hotkey support, speech recognition, and auto-paste.

## STRUCTURE

```
macOS/
├── App/
│   ├── macOSApp.swift          # @main entry, multi-window (Dashboard + FloatingWindow)
│   ├── AppDelegate.swift       # Dock icon click handling
│   └── AppConstants.swift      # Caseless enum constants
├── Services/
│   ├── PushToTalkService.swift     # Main orchestrator (470 lines) - singleton
│   ├── RecordingCoordinator.swift  # actor - recording lifecycle
│   ├── HotkeyManager.swift         # Global hotkeys (Fn key + custom)
│   ├── TextInputService.swift      # CGEvent text simulation
│   ├── PermissionManager.swift     # Microphone + Accessibility
│   ├── SmartPhraseService.swift    # Trigger word matching
│   ├── HistoryStorage.swift        # Weekly-partitioned history
│   ├── SettingsStorage.swift       # UserDefaults settings
│   └── SmartPhraseStorage.swift    # Smart phrase persistence
├── Models/
│   ├── AppState.swift          # @Observable app-wide state
│   ├── Hotkey.swift            # Hotkey config + validation
│   ├── SmartPhrase.swift       # Phrase + action types
│   └── HistoryRecord.swift     # Transcription history
├── Views/
│   ├── Root/RootView.swift         # Permission -> Dashboard routing
│   ├── PermissionRequestView.swift # Permission onboarding
│   ├── Dashboard/
│   │   ├── DashboardView.swift     # Main container
│   │   ├── Components/             # Sidebar, settings sections
│   │   └── Pages/                  # Home, Settings, History, SmartPhrases
│   ├── FloatingWindow/             # Minimal overlay window
│   └── AudioView/                  # Debug audio visualization
├── ViewModels/
│   └── AppSessionCoordinator.swift # Session management
├── Resources/
│   ├── Info.plist
│   ├── macOS.entitlements          # Sandbox DISABLED
│   └── Assets.xcassets
├── build-dmg.sh                # DMG creation + R2 upload
├── notarize.sh                 # Archive + notarize + staple
├── check-dmg.sh                # Verify DMG integrity
└── .env.example                # Signing credentials template
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Push-to-Talk flow | `Services/PushToTalkService.swift` | Main entry point |
| Recording lifecycle | `Services/RecordingCoordinator.swift` | actor pattern |
| Global hotkeys | `Services/HotkeyManager.swift` | Fn key via NSEvent, others via HotKey |
| Auto-paste text | `Services/TextInputService.swift` | CGEvent key simulation |
| Permission checks | `Services/PermissionManager.swift` | Mic + Accessibility |
| Smart phrases | `Services/SmartPhraseService.swift` | "over" command, app launch |
| Main UI | `Views/Dashboard/` | SwiftUI pages |
| Settings | `Views/Dashboard/Pages/SettingsPage.swift` | All user preferences |
| History | `Views/Dashboard/Pages/HistoryPage.swift` | Transcription log |

## KEY PATTERNS

### Service Singletons
```swift
@Observable
@MainActor
final class PushToTalkService {
    static let shared = PushToTalkService()
    private init() { ... }
}
```

### Notification-Based Updates
```swift
extension Notification.Name {
    static let historyRecordAdded = Notification.Name("historyRecordAdded")
    static let hotkeyConfigurationChanged = Notification.Name("hotkeyConfigurationChanged")
}
```

### Environment Injection
```swift
@main
struct macOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(speechService)
                .environment(audioService)
        }
    }
}
```

## PUSH-TO-TALK FLOW

1. User presses hotkey (Fn or custom)
2. `HotkeyManager` fires callback
3. `PushToTalkService.startRecording()` called
4. `RecordingCoordinator` starts `AudioService` + `SpeechRecognitionService`
5. Audio streamed via WebSocket as binary frames
6. Recognition results arrive via `AsyncStream`
7. `SmartPhraseService` checks for triggers ("over" command)
8. `TextInputService` pastes final text

## BUILD

```bash
# Debug
xcodebuild -workspace ../MicOver.xcworkspace -scheme macOS -configuration Debug build
../run.sh  # Quick build & run

# Release
./notarize.sh  # Full archive + notarize workflow
APP_PATH="build/export/MicOver.app" ./build-dmg.sh
```

## PERMISSIONS

| Permission | Purpose | How |
|------------|---------|-----|
| Microphone | Audio recording | AVCaptureDevice |
| Accessibility | Global hotkeys + auto-paste | AXIsProcessTrusted() |

**Sandbox is DISABLED** in entitlements to enable global hotkey monitoring.

## LARGE FILES

| File | Lines | Purpose |
|------|-------|---------|
| `SmartPhrasesPage.swift` | 1004 | Complex phrase management UI |
| `PushToTalkService.swift` | 470 | Main orchestrator |
| `AudioView.swift` | 408 | Debug visualization |

## ANTI-PATTERNS

- Never call `AXIsProcessTrusted()` on main thread - use async version
- Never use `Timer.scheduledTimer` - use `Task.sleep`
- Never modify UI state from background threads
