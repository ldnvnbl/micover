import Foundation
import KeychainAccess
import CryptoKit

public class KeychainManager {
    private let keychain: Keychain
    
    // Keys for storing data
    private enum Keys {
        static let deviceID = "device.id"
    }
    
    public init(service: String) {
        self.keychain = Keychain(service: service)
    }
    
    // MARK: - Device ID Management
    
    public func saveDeviceID(_ deviceID: String) throws {
        try keychain.set(deviceID, key: Keys.deviceID)
    }
    
    public func getDeviceID() throws -> String? {
        return try keychain.get(Keys.deviceID)
    }
    
    public func getOrCreateDeviceID() throws -> String {
        if let existingID = try getDeviceID() {
            return existingID
        }
        
        // Generate a new device ID that passes server validation:
        // - Total length: 40 characters
        // - First 8 chars: SHA256 hash prefix of the last 32 chars
        // - Last 32 chars: Random hex string
        
        // Generate 16 random bytes (will become 32 hex characters)
        let randomBytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        let suffix = randomBytes.map { String(format: "%02x", $0) }.joined()
        
        // Calculate SHA256 hash of the suffix
        let suffixData = Data(suffix.utf8)
        let hash = SHA256.hash(data: suffixData)
        let hashHex = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Take first 8 characters of the hash as prefix
        let prefix = String(hashHex.prefix(8))
        
        // Combine prefix and suffix to create 40-character device ID
        let newDeviceID = prefix + suffix
        
        try saveDeviceID(newDeviceID)
        return newDeviceID
    }
    
    // MARK: - Clear All Data
    
    public func clearAll() throws {
        try keychain.removeAll()
    }
}
