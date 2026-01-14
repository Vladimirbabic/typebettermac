import Foundation
import AppKit

// MARK: - App Constants
enum AppConstants {
    static let bundleIdentifier = "com.reword.app"
    static let keychainService = "com.reword.app"
}

// MARK: - UI Constants
enum UIConstants {
    enum FloatingPanel {
        static let width: CGFloat = 480
        static let height: CGFloat = 220
        static let cornerRadius: CGFloat = 14
        static let padding: CGFloat = 16
        static let inputFieldPaddingH: CGFloat = 16
        static let inputFieldPaddingV: CGFloat = 14
        static let inputCornerRadius: CGFloat = 10
        static let shadowRadius: CGFloat = 30
        static let shadowOpacity: CGFloat = 0.2
        static let shadowOffsetY: CGFloat = 15
        static let focusDelay: TimeInterval = 0.1
    }

    enum SettingsWindow {
        static let width: CGFloat = 520
        static let height: CGFloat = 420
    }

    enum PromptEditor {
        static let width: CGFloat = 450
        static let height: CGFloat = 350
        static let textEditorMinHeight: CGFloat = 100
    }

    enum HotkeyRecorder {
        static let width: CGFloat = 140
        static let height: CGFloat = 28
    }

    enum QuickActionChip {
        static let paddingH: CGFloat = 10
        static let paddingV: CGFloat = 5
        static let cornerRadius: CGFloat = 6
        static let iconSize: CGFloat = 10
        static let fontSize: CGFloat = 11
    }

    enum FontSizes {
        static let inputField: CGFloat = 16
        static let submitIcon: CGFloat = 22
        static let sparklesIcon: CGFloat = 20
        static let caption: CGFloat = 12
        static let small: CGFloat = 11
    }

    enum TextPreview {
        static let maxLength = 80
    }
}

// MARK: - Timing Constants
enum TimingConstants {
    static let clipboardRestoreDelay: TimeInterval = 2.0
    static let appActivationDelay: TimeInterval = 0.3
    static let pasteActivationDelay: TimeInterval = 0.2
    static let keyEventDelay: TimeInterval = 0.05
    static let saveConfirmationDuration: TimeInterval = 2.0
}

// MARK: - API Constants
enum APIConstants {
    enum Claude {
        static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
        static let apiVersion = "2023-06-01"
        static let maxTokens = 4096
    }

    enum OpenAI {
        static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
        static let maxTokens = 4096
        static let temperature = 0.7
    }

    enum Gemini {
        static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
        static let maxTokens = 4096
        static let temperature = 0.7
    }
}

// MARK: - Key Codes
enum KeyCodes {
    // Letter keys
    static let a: UInt32 = 0x00
    static let s: UInt32 = 0x01
    static let d: UInt32 = 0x02
    static let f: UInt32 = 0x03
    static let h: UInt32 = 0x04
    static let g: UInt32 = 0x05
    static let z: UInt32 = 0x06
    static let x: UInt32 = 0x07
    static let c: UInt32 = 0x08
    static let v: UInt32 = 0x09
    static let b: UInt32 = 0x0B
    static let q: UInt32 = 0x0C
    static let w: UInt32 = 0x0D
    static let e: UInt32 = 0x0E
    static let r: UInt32 = 0x0F
    static let y: UInt32 = 0x10
    static let t: UInt32 = 0x11

    // Function keys
    static let f1: UInt32 = 0x7A
    static let f2: UInt32 = 0x78
    static let f3: UInt32 = 0x63
    static let f4: UInt32 = 0x76
    static let f5: UInt32 = 0x60
    static let f6: UInt32 = 0x61
    static let f7: UInt32 = 0x62
    static let f8: UInt32 = 0x64
    static let f9: UInt32 = 0x65
    static let f10: UInt32 = 0x6D
    static let f11: UInt32 = 0x67
    static let f12: UInt32 = 0x6F
    static let f13: UInt32 = 0x69
    static let f14: UInt32 = 0x6B
    static let f15: UInt32 = 0x71
    static let f16: UInt32 = 0x6A
    static let f17: UInt32 = 0x40
    static let f18: UInt32 = 0x4F
    static let f19: UInt32 = 0x50
    static let f20: UInt32 = 0x5A

    // All function key codes as a set for quick lookup
    static let functionKeys: Set<UInt16> = [
        0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,
        0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A,
        0x40, 0x4F, 0x50, 0x5A
    ]

    // Modifier-only key codes (to ignore when recording hotkeys)
    static let modifierOnlyKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    // Key code to display string mapping
    static let displayStrings: [UInt32: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
        0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
        0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
        0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
        0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
        0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
        0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
        0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
        0x2F: ".", 0x32: "`", 0x24: "↩", 0x30: "⇥", 0x31: "Space",
        0x33: "⌫", 0x35: "⎋",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15", 0x6A: "F16",
        0x40: "F17", 0x4F: "F18", 0x50: "F19", 0x5A: "F20",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑"
    ]
}

// MARK: - Hotkey Signature
enum HotkeyConstants {
    // 'RWRD' as OSType
    static let signature: OSType = 0x5257_4452
    static let id: UInt32 = 1
}

// MARK: - System Settings URLs
enum SystemURLs {
    static let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let anthropicConsole = URL(string: "https://console.anthropic.com/")!
    static let openAIPlatform = URL(string: "https://platform.openai.com/api-keys")!
}
