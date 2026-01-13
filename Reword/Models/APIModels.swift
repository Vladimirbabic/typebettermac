import Foundation

// MARK: - Claude API Models

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Decodable {
    let content: [ClaudeContent]
}

struct ClaudeContent: Decodable {
    let type: String
    let text: String
}

struct ClaudeErrorResponse: Decodable {
    let error: ClaudeError
}

struct ClaudeError: Decodable {
    let type: String
    let message: String
}

// MARK: - OpenAI API Models

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

struct OpenAIError: Decodable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Ollama API Models

struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Encodable {
    let temperature: Double
}

struct OllamaResponse: Decodable {
    let response: String
    let done: Bool
}

struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

struct OllamaModel: Decodable {
    let name: String
    let modifiedAt: String?
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
}
