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

// MARK: - Gemini API Models

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?

    init(parts: [GeminiPart], role: String? = nil) {
        self.parts = parts
        self.role = role
    }
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Encodable {
    let maxOutputTokens: Int
    let temperature: Double
}

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContent
    let finishReason: String?
}

struct GeminiError: Decodable {
    let code: Int
    let message: String
    let status: String
}
