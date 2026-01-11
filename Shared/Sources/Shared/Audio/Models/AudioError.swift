import Foundation

public enum AudioError: LocalizedError, Sendable {
    case engineNotFound
    case formatCreationFailed
    case converterCreationFailed
    case conversionFailed(Error)
    case recordingInProgress
    case notRecording
    case permissionDenied
    case deviceNotAvailable
    case bufferAllocationFailed
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .engineNotFound:
            return "Audio engine could not be initialized"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .conversionFailed(let error):
            return "Audio conversion failed: \(error.localizedDescription)"
        case .recordingInProgress:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording in progress"
        case .permissionDenied:
            return "Microphone permission denied"
        case .deviceNotAvailable:
            return "Audio input device not available"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .unknownError(let message):
            return "Audio error: \(message)"
        }
    }
}
