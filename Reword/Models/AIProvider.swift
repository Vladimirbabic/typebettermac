import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case claude = "claude"
    case openai = "openai"
    case ollama = "ollama"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .ollama: return "Ollama (Local)"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .claude, .openai: return true
        case .ollama: return false
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .openai: return "gpt-4o"
        case .ollama: return "llama3.2"
        }
    }

    var keychainKey: String {
        return "com.reword.apikey.\(rawValue)"
    }
}
