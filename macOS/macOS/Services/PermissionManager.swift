import Foundation
import AVFoundation
import AppKit
import Observation
import CoreGraphics

@Observable
@MainActor
final class PermissionManager {
    enum PermissionType {
        case microphone
        case accessibility
    }

    var microphoneStatus: AVAuthorizationStatus = .notDetermined
    var accessibilityStatus: Bool = false

    private var permissionCheckTask: Task<Void, Never>?
    private let maxCheckCount = 120 // Allow up to 120 seconds of follow-up checks

    init() {
        checkPermissions()
        setupNotificationObservers()
    }

    // MARK: - Public Methods
    
    func checkPermissions() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityStatus = checkAccessibilityPermissionRealtime()
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                microphoneStatus = .authorized
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    Task { @MainActor in
                        if let self {
                            self.microphoneStatus = granted ? .authorized : .denied
                        }
                        continuation.resume(returning: granted)
                    }
                }
            case .denied, .restricted:
                microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func requestAccessibilityPermission() {
        print("🔑 requestAccessibilityPermission() called")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessibilityStatus = AXIsProcessTrustedWithOptions(options)
        print("🔑 After prompt, accessibilityStatus = \(accessibilityStatus)")
        
        if !hasAccessibilityPermission {
            print("🔑 Permission not granted yet, starting monitoring...")
            startMonitoringAccessibilityPermission()
        }
    }
    
    func openSystemPreferences(for type: PermissionType) {
        var urlString: String
        var shouldStartMonitoring = false
        
        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            shouldStartMonitoring = true
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            if shouldStartMonitoring && !hasAccessibilityPermission {
                startMonitoringAccessibilityPermission()
            }
        }
    }
    
    var hasMicrophonePermission: Bool {
        microphoneStatus == .authorized
    }
    
    var hasAccessibilityPermission: Bool {
        accessibilityStatus
    }
    
    var allPermissionsGranted: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }
    
    // MARK: - Private Methods

    private func startMonitoringAccessibilityPermission() {
        print("🚀 startMonitoringAccessibilityPermission() called")
        // Cancel any existing monitoring task
        stopMonitoringAccessibilityPermission()

        // Check current status immediately
        checkAccessibilityStatus()

        // If permission not granted, start polling with Task.sleep (avoids Timer/RunLoop issues)
        guard !accessibilityStatus else { 
            print("✅ Permission already granted, no need to monitor")
            return 
        }
        
        print("⏱️ Starting permission polling task...")
        let maxChecks = maxCheckCount
        permissionCheckTask = Task { [weak self] in
            print("⏱️ Polling task started")
            for checkCount in 1...maxChecks {
                // Check if task was cancelled
                if Task.isCancelled { 
                    print("⏱️ Task cancelled at check #\(checkCount)")
                    break 
                }
                
                // Wait 1 second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                guard let self, !Task.isCancelled else { 
                    print("⏱️ Self is nil or task cancelled")
                    break 
                }
                
                print("⏱️ Accessibility permission check #\(checkCount), current status: \(self.accessibilityStatus)")
                self.checkAccessibilityStatus()
                
                // Stop if permission granted
                if self.accessibilityStatus {
                    print("✅ Accessibility permission granted after \(checkCount) checks")
                    break
                }
            }
            
            print("🛑 Accessibility permission monitoring stopped")
        }
        print("⏱️ Permission polling task created: \(permissionCheckTask != nil)")
    }

    private func stopMonitoringAccessibilityPermission() {
        permissionCheckTask?.cancel()
        permissionCheckTask = nil
    }

    private func checkAccessibilityStatus() {
        let newStatus = checkAccessibilityPermissionRealtime()
        if newStatus != accessibilityStatus {
            print("🔄 Accessibility permission changed: \(accessibilityStatus) -> \(newStatus)")
            accessibilityStatus = newStatus

            // Stop monitoring if permission was granted
            if newStatus {
                stopMonitoringAccessibilityPermission()
            }
        }
    }

    // MARK: - Real-time Accessibility Permission Check

    /// Checks accessibility permission using AXIsProcessTrusted()
    /// Note: CGEvent.tapCreate() requires app restart to detect newly granted permissions,
    /// so we use AXIsProcessTrusted() which updates more reliably during the same session.
    private nonisolated func checkAccessibilityPermissionRealtime() -> Bool {
        let result = AXIsProcessTrusted()
        print("🔍 AXIsProcessTrusted() = \(result)")
        return result
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Monitor distributed notification center for accessibility changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )

        // Monitor app activation events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        print("📡 Started monitoring accessibility permission changes via notifications")
    }

    private nonisolated func removeNotificationObservers() {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func accessibilityChanged(_ notification: Notification) {
        print("🔔 Received accessibility change notification, current status: \(accessibilityStatus)")
        // Delay the check slightly to allow the system to finalize the permission state.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self?.checkAccessibilityStatus()
        }
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        print("🔄 App became active, checking permissions...")
        Task { @MainActor [weak self] in
            self?.checkPermissions()
        }
    }
}
