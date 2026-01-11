import Foundation
import AVFoundation

public enum AudioConverter {
    /// 将 Float 通道数据转换为 PCM S16LE 格式并重采样
    /// - Parameters:
    ///   - floatData: 原始的浮点音频数据 (多通道)
    ///   - originalSampleRate: 原始采样率 (默认 48000 Hz)
    ///   - targetSampleRate: 目标采样率 (默认 16000 Hz)
    /// - Returns: PCM S16LE 格式的音频数据
    public static func floatChannelDataToPCMS16LE(
        _ floatData: [[Float]],
        originalSampleRate: Double = 48000,
        targetSampleRate: Double = 16000
    ) -> Data? {
        let channelCount = floatData.count
        guard channelCount > 0, floatData[0].count > 0 else {
            return nil
        }
        let frameCount = floatData[0].count
        
        // 1. 先创建原始格式的 Float32 buffer
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: originalSampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            return nil
        }
        
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            return nil
        }
        
        // 填充源 buffer (使用 memcpy 优化性能)
        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)
        if let floatChannelData = sourceBuffer.floatChannelData {
            for channel in 0..<channelCount {
                // 使用 memcpy 直接复制整个通道的数据
                _ = floatData[channel].withUnsafeBufferPointer { sourcePointer in
                    memcpy(floatChannelData[channel], 
                           sourcePointer.baseAddress, 
                           frameCount * MemoryLayout<Float>.stride)
                }
            }
        }
        
        // 2. 创建目标格式 (16000 Hz, Int16, 交织)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            return nil
        }
        
        // 3. 创建转换器
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }
        
        // 4. 计算输出帧数
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * targetSampleRate / originalSampleRate)
        
        // 5. 创建输出 buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else {
            return nil
        }
        
        // 6. 执行转换（重采样 + 格式转换）
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        if let error = error {
            print("Conversion error: \(error)")
            return nil
        }
        
        // 7. 提取 PCM 数据
        let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
        guard let dataPointer = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }
        let dataSize = Int(audioBuffer.mDataByteSize)
        
        return Data(bytes: dataPointer, count: dataSize)
    }
    
    public static func convertAudioBufferToPCMS16LE(_ inputBuffer: AVAudioPCMBuffer) -> Data? {
        // 创建目标格式
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000.0,
            channels: AVAudioChannelCount(1),
            interleaved: false
        ) else {
            print("Failed to create target format")
            return nil
        }
        
        // 创建转换器
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
            print("Failed to create audio converter")
            return nil
        }
        
        // 计算输出帧数
        let inputFrameCount = inputBuffer.frameLength
        let outputFrameCount = AVAudioFrameCount(
            Double(inputFrameCount) * targetFormat.sampleRate / inputBuffer.format.sampleRate
        )
        
        // 创建输出 buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else {
            print("Failed to create output buffer")
            return nil
        }
        
        // 执行转换
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if let error = error {
            print("Conversion error: \(error)")
            return nil
        }
        
        let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
        guard let dataPointer = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }
        let dataSize = Int(audioBuffer.mDataByteSize)
        
        return Data(bytes: dataPointer, count: dataSize)
    }

}
