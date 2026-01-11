import Foundation

public enum AppConstants {
    public enum Environment {
        public enum Configuration {
            case development
            case production
        }
        
        #if DEBUG
        public static let current: Configuration = .production
        #else
        public static let current: Configuration = .production
        #endif
    }
    
    enum Audio {
        static let bufferSize: UInt32 = 4800
        static let targetSampleRate: Double = 16000
        static let packetsPerSecond = 10
    }
    
    enum Window {
        static let mainWindowID = "main-window"
        static let floatingWindowID = "floating-window"
        static let defaultWidth: CGFloat = 800
        static let defaultHeight: CGFloat = 600
        static let floatingWidth: CGFloat = 150
        static let floatingHeight: CGFloat = 120
    }
    
    enum Hotkey {
        static let defaultModifierFlags: UInt32 = 0
        static let fnKeyCode: UInt16 = 63  // Fn key code
    }
    
    public enum Storage {
        private static let developmentService = "app.micover.macos.debug"
        private static let productionService = "app.micover.macos"
        
        public static var keychainService: String {
            switch Environment.current {
            case .development:
                return developmentService
            case .production:
                return productionService
            }
        }
    }
}
