import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var claudeAPIKey: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var showingPromptEditor = false
    @State private var editingPrompt: RephrasePrompt?
    @State private var ollamaModels: [String] = []
    @State private var isCheckingOllama = false

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            APIKeysView(
                settings: settings,
                claudeAPIKey: $claudeAPIKey,
                openAIAPIKey: $openAIAPIKey
            )
            .tabItem {
                Label("API Keys", systemImage: "key")
            }

            PromptsView(
                settings: settings,
                showingPromptEditor: $showingPromptEditor,
                editingPrompt: $editingPrompt
            )
            .tabItem {
                Label("Prompts", systemImage: "text.quote")
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadAPIKeys()
        }
        .sheet(isPresented: $showingPromptEditor) {
            PromptEditorView(
                prompt: editingPrompt,
                onSave: { prompt in
                    if editingPrompt != nil {
                        settings.updatePrompt(prompt)
                    } else {
                        settings.addPrompt(prompt)
                    }
                    showingPromptEditor = false
                    editingPrompt = nil
                },
                onCancel: {
                    showingPromptEditor = false
                    editingPrompt = nil
                }
            )
        }
    }

    private func loadAPIKeys() {
        claudeAPIKey = KeychainService.shared.getAPIKey(for: .claude) ?? ""
        openAIAPIKey = KeychainService.shared.getAPIKey(for: .openai) ?? ""
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var ollamaStatus: String = "Unknown"
    @State private var ollamaModels: [String] = []

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $settings.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChangeCompat(of: settings.selectedProvider) { newProvider in
                    settings.selectedModel = newProvider.defaultModel
                    if newProvider == .ollama {
                        checkOllamaStatus()
                    }
                }

                if settings.selectedProvider == .ollama {
                    TextField("Ollama Endpoint", text: $settings.ollamaEndpoint)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Status: \(ollamaStatus)")
                            .foregroundColor(ollamaStatus == "Connected" ? .green : .secondary)
                        Spacer()
                        Button("Check") {
                            checkOllamaStatus()
                        }
                    }

                    if !ollamaModels.isEmpty {
                        Picker("Model", selection: $settings.selectedModel) {
                            ForEach(ollamaModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    } else {
                        TextField("Model", text: $settings.selectedModel)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    TextField("Model", text: $settings.selectedModel)
                        .textFieldStyle(.roundedBorder)

                    Text(modelHint)
                        .font(.caption)
                            .foregroundColor(.secondary)
                }
            } header: {
                Text("AI Configuration")
            }

            Section {
                HStack {
                    Text("Global Hotkey")
                    Spacer()
                    HotkeyRecorderView(
                        keyCode: $settings.hotkeyKeyCode,
                        modifiers: $settings.hotkeyModifiers
                    )
                }

                Text("Press this shortcut with text selected to rephrase it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Keyboard Shortcut")
            }
        }
        .padding()
        .onAppear {
            if settings.selectedProvider == .ollama {
                checkOllamaStatus()
            }
        }
    }

    private var modelHint: String {
        switch settings.selectedProvider {
        case .claude:
            return "Recommended: claude-sonnet-4-20250514 or claude-3-5-haiku-20241022"
        case .openai:
            return "Recommended: gpt-4o or gpt-4o-mini"
        case .ollama:
            return ""
        }
    }

    private func checkOllamaStatus() {
        ollamaStatus = "Checking..."
        Task {
            let service = OllamaService()
            let connected = await service.checkConnection()
            await MainActor.run {
                if connected {
                    ollamaStatus = "Connected"
                    Task {
                        let models = await service.getAvailableModels()
                        await MainActor.run {
                            ollamaModels = models
                        }
                    }
                } else {
                    ollamaStatus = "Not connected"
                    ollamaModels = []
                }
            }
        }
    }
}

struct APIKeysView: View {
    @ObservedObject var settings: SettingsManager
    @Binding var claudeAPIKey: String
    @Binding var openAIAPIKey: String

    @State private var claudeSaved = false
    @State private var openAISaved = false

    var body: some View {
        Form {
            Section {
                SecureField("Claude API Key", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        if KeychainService.shared.saveAPIKey(for: .claude, key: claudeAPIKey) {
                            claudeSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                claudeSaved = false
                            }
                        }
                    }
                    .disabled(claudeAPIKey.isEmpty)

                    if claudeSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved!")
                            .foregroundColor(.green)
                    }
                }

                Link("Get API key from Anthropic Console",
                     destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            } header: {
                Text("Claude (Anthropic)")
            }

            Section {
                SecureField("OpenAI API Key", text: $openAIAPIKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        if KeychainService.shared.saveAPIKey(for: .openai, key: openAIAPIKey) {
                            openAISaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                openAISaved = false
                            }
                        }
                    }
                    .disabled(openAIAPIKey.isEmpty)

                    if openAISaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved!")
                            .foregroundColor(.green)
                    }
                }

                Link("Get API key from OpenAI",
                     destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            } header: {
                Text("OpenAI")
            }

            Section {
                Text("API keys are stored securely in your macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct PromptsView: View {
    @ObservedObject var settings: SettingsManager
    @Binding var showingPromptEditor: Bool
    @Binding var editingPrompt: RephrasePrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Custom Prompts")
                    .font(.headline)
                Spacer()
                Button(action: {
                    editingPrompt = nil
                    showingPromptEditor = true
                }) {
                    Image(systemName: "plus")
                }
            }

            List {
                ForEach(settings.prompts) { prompt in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(prompt.name)
                                .font(.body)
                            Text(prompt.instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if settings.selectedPromptIndex == settings.prompts.firstIndex(of: prompt) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let index = settings.prompts.firstIndex(of: prompt) {
                            settings.selectedPromptIndex = index
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingPrompt = prompt
                            showingPromptEditor = true
                        }

                        Button("Delete", role: .destructive) {
                            settings.deletePrompt(prompt)
                        }
                    }
                }
            }
            .listStyle(.bordered)

            HStack {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }

                Spacer()

                Text("Right-click to edit or delete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
