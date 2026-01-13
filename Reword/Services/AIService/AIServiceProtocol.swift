import Foundation
import OSLog

protocol AIService: Sendable {
    var provider: AIProvider { get }
    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String
}

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case apiError(String)
    case rateLimited
    case serverError(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the AI service."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please try again later."
        case .invalidURL:
            return "Invalid endpoint URL configured."
        }
    }
}

final class AIServiceManager: Sendable {
    private let claudeService = ClaudeService()
    private let openAIService = OpenAIService()
    private let ollamaService = OllamaService()

    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String {
        let provider = SettingsManager.shared.selectedProvider

        Logger.ai.info("Rephrasing with provider: \(provider.displayName)")

        let service: any AIService = switch provider {
        case .claude: claudeService
        case .openai: openAIService
        case .ollama: ollamaService
        }

        return try await service.rephrase(text: text, prompt: prompt)
    }
}
