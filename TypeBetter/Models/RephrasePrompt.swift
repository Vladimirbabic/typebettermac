import Foundation

struct RephrasePrompt: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var instruction: String
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, instruction: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.isDefault = isDefault
    }

    static let defaultPrompts: [RephrasePrompt] = [
        RephrasePrompt(
            name: "Improve",
            instruction: "Improve this text to be clearer and more professional while keeping the same meaning. Only return the improved text, nothing else.",
            isDefault: true
        ),
        RephrasePrompt(
            name: "Formal",
            instruction: "Rewrite this text in a formal, professional tone. Only return the rewritten text, nothing else."
        ),
        RephrasePrompt(
            name: "Casual",
            instruction: "Rewrite this text in a casual, friendly tone. Only return the rewritten text, nothing else."
        ),
        RephrasePrompt(
            name: "Shorter",
            instruction: "Make this text more concise while keeping the key points. Only return the shortened text, nothing else."
        ),
        RephrasePrompt(
            name: "Fix Grammar",
            instruction: "Fix any grammar, spelling, or punctuation errors in this text. Only return the corrected text, nothing else."
        )
    ]
}
