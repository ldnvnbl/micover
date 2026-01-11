import AVFoundation
import CoreAudio

#if os(macOS)
import AppKit
#endif

public struct AudioInputDevice: Identifiable, Hashable, Sendable {
    public let id: UInt32
    public let name: String
    public let isBuiltIn: Bool
    public let transportType: String
    
    public init(id: UInt32, name: String, isBuiltIn: Bool, transportType: String = "") {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.transportType = transportType
    }
}

@Observable
@MainActor
public final class AudioDeviceManager {
    public static let shared = AudioDeviceManager()
    
    public private(set) var availableDevices: [AudioInputDevice] = []
    public private(set) var systemDefaultDevice: AudioInputDevice?
    
    public var selectedDeviceId: UInt32? {
        didSet {
            saveSelectedDevice()
        }
    }
    
    private let userDefaultsKey = "settings.audio.selectedMicrophoneId"
    
    private init() {
        loadSelectedDevice()
        refreshDevices()
        setupDeviceChangeListener()
    }
    
    // MARK: - Public Methods
    
    public func refreshDevices() {
        #if os(macOS)
        availableDevices = fetchAvailableInputDevices()
        systemDefaultDevice = fetchDefaultInputDevice()
        #else
        availableDevices = []
        systemDefaultDevice = nil
        #endif
    }
    
    public func getEffectiveDeviceId() -> UInt32? {
        guard let selectedId = selectedDeviceId else {
            return nil
        }
        
        if availableDevices.contains(where: { $0.id == selectedId }) {
            return selectedId
        }
        
        return nil
    }
    
    public func getCurrentDeviceDisplayName() -> String {
        if let selectedId = selectedDeviceId,
           let device = availableDevices.first(where: { $0.id == selectedId }) {
            return device.name
        }
        
        if let defaultDevice = systemDefaultDevice {
            return "自动检测 (\(defaultDevice.name))"
        }
        
        return "自动检测"
    }
    
    // MARK: - Private Methods
    
    private func loadSelectedDevice() {
        let value = UserDefaults.standard.object(forKey: userDefaultsKey)
        if let intValue = value as? Int, intValue > 0 {
            selectedDeviceId = UInt32(intValue)
        } else {
            selectedDeviceId = nil
        }
    }
    
    private func saveSelectedDevice() {
        if let deviceId = selectedDeviceId {
            UserDefaults.standard.set(Int(deviceId), forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
    
    #if os(macOS)
    private func fetchAvailableInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return [] }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIds = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIds
        )
        
        guard status == noErr else { return [] }
        
        var inputDevices: [AudioInputDevice] = []
        
        for deviceId in deviceIds {
            guard hasInputChannels(deviceId: deviceId) else { continue }
            guard let name = getDeviceName(deviceId: deviceId) else { continue }
            if name.contains("CADefaultDeviceAggregate") { continue }
            
            let isBuiltIn = isBuiltInDevice(deviceId: deviceId)
            let transportType = getDeviceTransportType(deviceId: deviceId)
            
            inputDevices.append(AudioInputDevice(
                id: deviceId,
                name: name,
                isBuiltIn: isBuiltIn,
                transportType: transportType
            ))
        }
        
        return inputDevices.sorted { $0.isBuiltIn && !$1.isBuiltIn }
    }
    
    private func fetchDefaultInputDevice() -> AudioInputDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceId: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceId
        )
        
        guard status == noErr, deviceId != 0 else { return nil }
        
        guard let name = getDeviceName(deviceId: deviceId) else { return nil }
        let isBuiltIn = isBuiltInDevice(deviceId: deviceId)
        let transportType = getDeviceTransportType(deviceId: deviceId)
        
        return AudioInputDevice(id: deviceId, name: name, isBuiltIn: isBuiltIn, transportType: transportType)
    }
    
    private func hasInputChannels(deviceId: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, nil, &dataSize)
        
        guard status == noErr, dataSize > 0 else { return false }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        let getStatus = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &dataSize, bufferListPointer)
        guard getStatus == noErr else { return false }
        
        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceName(deviceId: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &dataSize, &name)
        
        guard status == noErr else { return nil }
        
        return name as String
    }
    
    private func isBuiltInDevice(deviceId: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &dataSize, &transportType)
        
        guard status == noErr else { return false }
        
        return transportType == kAudioDeviceTransportTypeBuiltIn
    }
    
    private func getDeviceTransportType(deviceId: AudioDeviceID) -> String {
        // 先尝试获取 DataSource 名称（如 "Microphone port"）
        if let sourceName = getDataSourceName(deviceId: deviceId) {
            return sourceName
        }
        
        // 回退到 TransportType
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &dataSize, &transportType)
        
        guard status == noErr else { return "" }
        
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return "Built-in"
        case kAudioDeviceTransportTypeUSB:
            return "USB"
        case kAudioDeviceTransportTypeBluetooth:
            return "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE:
            return "Bluetooth LE"
        case kAudioDeviceTransportTypeThunderbolt:
            return "Thunderbolt"
        case kAudioDeviceTransportTypeHDMI:
            return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort:
            return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay:
            return "AirPlay"
        case kAudioDeviceTransportTypeAVB:
            return "AVB"
        case kAudioDeviceTransportTypeFireWire:
            return "FireWire"
        case kAudioDeviceTransportTypePCI:
            return "PCI"
        case kAudioDeviceTransportTypeVirtual:
            return "Virtual"
        case kAudioDeviceTransportTypeAggregate:
            return "Aggregate"
        default:
            return ""
        }
    }
    
    private func getDataSourceName(deviceId: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sourceCode: UInt32 = 0
        var propSize = UInt32(MemoryLayout<UInt32>.size)
        
        let err = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &propSize, &sourceCode)
        guard err == noErr, sourceCode != 0 else { return nil }
        
        switch sourceCode {
        case 0x656d6963: // 'emic' - External Microphone (3.5mm jack)
            return "Microphone port"
        case 0x696d6963: // 'imic' - Internal Microphone
            return "Internal Microphone"
        case 0x6c696e72: // 'linr' - Line In
            return "Line In"
        default:
            return nil
        }
    }
    
    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
    }
    #endif
}
