import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case claude = "claude"
    case openai = "openai"
    case gemini = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        }
    }

    var requiresAPIKey: Bool {
        return true
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        }
    }

    var keychainKey: String {
        return "com.reword.apikey.\(rawValue)"
    }

    var apiKeyURL: URL {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain"
        case .openai: return "sparkle"
        case .gemini: return "diamond"
        }
    }
}
