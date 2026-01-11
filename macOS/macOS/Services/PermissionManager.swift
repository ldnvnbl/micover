import Foundation
import AVFoundation
import AppKit
import Observation
import CoreGraphics

@Observable
final class PermissionManager {
    enum PermissionType {
        case microphone
        case accessibility
    }

    var microphoneStatus: AVAuthorizationStatus = .notDetermined
    var accessibilityStatus: Bool = false

    private var permissionCheckTimer: Timer?
    private var timerCheckCount = 0
    private let maxTimerChecks = 120 // Allow up to 120 seconds of follow-up checks

    init() {
        checkPermissions()
        setupNotificationObservers()
    }

    deinit {
        stopMonitoringAccessibilityPermission()
        removeNotificationObservers()
    }
    
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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessibilityStatus = AXIsProcessTrustedWithOptions(options)
        
        if !hasAccessibilityPermission {
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
        // 停止之前的定时器（如果有）
        stopMonitoringAccessibilityPermission()

        // 立即检查一次当前状态
        checkAccessibilityStatus()

        // 如果权限未授予，启动最长 120 秒的轮询定时器
        if !accessibilityStatus {
            timerCheckCount = 0
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }

                    print("⏱️ Accessibility permission timer check #\(self.timerCheckCount + 1), current status: \(self.accessibilityStatus)")
                    self.checkAccessibilityStatus()
                    self.timerCheckCount += 1

                    // 达到最大检查次数或权限已授予时停止 timer
                    if self.timerCheckCount >= self.maxTimerChecks || self.accessibilityStatus {
                        timer.invalidate()
                        self.permissionCheckTimer = nil
                        print("✅ Accessibility permission timer stopped after \(self.timerCheckCount) checks")
                    }
                }

                // 确保 Timer 立即运行
                if let timer = self.permissionCheckTimer {
                    RunLoop.current.add(timer, forMode: .common)
                }
            }
        }
    }

    private func stopMonitoringAccessibilityPermission() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        timerCheckCount = 0
    }

    private func checkAccessibilityStatus() {
        let newStatus = checkAccessibilityPermissionRealtime()
        if newStatus != accessibilityStatus {
            print("🔄 Accessibility permission changed: \(accessibilityStatus) -> \(newStatus)")
            accessibilityStatus = newStatus

            // 如果权限已授予且 timer 还在运行，停止它
            if newStatus && permissionCheckTimer != nil {
                stopMonitoringAccessibilityPermission()
            }
        }
    }

    // MARK: - Real-time Accessibility Permission Check

    /// Uses CGEvent.tapCreate to check accessibility permission in real-time
    /// This method doesn't cache results and can detect permission changes without app restart
    private func checkAccessibilityPermissionRealtime() -> Bool {
        // Try to create an event tap - this will fail if we don't have accessibility permission
        // We use .listenOnly to avoid triggering the system permission dialog
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,           // Tap at HID level
            place: .headInsertEventTap,    // Insert at head of list
            options: .listenOnly,          // Listen only - doesn't trigger permission dialog
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue), // Monitor key events
            callback: { _, _, _, _ in nil },  // Minimal callback that returns nil
            userInfo: nil                  // No user info needed
        )

        if let tap = tap {
            // Permission granted - clean up the tap immediately
            CFMachPortInvalidate(tap)
            print("✅ CGEvent.tapCreate succeeded - Accessibility permission granted")
            return true
        } else {
            // Permission denied or not yet granted
            print("❌ CGEvent.tapCreate failed - Accessibility permission not granted")
            return false
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // 监听分布式通知中心的 accessibility 变化
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )

        // 监听应用激活事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        print("📡 Started monitoring accessibility permission changes via notifications")
    }

    private func removeNotificationObservers() {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func accessibilityChanged(_ notification: Notification) {
        print("🔔 Received accessibility change notification, current status: \(accessibilityStatus)")
        // Delay the check slightly to allow the system to finalize the permission state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAccessibilityStatus()
        }
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        print("🔄 App became active, checking permissions...")
        checkPermissions()
    }
}
