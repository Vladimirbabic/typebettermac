import Foundation
import OSLog

final class OllamaService: AIService, Sendable {
    let provider: AIProvider = .ollama

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    func rephrase(text: String, prompt: RephrasePrompt) async throws -> String {
        let settings = SettingsManager.shared
        let endpoint = settings.ollamaEndpoint
        let model = settings.selectedModel

        guard let url = URL(string: "\(endpoint)/api/generate") else {
            Logger.ai.error("Ollama: Invalid endpoint URL - \(endpoint)")
            throw AIServiceError.invalidURL
        }

        Logger.ai.debug("Ollama: Using model \(model) at \(endpoint)")

        let fullPrompt = "\(prompt.instruction)\n\nText to rephrase:\n\(text)"

        let requestBody = OllamaRequest(
            model: model,
            prompt: fullPrompt,
            stream: false,
            options: OllamaOptions(temperature: APIConstants.Ollama.temperature)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        request.timeoutInterval = APIConstants.Ollama.timeoutInterval

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            Logger.ai.debug("Ollama: Response status \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
                return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)

            case 404:
                throw AIServiceError.apiError("Model '\(model)' not found. Make sure it's pulled in Ollama.")

            case 500...599:
                throw AIServiceError.serverError(httpResponse.statusCode)

            default:
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            Logger.ai.error("Ollama: Decoding error - \(error.localizedDescription)")
            throw AIServiceError.decodingError(error)
        } catch {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCannotConnectToHost {
                Logger.ai.error("Ollama: Cannot connect to host at \(endpoint)")
                throw AIServiceError.apiError("Cannot connect to Ollama. Make sure Ollama is running at \(endpoint)")
            }
            Logger.ai.error("Ollama: Network error - \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    func checkConnection() async -> Bool {
        let endpoint = SettingsManager.shared.ollamaEndpoint
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let connected = (response as? HTTPURLResponse)?.statusCode == 200
            Logger.ai.debug("Ollama: Connection check - \(connected ? "connected" : "not connected")")
            return connected
        } catch {
            Logger.ai.debug("Ollama: Connection check failed - \(error.localizedDescription)")
            return false
        }
    }

    func getAvailableModels() async -> [String] {
        let endpoint = SettingsManager.shared.ollamaEndpoint
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return []
            }

            let tagsResponse = try decoder.decode(OllamaTagsResponse.self, from: data)
            let modelNames = tagsResponse.models.map(\.name)
            Logger.ai.debug("Ollama: Found \(modelNames.count) models")
            return modelNames
        } catch {
            Logger.ai.debug("Ollama: Failed to fetch models - \(error.localizedDescription)")
            return []
        }
    }
}
