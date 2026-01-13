import Foundation
import SwiftUI
import Carbon

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let selectedModel = "selectedModel"
        static let prompts = "prompts"
        static let selectedPromptIndex = "selectedPromptIndex"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    @Published var selectedProvider: AIProvider {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        }
    }

    @Published var selectedModel: String {
        didSet {
            defaults.set(selectedModel, forKey: Keys.selectedModel)
        }
    }

    @Published var prompts: [RephrasePrompt] {
        didSet {
            savePrompts()
        }
    }

    @Published var selectedPromptIndex: Int {
        didSet {
            defaults.set(selectedPromptIndex, forKey: Keys.selectedPromptIndex)
        }
    }

    @Published var ollamaEndpoint: String {
        didSet {
            defaults.set(ollamaEndpoint, forKey: Keys.ollamaEndpoint)
        }
    }

    @Published var hotkeyKeyCode: UInt32 {
        didSet {
            defaults.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    @Published var hotkeyModifiers: UInt32 {
        didSet {
            defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    var currentPrompt: RephrasePrompt {
        guard selectedPromptIndex >= 0 && selectedPromptIndex < prompts.count else {
            return prompts.first ?? RephrasePrompt.defaultPrompts[0]
        }
        return prompts[selectedPromptIndex]
    }

    private init() {
        // Load provider first (use local variable to avoid self reference issue)
        let provider: AIProvider
        if let providerRaw = defaults.string(forKey: Keys.selectedProvider),
           let savedProvider = AIProvider(rawValue: providerRaw) {
            provider = savedProvider
        } else {
            provider = .claude
        }
        self.selectedProvider = provider

        // Load model (use local provider variable)
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? provider.defaultModel

        // Load prompts
        if let data = defaults.data(forKey: Keys.prompts),
           let decoded = try? JSONDecoder().decode([RephrasePrompt].self, from: data) {
            self.prompts = decoded
        } else {
            self.prompts = RephrasePrompt.defaultPrompts
        }

        // Load selected prompt index
        self.selectedPromptIndex = defaults.integer(forKey: Keys.selectedPromptIndex)

        // Load Ollama endpoint
        self.ollamaEndpoint = defaults.string(forKey: Keys.ollamaEndpoint) ?? "http://localhost:11434"

        // Load hotkey (default: F16)
        let savedKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? UInt32
        let savedModifiers = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt32
        self.hotkeyKeyCode = savedKeyCode ?? 0x6A // F16 key
        self.hotkeyModifiers = savedModifiers ?? 0 // No modifiers needed for F16
    }

    private func savePrompts() {
        if let encoded = try? JSONEncoder().encode(prompts) {
            defaults.set(encoded, forKey: Keys.prompts)
        }
    }

    func addPrompt(_ prompt: RephrasePrompt) {
        prompts.append(prompt)
    }

    func updatePrompt(_ prompt: RephrasePrompt) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: RephrasePrompt) {
        prompts.removeAll { $0.id == prompt.id }
        if selectedPromptIndex >= prompts.count {
            selectedPromptIndex = max(0, prompts.count - 1)
        }
    }

    func resetToDefaults() {
        prompts = RephrasePrompt.defaultPrompts
        selectedPromptIndex = 0
    }
}
