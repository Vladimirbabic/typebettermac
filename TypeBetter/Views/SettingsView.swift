import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 4) {
                SettingsTabButton(title: "General", icon: "gear", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                SettingsTabButton(title: "API Keys", icon: "key", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                SettingsTabButton(title: "Buttons", icon: "sparkles", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case 0:
                    GeneralSettingsView(settings: settings)
                case 1:
                    APIKeysSettingsView()
                case 2:
                    QuickActionsSettingsView(settings: settings)
                default:
                    GeneralSettingsView(settings: settings)
                }
            }
        }
        .frame(width: 520, height: 420)
    }
}

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? brandPurple.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? brandPurple : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @StateObject private var launchAtLogin = LaunchAtLoginService.shared
    @State private var hasAccessibility = false

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Permissions Status Section
                PermissionsStatusView(
                    hasAccessibility: $hasAccessibility,
                    hasAPIKey: hasAPIKey(for: settings.selectedProvider),
                    selectedProvider: settings.selectedProvider
                )

                Divider()

                // AI Provider Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("AI Provider", systemImage: "cpu")
                        .font(.headline)

                    // Custom provider selector
                    VStack(spacing: 6) {
                        ForEach(AIProvider.allCases) { provider in
                            ProviderSelectionRow(
                                provider: provider,
                                isSelected: settings.selectedProvider == provider,
                                hasAPIKey: hasAPIKey(for: provider),
                                onSelect: {
                                    selectProvider(provider)
                                }
                            )
                        }
                    }

                    TextField("Model", text: $settings.selectedModel)
                        .textFieldStyle(.roundedBorder)

                    if !modelHint.isEmpty {
                        Text(modelHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Hotkey Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Keyboard Shortcut", systemImage: "keyboard")
                        .font(.headline)

                    HStack {
                        Text("Global Hotkey")
                        Spacer()
                        HotkeyRecorderView(
                            keyCode: $settings.hotkeyKeyCode,
                            modifiers: $settings.hotkeyModifiers
                        )
                    }

                    Text("Press this shortcut with text selected to open the rephrase popup.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Launch at Login Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Startup", systemImage: "power")
                        .font(.headline)

                    Toggle("Launch TypeBetter at login", isOn: $launchAtLogin.isEnabled)

                    Text("Automatically start TypeBetter when you log in to your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }

    private var modelHint: String {
        switch settings.selectedProvider {
        case .claude:
            return "Recommended: claude-sonnet-4-20250514"
        case .openai:
            return "Recommended: gpt-4o or gpt-4o-mini"
        case .gemini:
            return "Recommended: gemini-2.0-flash or gemini-1.5-pro"
        }
    }

    private func hasAPIKey(for provider: AIProvider) -> Bool {
        let key = KeychainService.shared.getAPIKey(for: provider) ?? ""
        return !key.isEmpty
    }

    private func selectProvider(_ provider: AIProvider) {
        guard hasAPIKey(for: provider) else { return }
        settings.selectedProvider = provider
        settings.selectedModel = provider.defaultModel
    }
}

// MARK: - Permissions Status

struct PermissionsStatusView: View {
    @Binding var hasAccessibility: Bool
    let hasAPIKey: Bool
    let selectedProvider: AIProvider

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: "checkmark.shield")
                .font(.headline)

            VStack(spacing: 8) {
                // Accessibility Permission
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required to read selected text",
                    isGranted: hasAccessibility,
                    action: hasAccessibility ? nil : openAccessibilitySettings
                )

                // API Key Status
                PermissionRow(
                    icon: "key.fill",
                    title: "\(selectedProvider.displayName) API Key",
                    description: "Required for AI features",
                    isGranted: hasAPIKey,
                    action: nil
                )
            }
        }
    }

    private func openAccessibilitySettings() {
        NSWorkspace.shared.open(SystemURLs.accessibilitySettings)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: (() -> Void)?

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 24)

            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                if let action = action {
                    Button(action: action) {
                        Text("Grant")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(brandPurple)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Missing")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(10)
        .background(isGranted ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Provider Selection Row

struct ProviderSelectionRow: View {
    let provider: AIProvider
    let isSelected: Bool
    let hasAPIKey: Bool
    let onSelect: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    private var isEnabled: Bool {
        hasAPIKey
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? brandPurple : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(brandPurple)
                            .frame(width: 10, height: 10)
                    }
                }

                // Provider icon
                Image(systemName: provider.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isEnabled ? (isSelected ? brandPurple : .primary) : .secondary)
                    .frame(width: 20)

                // Provider name
                Text(provider.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isEnabled ? .primary : .secondary)

                Spacer()

                // Status indicator
                if provider.requiresAPIKey {
                    if hasAPIKey {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Ready")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("No API Key")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? brandPurple.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? brandPurple.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

// MARK: - API Keys Settings

struct APIKeysSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var apiKeys: [AIProvider: String] = [:]
    @State private var savedStates: [AIProvider: Bool] = [:]

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    private var cloudProviders: [AIProvider] {
        AIProvider.allCases.filter { $0.requiresAPIKey }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Active provider indicator
                activeProviderBanner

                // API Key entries for each cloud provider
                ForEach(cloudProviders) { provider in
                    APIKeyRowView(
                        provider: provider,
                        apiKey: binding(for: provider),
                        isSaved: savedStates[provider] ?? false,
                        isActive: settings.selectedProvider == provider,
                        hasKey: hasKey(for: provider),
                        onSave: { saveKey(for: provider) }
                    )

                    if provider != cloudProviders.last {
                        Divider()
                    }
                }

                Divider()

                // Info footer
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.secondary)
                    Text("API keys are stored securely in your macOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .onAppear {
            loadKeys()
        }
    }

    private var activeProviderBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.selectedProvider.iconName)
                .font(.system(size: 14))
                .foregroundColor(brandPurple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Provider")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(settings.selectedProvider.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            if settings.selectedProvider.requiresAPIKey {
                if hasKey(for: settings.selectedProvider) {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Key Required", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                Label("No Key Needed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(brandPurple.opacity(0.08))
        .cornerRadius(8)
    }

    private func binding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { apiKeys[provider] ?? "" },
            set: { apiKeys[provider] = $0 }
        )
    }

    private func hasKey(for provider: AIProvider) -> Bool {
        let key = apiKeys[provider] ?? ""
        return !key.isEmpty
    }

    private func loadKeys() {
        for provider in cloudProviders {
            apiKeys[provider] = KeychainService.shared.getAPIKey(for: provider) ?? ""
        }
    }

    private func saveKey(for provider: AIProvider) {
        guard let key = apiKeys[provider], !key.isEmpty else { return }

        if KeychainService.shared.saveAPIKey(for: provider, key: key) {
            savedStates[provider] = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                savedStates[provider] = false
            }
        }
    }
}

struct APIKeyRowView: View {
    let provider: AIProvider
    @Binding var apiKey: String
    let isSaved: Bool
    let isActive: Bool
    let hasKey: Bool
    let onSave: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with provider name and status
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? brandPurple : .secondary)
                    .frame(width: 20)

                Text(provider.displayName)
                    .font(.system(size: 14, weight: .semibold))

                if isActive {
                    Text("Active")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(brandPurple.opacity(0.15))
                        .foregroundColor(brandPurple)
                        .cornerRadius(4)
                }

                Spacer()

                // Status indicator
                statusIndicator
            }

            // API Key input
            SecureField("Enter API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            // Actions row
            HStack {
                Button("Save Key") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .tint(brandPurple)
                .controlSize(.small)
                .disabled(apiKey.isEmpty)

                if isSaved {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }

                Spacer()

                Link(destination: provider.apiKeyURL) {
                    Label("Get API Key", systemImage: "arrow.up.right")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if hasKey {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Not configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Quick Actions Settings

struct QuickActionsSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var showingEditor = false
    @State private var editingAction: QuickAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Action Buttons")
                        .font(.headline)
                    Text("These buttons appear in the rephrase popup.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    editingAction = nil
                    showingEditor = true
                }) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(16)

            Divider()

            // List
            List {
                ForEach(settings.quickActions) { action in
                    HStack(spacing: 12) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14))
                            .foregroundColor(action.hasColor ? action.buttonColor.color : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(action.prompt)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if action.hasColor {
                            Circle()
                                .fill(action.buttonColor.color)
                                .frame(width: 10, height: 10)
                        }

                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            editingAction = action
                            showingEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            settings.deleteQuickAction(action)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    settings.quickActions.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer
            HStack {
                Button("Reset to Defaults") {
                    settings.resetQuickActionsToDefaults()
                }
                .font(.caption)

                Spacer()

                Text("Drag to reorder • Right-click for options")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .sheet(isPresented: $showingEditor) {
            QuickActionEditorView(
                action: editingAction,
                onSave: { action in
                    if editingAction != nil {
                        settings.updateQuickAction(action)
                    } else {
                        settings.addQuickAction(action)
                    }
                    showingEditor = false
                    editingAction = nil
                },
                onCancel: {
                    showingEditor = false
                    editingAction = nil
                }
            )
        }
    }
}

// MARK: - Quick Action Editor

struct QuickActionEditorView: View {
    let action: QuickAction?
    let onSave: (QuickAction) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "sparkles"
    @State private var prompt: String = ""
    @State private var selectedColor: ButtonColor = .none

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text(action == nil ? "New Button" : "Edit Button")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Button Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g., Rephrase, Fix Grammar", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(QuickAction.availableIcons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                        .background(icon == iconName ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                        .foregroundColor(icon == iconName ? .accentColor : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            ForEach(ButtonColor.allColors) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color.name == "Default" ? Color.secondary.opacity(0.3) : color.color)
                                            .frame(width: 32, height: 32)

                                        if selectedColor.name == color.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(color.name == "Default" ? .primary : .white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(color.name)
                            }
                        }
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Instructions")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextEditor(text: $prompt)
                            .font(.system(size: 13))
                            .frame(height: 80)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)

                        Text("Tell the AI what to do with the selected text.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                            Text(name.isEmpty ? "Button" : name)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedColor.name != "Default" ? selectedColor.color.opacity(0.15) : Color.secondary.opacity(0.1))
                        .foregroundColor(selectedColor.name != "Default" ? selectedColor.color : .primary)
                        .cornerRadius(6)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 520)
        .onAppear {
            if let action = action {
                name = action.name
                icon = action.icon
                prompt = action.prompt
                selectedColor = action.buttonColor
            }
        }
    }

    private func save() {
        let newAction = QuickAction(
            id: action?.id ?? UUID(),
            name: name,
            icon: icon,
            prompt: prompt,
            buttonColor: selectedColor
        )
        onSave(newAction)
    }
}

#Preview {
    SettingsView()
}
