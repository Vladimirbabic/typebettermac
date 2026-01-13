import Foundation
import OSLog

final class OpenAIService: AIService, Sendable {
    let provider: AIProvider = .openai

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String {
        guard let apiKey = KeychainService.shared.getAPIKey(for: .openai) else {
            Logger.ai.error("OpenAI: No API key configured")
            throw AIServiceError.noAPIKey
        }

        let model = SettingsManager.shared.selectedModel
        Logger.ai.debug("OpenAI: Using model \(model)")

        let requestBody = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: prompt.instruction),
                OpenAIMessage(role: "user", content: text)
            ],
            maxTokens: APIConstants.OpenAI.maxTokens,
            temperature: APIConstants.OpenAI.temperature
        )

        var request = URLRequest(url: APIConstants.OpenAI.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            Logger.ai.debug("OpenAI: Response status \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
                guard let content = openAIResponse.choices.first?.message.content else {
                    throw AIServiceError.invalidResponse
                }
                return content.trimmingCharacters(in: .whitespacesAndNewlines)

            case 401:
                throw AIServiceError.apiError("Invalid API key")

            case 429:
                throw AIServiceError.rateLimited

            case 500...599:
                throw AIServiceError.serverError(httpResponse.statusCode)

            default:
                if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                    throw AIServiceError.apiError(errorResponse.error.message)
                }
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            Logger.ai.error("OpenAI: Decoding error - \(error.localizedDescription)")
            throw AIServiceError.decodingError(error)
        } catch {
            Logger.ai.error("OpenAI: Network error - \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
}
