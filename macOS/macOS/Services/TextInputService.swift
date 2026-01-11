import Foundation
import AppKit
import ApplicationServices

@Observable
final class TextInputService {
    
    // 检查是否有辅助功能权限
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    // 通过粘贴板方式输入文字
    func pasteText(_ text: String) {
        print("🔵 pasteText called with text: '\(text)'")
        
        // 先检查权限
        let hasPermission = AXIsProcessTrusted()
        print("🔐 AXIsProcessTrusted result: \(hasPermission)")
        
        guard hasPermission else {
            print("❌ No accessibility permission for text input")
            print("💡 Tip: Go to System Preferences > Security & Privacy > Privacy > Accessibility")
            return
        }
        
        print("✅ Accessibility permission verified")
        
        // 小延迟确保目标应用获得焦点
        Thread.sleep(forTimeInterval: 0.1)
        print("⏱️ Added 100ms delay for focus")
        
        print("📋 Preparing to paste text: \(text)")
        
        // 保存当前粘贴板内容
        let pasteboard = NSPasteboard.general
        let savedContent = pasteboard.string(forType: .string)
        print("💾 Saved original clipboard content: \(savedContent ?? "nil")")
        
        // 设置新内容到粘贴板
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("📝 Set clipboard content success: \(success)")
        
        // 验证粘贴板内容
        let verifyContent = pasteboard.string(forType: .string)
        print("✔️ Verified clipboard content: \(verifyContent ?? "nil")")
        
        // 使用 CGEvent 模拟 Cmd+V 粘贴
        if let source = CGEventSource(stateID: .hidSystemState) {
            print("🎯 CGEventSource created successfully")
            // Virtual key codes
            let cmdKeyCode: CGKeyCode = 0x37  // Command key
            let vKeyCode: CGKeyCode = 0x09    // V key
            
            // 创建按键事件
            guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true),
                  let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false),
                  let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false) else {
                print("❌ Failed to create CGEvents")
                return
            }
            
            print("🔧 Created all key events successfully")
            
            // 设置 Command 标志 - 注意只在 v 键事件上设置，不在 cmd 事件上设置
            vDown.flags = .maskCommand
            vUp.flags = .maskCommand
            
            print("🏁 Sending key events...")
            
            // 发送按键事件
            cmdDown.post(tap: .cghidEventTap)
//            print("  ↓ Cmd key down posted")
            vDown.post(tap: .cghidEventTap)
//            print("  ↓ V key down posted")
            Thread.sleep(forTimeInterval: 0.01)
            
            vUp.post(tap: .cghidEventTap)
//            print("  ↑ V key up posted")
            cmdUp.post(tap: .cghidEventTap)
//            print("  ↑ Cmd key up posted")
            
            print("cmd+v click key events sent successfully")
            
            // 延迟恢复原始粘贴板内容
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let saved = savedContent {
                    pasteboard.clearContents()
                    pasteboard.setString(saved, forType: .string)
                    print("Restored original clipboard content")
                }
            }
        } else {
            print("❌ Failed to create CGEventSource")
        }
    }
    
    // 发送回车键
    func sendEnterKey() {
        guard hasAccessibilityPermission else {
            print("❌ No accessibility permission for sending Enter key")
            return
        }
        
        print("⏎ Sending Enter key...")
        
        // 创建事件源
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return
        }
        
        // Virtual key code for Enter/Return
        let enterKeyCode: CGKeyCode = 0x24
        
        // 创建按键事件
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: enterKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: enterKeyCode, keyDown: false) else {
            print("❌ Failed to create key events")
            return
        }
        
        // 发送按键事件
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)  // 按键之间的小延迟
        keyUp.post(tap: .cghidEventTap)
        
        print("✅ Enter key sent successfully")
    }
    
    // 粘贴文字并发送回车（可选）
    func pasteTextAndSend(_ text: String, sendEnter: Bool = false) {
        if !text.isEmpty {
            pasteText(text)
        }
        
        if sendEnter {
            // 等待粘贴完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.sendEnterKey()
            }
        }
    }    
}
