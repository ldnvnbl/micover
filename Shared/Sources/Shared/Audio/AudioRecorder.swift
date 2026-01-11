import AVFoundation
import CoreAudio

public struct RawAudioData: Sendable {
    var data: [[Float]]
    var sampleRate: Double
}


public actor AudioRecorder {
    private var isRecording = false
    
    // 公开的只读属性
    public var recording: Bool {
        isRecording
    }

    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var rawAudioStreamContinuation: AsyncStream<RawAudioData>.Continuation?

    public init() {
    }

    public func startRecording(inputDeviceId: UInt32? = nil) async throws -> AsyncStream<RawAudioData> {
        guard !isRecording else {
            throw AudioError.recordingInProgress
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioError.deviceNotAvailable
        }
        
        #if os(macOS)
        try configureInputDevice(for: inputNode, deviceId: inputDeviceId)
        #endif
        
        let (stream, continuation) = AsyncStream.makeStream(of: RawAudioData.self)
        self.rawAudioStreamContinuation = continuation
        
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4800,
            format: inputNode.outputFormat(forBus: 0)
        ) { buffer, _ in
            
            guard let data = buffer.toFloatChannelData() else {
                return
            }
            continuation.yield(RawAudioData(data: data, sampleRate: buffer.format.sampleRate))
        }

        do {
            // Prepare the engine before starting to avoid initialization issues
            audioEngine.prepare()
            try audioEngine.start()

            // Update recording state
            self.isRecording = true

            return stream
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioError.unknownError(error.localizedDescription)
        }
    }

    public func stopRecording() async {
        guard isRecording else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()

        rawAudioStreamContinuation?.finish()
        rawAudioStreamContinuation = nil

        // Update recording state
        self.isRecording = false

        print("Recording stopped")
    }
    
    #if os(macOS)
    private func configureInputDevice(for inputNode: AVAudioInputNode, deviceId: UInt32?) throws {
        guard let audioUnit = inputNode.audioUnit else { return }
        guard let deviceId = deviceId else { return }
        
        var mutableDeviceId = deviceId
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceId,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status != noErr {
            print("Failed to set input device: \(status)")
        }
    }
    #endif
}
