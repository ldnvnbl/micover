import Foundation

/// 轻量级 multipart/form-data 编码器
/// 用于构建 HTTP 文件上传请求体，无需第三方依赖
struct MultipartFormData {
    private let boundary: String
    private var body = Data()

    /// Content-Type header 值（含 boundary）
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    /// 添加文本字段
    mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    /// 添加文件字段
    mutating func addFile(name: String, fileName: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }

    /// 完成编码，返回最终的请求体数据
    func finalize() -> Data {
        var result = body
        result.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return result
    }
}
