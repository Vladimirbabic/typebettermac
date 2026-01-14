import Foundation
import OSLog

final class GeminiService: AIService, Sendable {
    let provider: AIProvider = .gemini

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String {
        guard let apiKey = KeychainService.shared.getAPIKey(for: .gemini) else {
            Logger.ai.error("Gemini: No API key configured")
            throw AIServiceError.noAPIKey
        }

        let model = SettingsManager.shared.selectedModel
        Logger.ai.debug("Gemini: Using model \(model)")

        guard let url = URL(string: "\(APIConstants.Gemini.baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw AIServiceError.invalidURL
        }

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: "\(prompt.instruction)\n\nText to rephrase:\n\(text)")],
                    role: "user"
                )
            ],
            generationConfig: GeminiGenerationConfig(
                maxOutputTokens: APIConstants.Gemini.maxTokens,
                temperature: APIConstants.Gemini.temperature
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            Logger.ai.debug("Gemini: Response status \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

                if let error = geminiResponse.error {
                    throw AIServiceError.apiError(error.message)
                }

                guard let candidate = geminiResponse.candidates?.first,
                      let text = candidate.content.parts.first?.text else {
                    throw AIServiceError.invalidResponse
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)

            case 400:
                if let geminiResponse = try? decoder.decode(GeminiResponse.self, from: data),
                   let error = geminiResponse.error {
                    throw AIServiceError.apiError(error.message)
                }
                throw AIServiceError.apiError("Bad request")

            case 401, 403:
                throw AIServiceError.apiError("Invalid API key")

            case 429:
                throw AIServiceError.rateLimited

            case 500...599:
                throw AIServiceError.serverError(httpResponse.statusCode)

            default:
                if let geminiResponse = try? decoder.decode(GeminiResponse.self, from: data),
                   let error = geminiResponse.error {
                    throw AIServiceError.apiError(error.message)
                }
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            Logger.ai.error("Gemini: Decoding error - \(error.localizedDescription)")
            throw AIServiceError.decodingError(error)
        } catch {
            Logger.ai.error("Gemini: Network error - \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
}
