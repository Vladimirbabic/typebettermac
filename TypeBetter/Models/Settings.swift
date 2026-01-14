import Foundation
import SwiftUI
import Carbon

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
    static let quickActionsDidSync = Notification.Name("quickActionsDidSync")
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let iCloud = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let selectedModel = "selectedModel"
        static let prompts = "prompts"
        static let selectedPromptIndex = "selectedPromptIndex"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let quickActions = "quickActions"
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

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    @Published var quickActions: [QuickAction] {
        didSet {
            saveQuickActions()
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

        // Load hotkey (default: CMD + ')
        let savedKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? UInt32
        let savedModifiers = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt32
        self.hotkeyKeyCode = savedKeyCode ?? 0x27 // Quote key (')
        self.hotkeyModifiers = savedModifiers ?? UInt32(cmdKey) // CMD modifier

        // Load onboarding state
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)

        // Load quick actions from iCloud first, fallback to UserDefaults
        // (inline to avoid calling method before init completes)
        if let data = iCloud.data(forKey: Keys.quickActions),
           let decoded = try? JSONDecoder().decode([QuickAction].self, from: data) {
            self.quickActions = decoded
            defaults.set(data, forKey: Keys.quickActions) // backup to UserDefaults
        } else if let data = defaults.data(forKey: Keys.quickActions),
                  let decoded = try? JSONDecoder().decode([QuickAction].self, from: data) {
            self.quickActions = decoded
            // Migrate to iCloud
            iCloud.set(data, forKey: Keys.quickActions)
            iCloud.synchronize()
        } else {
            self.quickActions = QuickAction.defaultActions
        }

        // Setup iCloud sync notifications (must be after all properties initialized)
        setupiCloudSync()
    }

    // MARK: - iCloud Sync

    private func setupiCloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidSync(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud
        )

        // Trigger initial sync
        iCloud.synchronize()
    }

    @objc private func iCloudDidSync(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Only reload if change came from another device or initial sync
        if reason == NSUbiquitousKeyValueStoreServerChange ||
           reason == NSUbiquitousKeyValueStoreInitialSyncChange {

            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
               changedKeys.contains(Keys.quickActions) {
                DispatchQueue.main.async { [weak self] in
                    self?.reloadQuickActionsFromiCloud()
                }
            }
        }
    }

    private func reloadQuickActionsFromiCloud() {
        if let data = iCloud.data(forKey: Keys.quickActions),
           let decoded = try? JSONDecoder().decode([QuickAction].self, from: data) {
            // Update without triggering didSet to avoid re-saving
            let oldValue = quickActions
            if decoded != oldValue {
                quickActions = decoded
                NotificationCenter.default.post(name: .quickActionsDidSync, object: nil)
            }
        }
    }

    private func savePrompts() {
        if let encoded = try? JSONEncoder().encode(prompts) {
            defaults.set(encoded, forKey: Keys.prompts)
        }
    }

    private func saveQuickActions() {
        if let encoded = try? JSONEncoder().encode(quickActions) {
            // Save to both UserDefaults (local backup) and iCloud
            defaults.set(encoded, forKey: Keys.quickActions)
            iCloud.set(encoded, forKey: Keys.quickActions)
            iCloud.synchronize()
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

    // MARK: - Quick Actions

    func addQuickAction(_ action: QuickAction) {
        quickActions.append(action)
    }

    func updateQuickAction(_ action: QuickAction) {
        if let index = quickActions.firstIndex(where: { $0.id == action.id }) {
            quickActions[index] = action
        }
    }

    func deleteQuickAction(_ action: QuickAction) {
        quickActions.removeAll { $0.id == action.id }
    }

    func resetQuickActionsToDefaults() {
        quickActions = QuickAction.defaultActions
    }
}
