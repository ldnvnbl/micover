import Foundation
import Shared

actor RecordingCoordinator {
    private var audioStreamTask: Task<Void, Never>?
    private var packetCount: Int = 0
    
    func startRecording(
        audioService: AudioService,
        speechService: SpeechRecognitionService,
        appState: AppState
    ) async throws -> AsyncStream<SpeechRecognitionResult> {
        let hasPermission = await audioService.requestPermission()
        guard hasPermission else {
            throw RecordingError.permissionDenied
        }

        packetCount = 0

        // 1. 先建立语音识别连接，等待服务端就绪。
        //    这样可以避免在音频引擎已启动的情况下因为连接失败/超时
        //    而需要立刻停止音频，造成 CoreAudio IOThread 状态不一致。
        let resultStream = try await speechService.startSession()

        // 2. 语音通道就绪后再启动音频采集。
        let audioStream: AsyncStream<Data>
        do {
            audioStream = try await audioService.startRecording()
        } catch {
            await speechService.disconnect()
            throw error
        }

        audioStreamTask = Task {
            for await audioData in audioStream {
                guard !Task.isCancelled else { break }
                do {
                    try await speechService.sendAudioData(audioData)
                    packetCount += 1
                    let count = packetCount
                    await MainActor.run {
                        appState.recordedPackets = count
                    }

                } catch {
                    print("❌ Failed to send audio: \(error)")
                }
            }
        }

        return resultStream
    }
    
    func stopRecording(
        audioService: AudioService,
        speechService: SpeechRecognitionService,
        appState: AppState
    ) async {
        // 1. 先停止录音，这会让 audioStream 结束
        await audioService.stopRecording()
        
        // 2. 等待音频流任务自然完成（处理完所有积压的数据）
        if let task = audioStreamTask {
            await task.value
        }
        audioStreamTask = nil
        
        // 3. 所有音频数据都发送完成后，再发送最后一包
        do {
            try await speechService.sendAudioData(Data(), isLast: true)
        } catch {
            print("❌ Failed to send final packet: \(error)")
        }
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case apiKeyNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .recordingFailed(let reason):
            return "录音失败: \(reason)"
        case .apiKeyNotConfigured:
            return "请先在设置中配置 API Key"
        }
    }
}
