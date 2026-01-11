import Foundation

/// 设置存储服务 - 使用 UserDefaults 存储用户偏好设置
final class SettingsStorage {
    static let shared = SettingsStorage()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let hotkeyConfiguration = "settings.hotkey.configuration"
        static let overCommandEnabled = "settings.voiceInput.overCommandEnabled"
    }

    private init() {}

    // MARK: - Hotkey Configuration

    func saveHotkeyConfiguration(_ config: HotkeyConfiguration) {
        do {
            let data = try JSONEncoder().encode(config)
            userDefaults.set(data, forKey: Keys.hotkeyConfiguration)
            print("Hotkey configuration saved: \(config.hotkeys.count) hotkeys")
        } catch {
            print("Failed to save hotkey configuration: \(error)")
        }
    }

    func loadHotkeyConfiguration() -> HotkeyConfiguration {
        guard let data = userDefaults.data(forKey: Keys.hotkeyConfiguration) else {
            print("No saved hotkey configuration, using default")
            return .defaultConfiguration
        }

        do {
            let config = try JSONDecoder().decode(HotkeyConfiguration.self, from: data)
            print("✅ Hotkey configuration loaded: \(config.hotkeys.count) hotkeys")
            return config
        } catch {
            print("⚠️ Failed to load hotkey configuration: \(error)")
            return .defaultConfiguration
        }
    }

    func resetHotkeyConfiguration() {
        userDefaults.removeObject(forKey: Keys.hotkeyConfiguration)
        print("Hotkey configuration reset to default")
    }
    
    // MARK: - Voice Input Settings
    
    /// "Over" 快捷发送功能是否启用（默认开启）
    var isOverCommandEnabled: Bool {
        get {
            // 如果没有设置过，默认为 true
            if userDefaults.object(forKey: Keys.overCommandEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.overCommandEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.overCommandEnabled)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// 快捷键配置变更通知
    static let hotkeyConfigurationChanged = Notification.Name("hotkeyConfigurationChanged")
}

// MARK: - Notification Helper

extension SettingsStorage {
    /// 发送配置变更通知
    func notifyConfigurationChanged(_ config: HotkeyConfiguration) {
        NotificationCenter.default.post(
            name: .hotkeyConfigurationChanged,
            object: nil,
            userInfo: ["configuration": config]
        )
    }
}
