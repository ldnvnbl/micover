# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-09 | **Commit:** 1e7e0ff | **Branch:** open-source-dev

## OVERVIEW

MicOver: Cross-platform Swift app (macOS 14.0+, iOS 13.0+, Swift 6.1) for Push-to-Talk audio recording with WebSocket-based speech recognition. Real-time transcription with auto-paste functionality.

## STRUCTURE

```
MicOver/
├── Shared/                    # Cross-platform SPM library (15 Swift files)
│   └── Sources/Shared/
│       ├── Audio/             # AudioService, AudioRecorder, AudioConverter
│       ├── Core/Storage/      # KeychainManager, APIKeyStorage, StatsStorage
│       └── SpeechRecognition/ # WebSocket speech service, binary protocol codec
├── macOS/macOS/               # macOS app (30+ Swift files) - DOUBLE NESTED (intentional)
│   ├── App/                   # macOSApp, AppDelegate, AppConstants
│   ├── Services/              # PushToTalkService, HotkeyManager, RecordingCoordinator
│   ├── Views/                 # SwiftUI views (Dashboard, FloatingWindow)
│   └── ViewModels/            # AppSessionCoordinator
├── iOS/iOS/                   # iOS app (minimal template, 2 files)
└── MicOver.xcworkspace        # Links Shared SPM + platform Xcode projects
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Audio recording/conversion | `Shared/Sources/Shared/Audio/` | Float32 48kHz -> PCM S16LE 16kHz |
| Speech recognition | `Shared/Sources/Shared/SpeechRecognition/` | WebSocket + binary protocol |
| Push-to-Talk flow | `macOS/macOS/Services/PushToTalkService.swift` | Main orchestrator (470 lines) |
| Global hotkeys | `macOS/macOS/Services/HotkeyManager.swift` | Fn key + custom shortcuts |
| Auto-paste text | `macOS/macOS/Services/TextInputService.swift` | CGEvent simulation |
| Smart phrases | `macOS/macOS/Services/SmartPhraseService.swift` | Trigger word matching |
| UI components | `macOS/macOS/Views/Dashboard/` | SwiftUI dashboard pages |
| Storage | `Shared/.../Core/Storage/` + `macOS/.../Services/*Storage.swift` | Keychain + UserDefaults |

## BUILD COMMANDS

```bash
# macOS App
xcodebuild -workspace MicOver.xcworkspace -scheme macOS -configuration Debug build
./run.sh                                    # Build & run (kills existing process)

# iOS App
xcodebuild -workspace MicOver.xcworkspace -scheme iOS -configuration Debug build

# Shared Package (SPM)
swift build --package-path Shared           # Build
swift test --package-path Shared            # Run tests
swift package --package-path Shared clean   # Clean

# Release Distribution (macOS)
APP_PATH="build/export/MicOver.app" ./macOS/build-dmg.sh  # Build DMG
./macOS/notarize.sh                                        # Full notarize workflow
./macOS/check-dmg.sh                                       # Verify DMG
```

## CONVENTIONS

### Type Definitions
| Type | Usage |
|------|-------|
| `@Observable @MainActor final class` | Services, view models |
| `actor` | Thread-safe isolated state (AudioRecorder, RecordingCoordinator) |
| `struct` | Data models, SwiftUI views |
| `enum` (caseless) | Constants with `static` properties |

### Import Order (no blank lines)
```swift
import Foundation      // 1. System
import AppKit          // 2. Platform frameworks
import KeychainAccess  // 3. Third-party
import Shared          // 4. Local modules
```

### Access Control
- `public` for Shared module APIs consumed by platform targets
- `private(set)` for read-only exposed properties
- Default to `private` for implementation details

### Concurrency
- `@MainActor` for UI-related classes
- `async/await` throughout, avoid callbacks
- `Task.sleep` instead of `Timer.scheduledTimer`
- `AsyncStream` for streaming data

### Error Handling
```swift
public enum ServiceError: LocalizedError, Sendable {
    case notConfigured
    case connectionFailed(String)
}
```

### Code Organization
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Helpers
```

## ANTI-PATTERNS (THIS PROJECT)

- **No tests unless requested**: Explicit policy - do not write test files or examples
- **No linter**: No SwiftLint configured
- **No `as any`, `@ts-ignore`**: Never suppress type errors
- **No force unwraps**: Avoid `!` operator
- **No callbacks**: Use async/await

## CRITICAL IMPLEMENTATION NOTES

### Threading
- `AXIsProcessTrusted()` MUST be called async (blocks UI otherwise)
- Use `HotkeyManager.checkAccessibilityPermissionAsync()`

### WebSocket
- Headers (API key, device ID) fetched dynamically at connection time
- Audio sent as binary frames via `sendAudioData()`, not `sendMessage()`
- Final packet marked with `isLast: true`

### Audio Pipeline
- Mic input: Float32 @ 48kHz
- WebSocket output: PCM S16LE @ 16kHz
- Conversion via `AudioConverter.floatChannelDataToPCMS16LE()`

### macOS Permissions
- **Microphone**: AVCaptureDevice
- **Accessibility**: Required for global hotkeys + auto-paste
- **Sandbox disabled**: Enables global hotkey listening

## DEPENDENCIES

| Package | Version | Purpose |
|---------|---------|---------|
| KeychainAccess | 4.2.2 | Secure storage |
| HotKey | 0.2.1 | Global hotkey monitoring |
| Alamofire | 5.10.2 | HTTP networking |

## NOTES

- **Double-nested dirs**: `macOS/macOS/` and `iOS/iOS/` are intentional (Xcode project structure)
- **iOS app**: Minimal template, not developed
- **No CI/CD**: Manual build scripts only
- **SmartPhrasesPage.swift**: Largest file (1004 lines) - main UI complexity
