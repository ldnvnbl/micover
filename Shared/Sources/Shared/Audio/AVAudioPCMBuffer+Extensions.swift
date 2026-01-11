import AVFoundation

public extension AVAudioPCMBuffer {
    
    func toFloatChannelData() -> [[Float]]? {
        guard let pcmFloatChannelData = floatChannelData else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        let frameLength = Int(self.frameLength)
        let stride = self.stride

        var result = Array(repeating: [Float](repeating: 0, count: frameLength), count: channelCount)

        for channel in 0 ..< channelCount {
            result[channel].withUnsafeMutableBufferPointer { destBuffer in
                let srcPointer = pcmFloatChannelData[channel]
                if stride == 1 {
                    // Direct memory copy when no striding needed
                    memcpy(destBuffer.baseAddress!,
                           srcPointer,
                           frameLength * MemoryLayout<Float>.size)
                } else {
                    // Fall back to loop for strided data
                    for i in 0 ..< frameLength {
                        destBuffer[i] = srcPointer[i * stride]
                    }
                }
            }
        }

        return result
    }}
