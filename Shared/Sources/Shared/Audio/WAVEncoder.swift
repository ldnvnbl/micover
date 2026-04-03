import Foundation

/// 将原始 PCM 数据封装为 WAV 文件格式（内存中）
/// WAV = 44 字节 RIFF 头 + 原始 PCM 数据，零转码开销
public enum WAVEncoder {
    /// 将 PCM 数据编码为 WAV
    /// - Parameters:
    ///   - pcmData: 原始 PCM 音频数据（例如 S16LE）
    ///   - sampleRate: 采样率（例如 16000）
    ///   - channels: 声道数（例如 1 = 单声道）
    ///   - bitsPerSample: 每个采样的位数（例如 16）
    /// - Returns: 包含 RIFF/WAV 头的完整 WAV 文件数据
    public static func encode(pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let fileSize = UInt32(36) + dataSize

        var header = Data(capacity: 44)

        // RIFF chunk descriptor
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.appendLittleEndian(fileSize)
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt sub-chunk
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.appendLittleEndian(UInt32(16))                 // sub-chunk size
        header.appendLittleEndian(UInt16(1))                  // PCM format
        header.appendLittleEndian(UInt16(channels))
        header.appendLittleEndian(UInt32(sampleRate))
        header.appendLittleEndian(UInt32(byteRate))
        header.appendLittleEndian(UInt16(blockAlign))
        header.appendLittleEndian(UInt16(bitsPerSample))

        // data sub-chunk
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.appendLittleEndian(dataSize)

        return header + pcmData
    }
}

// MARK: - Data helpers for little-endian encoding

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
