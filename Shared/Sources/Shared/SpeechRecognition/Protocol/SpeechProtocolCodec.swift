import Foundation
import Compression

/// 字节跳动语音识别二进制协议编解码器
public enum SpeechProtocolCodec {
    
    // MARK: - GZIP 压缩/解压（使用 Apple Compression framework）
    
    public static func gzipCompress(_ data: Data) -> Data? {
        // GZIP header
        var compressed = Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
        
        // 处理空数据的情况 - 生成有效的空 GZIP
        if data.isEmpty {
            // 空数据的 deflate 压缩结果是固定的 [0x03, 0x00]
            compressed.append(contentsOf: [0x03, 0x00])
            // CRC32 of empty data is 0x00000000
            compressed.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            // Original size is 0
            compressed.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            return compressed
        }
        
        // Compress using COMPRESSION_ZLIB (deflate)
        let destinationBufferSize = data.count + 1024
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        
        let compressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let sourceBaseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                sourceBaseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard compressedSize > 0 else { return nil }
        
        compressed.append(contentsOf: destinationBuffer.prefix(compressedSize))
        
        // GZIP footer: CRC32 + original size (little-endian)
        let crc = crc32(data)
        compressed.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        compressed.append(contentsOf: withUnsafeBytes(of: UInt32(data.count).littleEndian) { Array($0) })
        
        return compressed
    }
    
    public static func gzipDecompress(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }  // Minimum GZIP size
        
        // Verify GZIP magic number
        guard data[0] == 0x1f && data[1] == 0x8b else { return nil }
        
        // Skip GZIP header (minimum 10 bytes) and footer (8 bytes)
        var headerSize = 10
        let flags = data[3]
        
        // Handle optional header fields
        if flags & 0x04 != 0 {  // FEXTRA
            let extraLen = Int(data[10]) | (Int(data[11]) << 8)
            headerSize += 2 + extraLen
        }
        if flags & 0x08 != 0 {  // FNAME
            while headerSize < data.count && data[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1
        }
        if flags & 0x10 != 0 {  // FCOMMENT
            while headerSize < data.count && data[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1
        }
        if flags & 0x02 != 0 {  // FHCRC
            headerSize += 2
        }
        
        let compressedData = data.subdata(in: headerSize..<(data.count - 8))
        
        // Get original size from footer
        let originalSize = data.suffix(4).withUnsafeBytes { ptr -> UInt32 in
            ptr.load(as: UInt32.self).littleEndian
        }
        
        // Decompress
        var destinationBuffer = [UInt8](repeating: 0, count: Int(originalSize) + 1024)
        
        let decompressedSize = compressedData.withUnsafeBytes { sourcePtr -> Int in
            guard let sourceBaseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                &destinationBuffer,
                destinationBuffer.count,
                sourceBaseAddress.assumingMemoryBound(to: UInt8.self),
                compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard decompressedSize > 0 else { return nil }
        
        return Data(destinationBuffer.prefix(decompressedSize))
    }
    
    // MARK: - CRC32 计算
    
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = makeCRC32Table()
        
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        
        return crc ^ 0xFFFFFFFF
    }
    
    private static func makeCRC32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }
    
    // MARK: - Header 构建
    
    public static func buildHeader(
        messageType: SpeechProtocol.MessageType,
        flags: SpeechProtocol.MessageFlags,
        serialization: SpeechProtocol.SerializationType = .json,
        compression: SpeechProtocol.CompressionType = .gzip
    ) -> Data {
        var header = Data(capacity: 4)
        header.append((SpeechProtocol.protocolVersion << 4) | SpeechProtocol.headerSize)
        header.append((messageType.rawValue << 4) | flags.rawValue)
        header.append((serialization.rawValue << 4) | compression.rawValue)
        header.append(0x00)  // reserved
        return header
    }
    
    // MARK: - Full Client Request
    
    public static func buildFullClientRequest(seq: Int32, payload: FullClientRequestPayload) throws -> Data {
        var request = Data()
        
        // Header
        request.append(buildHeader(
            messageType: .fullClientRequest,
            flags: .positiveSequence
        ))
        
        // Sequence (big-endian)
        var seqBE = seq.bigEndian
        withUnsafeBytes(of: &seqBE) { request.append(contentsOf: $0) }
        
        // Payload (JSON -> GZIP)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(payload)

        // Debug: 打印实际发送的 JSON
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📝 FullClientRequest JSON payload: \(jsonString)")
        }

        guard let compressed = gzipCompress(jsonData) else {
            throw SpeechRecognitionError.compressionFailed
        }
        
        // Payload size (big-endian)
        var sizeBE = Int32(compressed.count).bigEndian
        withUnsafeBytes(of: &sizeBE) { request.append(contentsOf: $0) }
        
        // Payload
        request.append(compressed)
        
        return request
    }
    
    // MARK: - Audio Only Request
    
    public static func buildAudioOnlyRequest(seq: Int32, audioData: Data) -> Data? {
        var request = Data()
        
        // Header - 最后一包用 negativeWithSequence
        let flags: SpeechProtocol.MessageFlags = seq < 0 ? .negativeWithSequence : .positiveSequence
        request.append(buildHeader(
            messageType: .audioOnlyRequest,
            flags: flags
        ))
        
        // Sequence (big-endian)
        var seqBE = seq.bigEndian
        withUnsafeBytes(of: &seqBE) { request.append(contentsOf: $0) }
        
        // Compress audio
        guard let compressed = gzipCompress(audioData) else { return nil }
        
        // Payload size (big-endian)
        var sizeBE = Int32(compressed.count).bigEndian
        withUnsafeBytes(of: &sizeBE) { request.append(contentsOf: $0) }
        
        // Payload
        request.append(compressed)
        
        return request
    }
    
    // MARK: - Response 解析
    
    public struct ParsedResponse: Sendable {
        public let code: Int
        public let isLastPackage: Bool
        public let sequence: Int32
        public let payload: SpeechResponsePayload?
        
        public init(code: Int, isLastPackage: Bool, sequence: Int32, payload: SpeechResponsePayload?) {
            self.code = code
            self.isLastPackage = isLastPackage
            self.sequence = sequence
            self.payload = payload
        }
    }
    
    public static func parseResponse(_ data: Data) -> ParsedResponse? {
        guard data.count >= 4 else { return nil }
        
        let headerSize = Int(data[0] & 0x0F) * 4
        let messageType = data[1] >> 4
        let flags = data[1] & 0x0F
        let compression = SpeechProtocol.CompressionType(rawValue: data[2] & 0x0F) ?? .none
        
        guard data.count > headerSize else {
            return ParsedResponse(code: 0, isLastPackage: false, sequence: 0, payload: nil)
        }
        
        var payload = data.dropFirst(headerSize)
        var code = 0
        var sequence: Int32 = 0
        var isLastPackage = false
        
        // 解析 flags
        if flags & 0x01 != 0 {  // has sequence
            guard payload.count >= 4 else { return nil }
            sequence = payload.prefix(4).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
            payload = payload.dropFirst(4)
        }
        if flags & 0x02 != 0 {  // is last package
            isLastPackage = true
        }
        
        // 解析 message type
        if messageType == SpeechProtocol.MessageType.fullServerResponse.rawValue {
            guard payload.count >= 4 else { return nil }
            // Skip payload size, we'll read until the end
            payload = payload.dropFirst(4)
        } else if messageType == SpeechProtocol.MessageType.serverErrorResponse.rawValue {
            guard payload.count >= 8 else { return nil }
            code = Int(payload.prefix(4).withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
            payload = payload.dropFirst(8)  // code + size
        }
        
        // 解压并解析 JSON payload
        var responsePayload: SpeechResponsePayload?
        if !payload.isEmpty {
            var decompressed = Data(payload)
            if compression == .gzip {
                decompressed = gzipDecompress(Data(payload)) ?? Data(payload)
            }
            
            let decoder = JSONDecoder()
            responsePayload = try? decoder.decode(SpeechResponsePayload.self, from: decompressed)
        }
        
        return ParsedResponse(
            code: code,
            isLastPackage: isLastPackage,
            sequence: sequence,
            payload: responsePayload
        )
    }
}
