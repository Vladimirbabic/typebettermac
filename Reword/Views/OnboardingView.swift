import SwiftUI
import ApplicationServices
import Carbon

struct OnboardingView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var currentStep = 0
    @State private var apiKey: String = ""
    @State private var selectedProvider: AIProvider = .claude
    @State private var hasAccessibility = false
    @State private var recordedKeyCode: UInt32 = 0x27 // Default: Quote key
    @State private var recordedModifiers: UInt32 = UInt32(cmdKey) // Default: CMD

    let onComplete: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator - 4 steps now
            HStack(spacing: 8) {
                ForEach(0..<4) { step in
                    Capsule()
                        .fill(step <= currentStep ? brandPurple : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Content
            TabView(selection: $currentStep) {
                WelcomeStep(onContinue: { currentStep = 1 })
                    .tag(0)

                AccessibilityStep(
                    hasPermission: $hasAccessibility,
                    onContinue: { currentStep = 2 }
                )
                .tag(1)

                ShortcutStep(
                    keyCode: $recordedKeyCode,
                    modifiers: $recordedModifiers,
                    onContinue: { currentStep = 3 }
                )
                .tag(2)

                APIKeyStep(
                    apiKey: $apiKey,
                    selectedProvider: $selectedProvider,
                    onComplete: completeOnboarding
                )
                .tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 500, height: 480)
        .background(Color.black)
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
            // Load current hotkey settings
            recordedKeyCode = settings.hotkeyKeyCode
            recordedModifiers = settings.hotkeyModifiers
        }
    }

    private func completeOnboarding() {
        // Save API key
        if !apiKey.isEmpty {
            let provider: AIProvider = selectedProvider
            _ = KeychainService.shared.saveAPIKey(for: provider, key: apiKey)
            settings.selectedProvider = provider
        }

        // Save hotkey
        settings.hotkeyKeyCode = recordedKeyCode
        settings.hotkeyModifiers = recordedModifiers

        settings.hasCompletedOnboarding = true
        onComplete()
    }
}

struct WelcomeStep: View {
    let onContinue: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundColor(brandPurple)

            VStack(spacing: 12) {
                Text("Welcome to TypeBetter")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Instantly rephrase any text with AI.\nSelect text anywhere, press your hotkey, done.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(brandPurple)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
    }
}

struct AccessibilityStep: View {
    @Binding var hasPermission: Bool
    let onContinue: () -> Void

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPermission ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundColor(hasPermission ? .green : brandPurple)

            VStack(spacing: 12) {
                Text("Accessibility Permission")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("TypeBetter needs Accessibility access to read\nselected text and paste the result.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if hasPermission {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission granted")
                        .foregroundColor(.green)
                }
                .font(.system(size: 14, weight: .medium))
            } else {
                VStack(spacing: 12) {
                    Button(action: openAccessibilitySettings) {
                        Text("Open System Settings")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(brandPurple)
                    }
                    .buttonStyle(.plain)

                    Text("Enable TypeBetter in Privacy & Security → Accessibility")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasPermission ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasPermission ? brandPurple : Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!hasPermission)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasPermission = AXIsProcessTrusted()
        }
    }

    private func openAccessibilitySettings() {
        NSWorkspace.shared.open(SystemURLs.accessibilitySettings)
    }
}

struct ShortcutStep: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    let onContinue: () -> Void

    @State private var isRecording = false

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "command.square.fill")
                .font(.system(size: 56))
                .foregroundColor(brandPurple)

            VStack(spacing: 12) {
                Text("Set Your Shortcut")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Choose a keyboard shortcut to trigger rephrasing.\nSelect text anywhere, press your shortcut, done.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Shortcut recorder
            VStack(spacing: 16) {
                Button(action: { isRecording.toggle() }) {
                    HStack {
                        if isRecording {
                            Text("Press your shortcut...")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text(shortcutDisplayString)
                                .foregroundColor(.white)
                        }
                    }
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(minWidth: 200)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(isRecording ? brandPurple.opacity(0.3) : Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isRecording ? brandPurple : Color.white.opacity(0.2), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                Text("Click to record a new shortcut")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if isRecording {
                        let newModifiers = event.modifierFlags.carbonFlags
                        // Only accept shortcuts with at least one modifier (CMD, Option, Control, Shift)
                        if newModifiers != 0 {
                            keyCode = UInt32(event.keyCode)
                            modifiers = newModifiers
                            isRecording = false
                        }
                        return nil
                    }
                    return event
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(brandPurple)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
    }

    private var shortcutDisplayString: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }

        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)

        return parts.joined(separator: " ")
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K",
            0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N",
            0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "Space",
            0x32: "`", 0x33: "⌫", 0x35: "⎋",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x63: "F3",
            0x64: "F8", 0x65: "F9", 0x67: "F11", 0x69: "F13",
            0x6A: "F16", 0x6B: "F14", 0x6D: "F10", 0x6F: "F12",
            0x71: "F15", 0x76: "F4", 0x78: "F2", 0x7A: "F1",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑"
        ]
        return keyMap[keyCode] ?? "Key \(keyCode)"
    }
}

struct APIKeyStep: View {
    @Binding var apiKey: String
    @Binding var selectedProvider: AIProvider
    let onComplete: () -> Void

    @State private var isValidating = false
    @State private var validationError: String?

    private let brandPurple = Color(red: 155/255, green: 123/255, blue: 212/255)

    private var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 56))
                .foregroundColor(brandPurple)

            VStack(spacing: 12) {
                Text("Connect Your AI")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Enter your API key to start rephrasing.\nYour key is stored securely in Keychain.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 16) {
                // Provider picker
                Picker("Provider", selection: $selectedProvider) {
                    Text("Claude").tag(AIProvider.claude)
                    Text("OpenAI").tag(AIProvider.openai)
                    Text("Gemini").tag(AIProvider.gemini)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                // API key input
                SecureField("Paste your API key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)

                // Get API key link
                Button(action: openAPIKeyPage) {
                    Text("Get an API key from \(selectedProvider.displayName) →")
                        .font(.system(size: 13))
                        .foregroundColor(brandPurple)
                }
                .buttonStyle(.plain)

                if let error = validationError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onComplete) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Complete Setup")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasValidKey ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasValidKey ? brandPurple : Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isValidating || !hasValidKey)

                if !hasValidKey {
                    Text("Enter an API key to continue")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
    }

    private func openAPIKeyPage() {
        NSWorkspace.shared.open(selectedProvider.apiKeyURL)
    }
}

// Extension for Carbon modifier flags
extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
