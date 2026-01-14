import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.reword.app"

    /// General app logging
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Text capture and clipboard operations
    static let textCapture = Logger(subsystem: subsystem, category: "TextCapture")

    /// Hotkey registration and handling
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")

    /// AI service operations
    static let ai = Logger(subsystem: subsystem, category: "AI")

    /// Keychain operations
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")

    /// Settings and preferences
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// UI operations
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
