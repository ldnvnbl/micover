import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        
        let mainWindow = NSApp.windows.first {
            if let identifier = $0.identifier?.rawValue,
                identifier.contains("main-window")
            {
                return true
            }
            return false
        }

        print("mainWindow is nil?: \(mainWindow == nil)")

        if let window = mainWindow {
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            print("Main window not found - need to create new one")
            NotificationCenter.default.post(
                name: .reopenMainWindow,
                object: nil
            )
        }

        return true
    }
}

extension Notification.Name {
    static let reopenMainWindow = Notification.Name("reopenMainWindow")
}
