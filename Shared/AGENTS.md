# Shared Module

Cross-platform Swift Package (SPM) for audio and speech recognition. Consumed by macOS and iOS targets.

## STRUCTURE

```
Sources/Shared/
├── Audio/
│   ├── AudioService.swift         # @Observable @MainActor - recording orchestration
│   ├── AudioRecorder.swift        # actor - AVAudioEngine wrapper
│   ├── AudioConverter.swift       # Float32 48kHz -> PCM S16LE 16kHz
│   ├── AudioDeviceManager.swift   # Device enumeration/selection
│   ├── AVAudioPCMBuffer+Extensions.swift
│   └── Models/AudioError.swift
├── Core/Storage/
│   ├── KeychainManager.swift      # Device ID, session storage
│   ├── APIKeyStorage.swift        # API key + resource ID
│   └── StatsStorage.swift         # Daily recording stats
└── SpeechRecognition/
    ├── SpeechRecognitionService.swift  # @Observable @MainActor - WebSocket client
    ├── SpeechRecognitionError.swift
    ├── Protocol/
    │   ├── SpeechProtocol.swift        # Message types, flags, constants
    │   └── SpeechProtocolCodec.swift   # Binary encoding + GZIP compression
    └── Models/
        ├── SpeechRequestModels.swift   # UserMeta, AudioMeta, RequestMeta
        └── SpeechResponseModels.swift  # SpeechRecognitionResult, Utterance, Word
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Start/stop recording | `AudioService.swift` | Manages AudioRecorder lifecycle |
| Raw audio capture | `AudioRecorder.swift` | actor, AVAudioEngine |
| Format conversion | `AudioConverter.swift` | Static methods, caseless enum |
| Device selection | `AudioDeviceManager.swift` | macOS-only, singleton |
| WebSocket connection | `SpeechRecognitionService.swift` | Handles connect/disconnect/streaming |
| Binary protocol | `SpeechProtocolCodec.swift` | GZIP, CRC32, header building |
| Secure storage | `KeychainManager.swift` | KeychainAccess wrapper |

## KEY PATTERNS

### Singleton Services
```swift
@Observable @MainActor public final class AudioDeviceManager {
    public static let shared = AudioDeviceManager()
    private init() { ... }
}
```

### Actor for Thread Safety
```swift
public actor AudioRecorder {
    private var audioEngine: AVAudioEngine?
    public func startRecording() async throws { ... }
}
```

### Caseless Enum for Utilities
```swift
public enum AudioConverter {
    public static func floatChannelDataToPCMS16LE(...) -> Data { ... }
}
```

### AsyncStream for Streaming
```swift
public func recognitionResults() -> AsyncStream<SpeechRecognitionResult> {
    AsyncStream { continuation in ... }
}
```

## AUDIO PIPELINE

```
Microphone → AVAudioEngine (Float32 @ 48kHz)
    ↓
AudioConverter.floatChannelDataToPCMS16LE()
    ↓
PCM S16LE @ 16kHz → WebSocket binary frames
```

**Critical**: Call `audioEngine.prepare()` before `audioEngine.start()` to avoid initialization issues.

## BUILD

```bash
swift build --package-path Shared
swift test --package-path Shared
swift package --package-path Shared clean
```

## PLATFORM SUPPORT

- iOS 13.0+
- macOS 14.0+
- Swift 6.1

Uses conditional compilation:
```swift
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
```

## ANTI-PATTERNS

- Never use callbacks - use async/await
- Never force unwrap (exception: `SpeechProtocol.swift:34` static URL)
- Never suppress errors with empty catch blocks
- Never use `sendMessage()` for audio - use `sendAudioData()`
