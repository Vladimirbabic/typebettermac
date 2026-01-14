import Foundation
import SwiftUI

struct ButtonColor: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    static let none = ButtonColor(name: "Default", red: 128, green: 128, blue: 128)
    static let purple = ButtonColor(name: "Purple", red: 155, green: 123, blue: 212)
    static let blue = ButtonColor(name: "Blue", red: 59, green: 130, blue: 246)
    static let green = ButtonColor(name: "Green", red: 34, green: 197, blue: 94)
    static let orange = ButtonColor(name: "Orange", red: 249, green: 115, blue: 22)
    static let pink = ButtonColor(name: "Pink", red: 236, green: 72, blue: 153)
    static let red = ButtonColor(name: "Red", red: 239, green: 68, blue: 68)
    static let yellow = ButtonColor(name: "Yellow", red: 234, green: 179, blue: 8)
    static let teal = ButtonColor(name: "Teal", red: 20, green: 184, blue: 166)

    static let allColors: [ButtonColor] = [.none, .purple, .blue, .green, .orange, .pink, .red, .yellow, .teal]
}

struct QuickAction: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var prompt: String
    var buttonColor: ButtonColor

    // Legacy support
    var isPurple: Bool {
        buttonColor.name == "Purple"
    }

    var hasColor: Bool {
        buttonColor.name != "Default"
    }

    init(id: UUID = UUID(), name: String, icon: String = "sparkles", prompt: String, buttonColor: ButtonColor = .none) {
        self.id = id
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.buttonColor = buttonColor
    }

    // Legacy initializer for backwards compatibility
    init(id: UUID = UUID(), name: String, icon: String = "sparkles", prompt: String, isPurple: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.buttonColor = isPurple ? .purple : .none
    }

    static let defaultActions: [QuickAction] = [
        QuickAction(
            name: "Rephrase",
            icon: "sparkles",
            prompt: "Rephrase this text to be clearer and more professional",
            buttonColor: .purple
        ),
        QuickAction(
            name: "Fix Grammar",
            icon: "checkmark.circle",
            prompt: "Fix any grammar and spelling errors"
        ),
        QuickAction(
            name: "Shorter",
            icon: "arrow.down.left.and.arrow.up.right",
            prompt: "Make this more concise while keeping the meaning"
        ),
        QuickAction(
            name: "Formal",
            icon: "person.text.rectangle",
            prompt: "Rewrite in a formal professional tone"
        )
    ]

    static let availableIcons: [String] = [
        "sparkles",
        "checkmark.circle",
        "arrow.down.left.and.arrow.up.right",
        "person.text.rectangle",
        "wand.and.stars",
        "text.quote",
        "doc.text",
        "pencil",
        "lightbulb",
        "brain",
        "list.bullet",
        "arrow.up.right",
        "globe",
        "heart",
        "star",
        "bolt"
    ]
}
