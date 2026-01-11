import SwiftUI
import AVFoundation

struct PermissionRequestView: View {
    @State private var permissionManager = PermissionManager()
    let onPermissionsGranted: () -> Void
    
    var body: some View {
        @Bindable var manager = permissionManager
        let allPermissionsGranted = manager.allPermissionsGranted
        
        VStack(spacing: 32) {
            // Top section with logo and title
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(radius: 5)
                
                Text("MicOver")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("需要您的授权才能开始")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Permission cards
            VStack(spacing: 20) {
                // Microphone permission card
                MicrophonePermissionCard(
                    microphoneStatus: manager.microphoneStatus,
                    onRequestPermission: requestMicrophonePermission,
                    onOpenSettings: openMicrophoneSettings
                )
                
                // Accessibility permission card
                AccessibilityPermissionCard(
                    isGranted: manager.hasAccessibilityPermission,
                    onRequestPermission: requestAccessibilityPermission
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue button
            Button(action: {
                onPermissionsGranted()
            }) {
                Text("继续")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!allPermissionsGranted)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .opacity(allPermissionsGranted ? 1 : 0.6)
            .animation(.easeInOut, value: allPermissionsGranted)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // PermissionManager will automatically start monitoring on init
            permissionManager.checkPermissions()
        }
    }
    
    private func requestMicrophonePermission() {
        Task {
            await permissionManager.requestMicrophonePermission()
        }
    }
    
    private func openMicrophoneSettings() {
        permissionManager.openSystemPreferences(for: .microphone)
    }
    
    private func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
    }
}

struct MicrophonePermissionCard: View {
    let microphoneStatus: AVAuthorizationStatus
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    
    var isGranted: Bool {
        microphoneStatus == .authorized
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isGranted ? .green : .gray)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("麦克风权限")
                    .font(.headline)
                
                Text(permissionDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator and button
            permissionButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isGranted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
    
    private var permissionDescription: String {
        switch microphoneStatus {
        case .denied, .restricted:
            return "请在系统设置中允许访问麦克风"
        default:
            return "用于识别您的语音输入"
        }
    }
    
    @ViewBuilder
    private var permissionButton: some View {
        switch microphoneStatus {
        case .authorized:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
                
                Text("已授权")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .transition(.scale.combined(with: .opacity))
            
        case .denied, .restricted:
            Button("打开设置") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
        case .notDetermined:
            Button("授权") {
                onRequestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
        @unknown default:
            Button("授权") {
                onRequestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
}

struct AccessibilityPermissionCard: View {
    let isGranted: Bool
    let onRequestPermission: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "accessibility")
                    .font(.system(size: 28))
                    .foregroundColor(isGranted ? .green : .gray)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("辅助功能权限")
                    .font(.headline)
                
                Text("用于将文字输入到其他应用")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator and button
            if isGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                    
                    Text("已授权")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button("授权") {
                    onRequestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isGranted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}

#Preview {
    PermissionRequestView(onPermissionsGranted: {
        print("Permissions granted!")
    })
}
