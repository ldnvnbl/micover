import SwiftUI
import Shared

struct MicrophonePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private var deviceManager: AudioDeviceManager { AudioDeviceManager.shared }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    autoDetectOption
                    
                    ForEach(deviceManager.availableDevices) { device in
                        deviceOption(device)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            deviceManager.refreshDevices()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("选择麦克风")
                .font(.headline)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var autoDetectOption: some View {
        let isSelected = deviceManager.selectedDeviceId == nil
        let defaultDeviceName = deviceManager.systemDefaultDevice?.name ?? "系统默认"
        
        return Button {
            deviceManager.selectedDeviceId = nil
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动检测 (\(defaultDeviceName))")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("使用系统默认麦克风")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func deviceOption(_ device: AudioInputDevice) -> some View {
        let isSelected = deviceManager.selectedDeviceId == device.id
        
        return Button {
            deviceManager.selectedDeviceId = device.id
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if !device.transportType.isEmpty {
                        Text(device.transportType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MicrophonePickerSheet()
}
