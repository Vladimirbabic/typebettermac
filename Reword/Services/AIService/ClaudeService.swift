import Foundation
import OSLog

final class ClaudeService: AIService, Sendable {
    let provider: AIProvider = .claude

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String {
        guard let apiKey = KeychainService.shared.getAPIKey(for: .claude) else {
            Logger.ai.error("Claude: No API key configured")
            throw AIServiceError.noAPIKey
        }

        let model = SettingsManager.shared.selectedModel
        Logger.ai.debug("Claude: Using model \(model)")

        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: APIConstants.Claude.maxTokens,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: "\(prompt.instruction)\n\nText to rephrase:\n\(text)"
                )
            ]
        )

        var request = URLRequest(url: APIConstants.Claude.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(APIConstants.Claude.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try encoder.encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            Logger.ai.debug("Claude: Response status \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
                guard let text = claudeResponse.content.first?.text else {
                    throw AIServiceError.invalidResponse
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)

            case 401:
                throw AIServiceError.apiError("Invalid API key")

            case 429:
                throw AIServiceError.rateLimited

            case 500...599:
                throw AIServiceError.serverError(httpResponse.statusCode)

            default:
                if let errorResponse = try? decoder.decode(ClaudeErrorResponse.self, from: data) {
                    throw AIServiceError.apiError(errorResponse.error.message)
                }
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            Logger.ai.error("Claude: Decoding error - \(error.localizedDescription)")
            throw AIServiceError.decodingError(error)
        } catch {
            Logger.ai.error("Claude: Network error - \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
}
