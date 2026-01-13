import SwiftUI
import AppKit
import ApplicationServices
import OSLog

@main
struct RewordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    private let textCaptureService = TextCaptureService()
    private let hotkeyService = HotkeyService()
    private let aiService = AIServiceManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()
        checkAccessibilityPermissions()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            Logger.app.error("Failed to create status bar button")
            return
        }

        button.image = NSImage(named: "MenuBarIcon")
        statusItem?.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        let rephraseItem = NSMenuItem(
            title: "Rephrase Selected Text",
            action: #selector(rephraseSelectedText),
            keyEquivalent: "r"
        )
        rephraseItem.keyEquivalentModifierMask = [.command, .shift]
        rephraseItem.target = self
        menu.addItem(rephraseItem)

        menu.addItem(.separator())

        let promptsItem = NSMenuItem(title: "Prompts", action: nil, keyEquivalent: "")
        promptsItem.submenu = createPromptsSubmenu()
        menu.addItem(promptsItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Reword",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func createPromptsSubmenu() -> NSMenu {
        let menu = NSMenu()
        let prompts = SettingsManager.shared.prompts

        if prompts.isEmpty {
            let noPromptsItem = NSMenuItem(title: "No custom prompts", action: nil, keyEquivalent: "")
            noPromptsItem.isEnabled = false
            menu.addItem(noPromptsItem)
        } else {
            for (index, prompt) in prompts.enumerated() {
                let item = NSMenuItem(
                    title: prompt.name,
                    action: #selector(selectPrompt(_:)),
                    keyEquivalent: index < 9 ? "\(index + 1)" : ""
                )
                item.tag = index
                item.target = self
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let addPromptItem = NSMenuItem(
            title: "Add New Prompt...",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        addPromptItem.target = self
        menu.addItem(addPromptItem)

        return menu
    }

    @objc private func selectPrompt(_ sender: NSMenuItem) {
        let index = sender.tag
        let prompts = SettingsManager.shared.prompts
        guard index < prompts.count else { return }

        SettingsManager.shared.selectedPromptIndex = index
        rephraseSelectedText()
    }

    private func setupHotkey() {
        hotkeyService.registerHotkey { [weak self] in
            self?.textCaptureService.captureFrontmostApp()
            self?.rephraseSelectedText()
        }
        Logger.app.info("Hotkey service started")
    }

    private func checkAccessibilityPermissions() {
        let hasPermission = AXIsProcessTrusted()
        Logger.app.info("Accessibility permission: \(hasPermission)")

        guard !hasPermission else { return }

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Reword needs Accessibility permission to read selected text and simulate copy/paste.

            1. Click 'Open Settings'
            2. Click the '+' button
            3. Add Reword app
            4. Toggle it ON
            5. Restart Reword
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(SystemURLs.accessibilitySettings)
        }
    }

    @objc private func rephraseSelectedText() {
        guard AXIsProcessTrusted() else {
            showAlert(
                title: "Accessibility Required",
                message: "Please enable Accessibility permission in System Settings → Privacy & Security → Accessibility"
            )
            return
        }

        let selectionBounds = textCaptureService.getSelectionBounds()

        Task { @MainActor in
            guard let selectedText = await textCaptureService.getSelectedText(), !selectedText.isEmpty else {
                showAlert(
                    title: "No Text Selected",
                    message: "Select some text first, then press the hotkey.\n\nMake sure Reword has Accessibility permission."
                )
                return
            }

            FloatingInputController.shared.show(
                selectedText: selectedText,
                selectionBounds: selectionBounds
            ) { [weak self] instruction in
                self?.processRephrase(selectedText: selectedText, instruction: instruction)
            }
        }
    }

    private func processRephrase(selectedText: String, instruction: String) {
        Task { @MainActor in
            updateMenuBarIcon(loading: true)

            do {
                let prompt = RephrasePrompt(
                    name: "Custom",
                    instruction: "\(instruction). Only return the result, nothing else."
                )

                let rephrasedText = try await aiService.rephrase(text: selectedText, prompt: prompt)
                await textCaptureService.replaceSelectedText(with: rephrasedText)

                Logger.app.info("Text rephrased successfully")
            } catch {
                Logger.app.error("Rephrase failed: \(error.localizedDescription)")
                showAlert(title: "Rephrase Failed", message: error.localizedDescription)
            }

            updateMenuBarIcon(loading: false)
        }
    }

    private func updateMenuBarIcon(loading: Bool) {
        guard let button = statusItem?.button else { return }

        if loading {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Loading")
        } else {
            button.image = NSImage(named: "MenuBarIcon")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(
                    x: 0, y: 0,
                    width: UIConstants.SettingsWindow.width,
                    height: UIConstants.SettingsWindow.height
                ),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Reword Settings"
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
