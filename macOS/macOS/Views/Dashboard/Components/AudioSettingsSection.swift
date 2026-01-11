import SwiftUI
import Shared

struct AudioSettingsSection: View {
    private var deviceManager: AudioDeviceManager { AudioDeviceManager.shared }
    @State private var showMicrophonePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "mic")
                    .font(.subheadline)
                Text("音频")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .padding(.leading, 4)
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("麦克风")
                            .font(.body)
                        
                        Text("选择用于语音录制的麦克风设备")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showMicrophonePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(deviceManager.getCurrentDeviceDisplayName())
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .sheet(isPresented: $showMicrophonePicker) {
            MicrophonePickerSheet()
        }
    }
}

#Preview {
    AudioSettingsSection()
        .frame(width: 600)
        .padding()
}
