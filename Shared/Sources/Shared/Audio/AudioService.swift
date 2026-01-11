import AVFoundation

#if os(macOS)
import AppKit
#endif


@Observable
@MainActor
public final class AudioService {
    public private(set) var isRecording = false
    
    private let audioRecorder: AudioRecorder
    
    private var processedDataContinuation: AsyncStream<Data>.Continuation?
    private var audioConversionTask: Task<Void, Never>?
    
    public init() {
        self.audioRecorder = AudioRecorder()
    }
    
    public func startRecording() async throws -> AsyncStream<Data> {
        #if os(macOS)
        let inputDeviceId = AudioDeviceManager.shared.getEffectiveDeviceId()
        let rawStream = try await self.audioRecorder.startRecording(inputDeviceId: inputDeviceId)
        #else
        let rawStream = try await self.audioRecorder.startRecording()
        #endif
        
        self.isRecording = await self.audioRecorder.recording
        
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        self.processedDataContinuation = continuation
        
        // 在后台任务中处理音频转换
        self.audioConversionTask = Task {
            defer {
                continuation.finish()
            }
            
            for await audioRawData in rawStream {
                // 转换音频格式: Float32 48kHz -> PCM S16LE 16kHz
                let startTime = CFAbsoluteTimeGetCurrent()
                
                if let pcmData = AudioConverter.floatChannelDataToPCMS16LE(
                    audioRawData.data,
                    originalSampleRate: audioRawData.sampleRate,
                    targetSampleRate: 16000
                ) {
                    let convertTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    // 处理转换后的 PCM 数据
                    // print("Converted PCM data size: \(pcmData.count) bytes, took \(String(format: "%.2f", convertTime)) ms")
                    
                    // 通过 stream 传递数据
                    continuation.yield(pcmData)
                } else {
                    print("Failed to convert audio data chunk")
                }
            }
        }
        return stream
    }
    
    public func stopRecording() async {
        // 停止录音
        await self.audioRecorder.stopRecording()
        self.isRecording = await self.audioRecorder.recording

        // 等待转换任务完成，而不是立即取消
        if let task = audioConversionTask {
            // 给任务一个完成的机会
            await task.value
        }
        audioConversionTask = nil
        
        // 完成 stream
        processedDataContinuation?.finish()
        processedDataContinuation = nil
    }
}


extension AudioService {
    public func requestPermission() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #elseif os(macOS)
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
        #else
        return true
        #endif
    }

    public static func checkPermissionStatus() -> Bool {
        #if os(iOS)
        return AVAudioSession.sharedInstance().recordPermission == .granted
        #elseif os(macOS)
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        #else
        return true
        #endif
    }
    
    public static func getPermissionStatus() -> AVAuthorizationStatus {
        #if os(iOS)
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .authorized
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
        #elseif os(macOS)
        return AVCaptureDevice.authorizationStatus(for: .audio)
        #else
        return .authorized
        #endif
    }
    
    public static func openSystemPreferences() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
