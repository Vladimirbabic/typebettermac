import Foundation

enum TranslateLanguage: String, CaseIterable, Identifiable {
    case none = "none"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case japanese = "ja"
    case chinese = "zh"
    case korean = "ko"
    case arabic = "ar"
    case ukrainian = "uk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Select..."
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .ukrainian: return "Ukrainian"
        }
    }

    var translationPrompt: String {
        "Translate this text to \(displayName). Only return the translated text."
    }
}
