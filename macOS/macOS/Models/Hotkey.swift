import Foundation
import AppKit
import HotKey

/// 快捷键类型
enum HotkeyType: String, Codable, CaseIterable {
    case fnKey           // Fn 键
    case keyWithModifiers // 普通按键（可带修饰键）
}

/// 表示一个快捷键配置
struct Hotkey: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let type: HotkeyType
    let keyCode: UInt16?              // 普通按键的 keyCode，Fn/修饰键为 nil
    let modifierFlags: UInt?          // 修饰键标志
    let displayName: String           // 显示名称

    init(id: UUID = UUID(), type: HotkeyType, keyCode: UInt16? = nil,
         modifierFlags: UInt? = nil, displayName: String) {
        self.id = id
        self.type = type
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.displayName = displayName
    }

    /// 预定义的 Fn 键快捷键
    static let fnKey = Hotkey(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        type: .fnKey,
        keyCode: nil,
        modifierFlags: nil,
        displayName: "Fn"
    )

    /// 从按键事件创建快捷键（普通按键）
    static func fromKeyEvent(_ event: NSEvent) -> Hotkey? {
        guard event.type == .keyDown else { return nil }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 过滤掉 Fn 键修饰符，只保留标准修饰键
        let cleanModifiers = modifiers.subtracting(.function)

        // 构建显示名称
        let displayName = buildDisplayName(keyCode: keyCode, modifiers: cleanModifiers)

        return Hotkey(
            type: .keyWithModifiers,
            keyCode: keyCode,
            modifierFlags: cleanModifiers.isEmpty ? nil : cleanModifiers.rawValue,
            displayName: displayName
        )
    }

    /// 构建显示名称
    private static func buildDisplayName(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }

        parts.append(keyCodeToString(keyCode))

        return parts.joined(separator: "+")
    }

    /// 将 keyCode 转换为可读字符串
    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            // 字母键
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x1F: "O", 0x20: "U", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N",
            0x2E: "M",
            // 数字键
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6",
            0x17: "5", 0x18: "=", 0x19: "9", 0x1A: "7", 0x1B: "-",
            0x1C: "8", 0x1D: "0",
            // 功能键
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x69: "F13", 0x6B: "F14", 0x71: "F15", 0x6A: "F16",
            0x40: "F17", 0x4F: "F18", 0x50: "F19", 0x5A: "F20",
            // 特殊键
            0x24: "Return", 0x30: "Tab", 0x31: "Space", 0x33: "Delete",
            0x35: "Escape", 0x75: "Forward Delete",
            // 方向键
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            // 其他
            0x32: "`", 0x21: "[", 0x1E: "]", 0x27: "'", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".",
            0x47: "Clear", 0x4C: "Enter",
            // 小键盘
            0x52: "Num 0", 0x53: "Num 1", 0x54: "Num 2", 0x55: "Num 3",
            0x56: "Num 4", 0x57: "Num 5", 0x58: "Num 6", 0x59: "Num 7",
            0x5B: "Num 8", 0x5C: "Num 9", 0x41: "Num .", 0x43: "Num *",
            0x45: "Num +", 0x4B: "Num /", 0x4E: "Num -", 0x51: "Num =",
        ]
        return keyMap[keyCode] ?? "Key(\(keyCode))"
    }

    /// 获取键位数组（用于分别显示每个键）
    var keyParts: [String] {
        displayName.split(separator: "+").map { String($0) }
    }

    /// 检查是否与另一个快捷键冲突（相同的按键组合）
    func conflictsWith(_ other: Hotkey) -> Bool {
        if self.type == .fnKey && other.type == .fnKey {
            return true
        }
        if self.type == .keyWithModifiers && other.type == .keyWithModifiers {
            return self.keyCode == other.keyCode && self.modifierFlags == other.modifierFlags
        }
        return false
    }
}

// MARK: - HotKey 库转换扩展

extension Hotkey {
    /// 转换为 HotKey 库的 Key 枚举
    var hotKeyKey: Key? {
        switch type {
        case .fnKey:
            return .function
        case .keyWithModifiers:
            guard let keyCode = keyCode else { return nil }
            return Key(carbonKeyCode: UInt32(keyCode))
        }
    }

    /// 转换为 HotKey 库的修饰键
    var hotKeyModifiers: NSEvent.ModifierFlags {
        guard let flags = modifierFlags else { return [] }
        return NSEvent.ModifierFlags(rawValue: flags)
    }
}

/// 快捷键配置集合
struct HotkeyConfiguration: Codable, Equatable {
    var hotkeys: [Hotkey]

    static let defaultConfiguration = HotkeyConfiguration(hotkeys: [.fnKey])

    var hasFnKey: Bool {
        hotkeys.contains { $0.type == .fnKey }
    }

    var hasKeyWithModifiersHotkeys: Bool {
        hotkeys.contains { $0.type == .keyWithModifiers }
    }

    func canRemove(_ hotkey: Hotkey) -> Bool {
        hotkeys.count > 1
    }

    mutating func add(_ hotkey: Hotkey) -> Bool {
        // 检查是否已存在相同的快捷键
        let isDuplicate = hotkeys.contains { $0.conflictsWith(hotkey) }
        if isDuplicate {
            return false
        }
        hotkeys.append(hotkey)
        return true
    }

    mutating func remove(_ hotkey: Hotkey) -> Bool {
        guard canRemove(hotkey) else { return false }
        hotkeys.removeAll { $0.id == hotkey.id }
        return true
    }

    /// 获取所有普通按键类型的快捷键
    func keyWithModifiersHotkeys() -> [Hotkey] {
        hotkeys.filter { $0.type == .keyWithModifiers }
    }
}
