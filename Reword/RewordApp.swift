import SwiftUI
import AppKit
import ApplicationServices
import OSLog

@main
struct TypeBetterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default scene - this is a menu bar app
        // Settings window is managed by AppDelegate
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var tooltipPopover: NSPopover?
    private var tooltipTimer: Timer?

    private let textCaptureService = TextCaptureService()
    private let hotkeyService = HotkeyService()
    private let aiService = AIServiceManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window restoration to prevent settings from auto-showing
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        setupMenuBar()
        setupHotkey()

        if !SettingsManager.shared.hasCompletedOnboarding {
            showOnboarding()
        }

        // Check for updates after a short delay (don't slow down launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UpdateService.shared.checkForUpdatesInBackground()
        }
    }

    // Prevent any automatic window showing on reopen
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't automatically open any windows - user should use menu or hotkey
        return false
    }

    // Prevent window state restoration
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
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

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TypeBetter",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    private func setupHotkey() {
        hotkeyService.registerHotkey { [weak self] in
            self?.textCaptureService.captureFrontmostApp()
            self?.rephraseSelectedText()
        }
        Logger.app.info("Hotkey service started")
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
                showMenuBarTooltip(message: "No text selected", isError: true)
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

                // Play success sound
                NSSound(named: "Pop")?.play()

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

    private func showMenuBarTooltip(message: String, isError: Bool = false) {
        // Cancel any existing tooltip
        tooltipTimer?.invalidate()
        tooltipPopover?.close()

        // Play error sound
        if isError {
            NSSound(named: "Basso")?.play()
        }

        // Create tooltip view
        let tooltipView = MenuBarTooltipView(message: message, isError: isError)
        let hostingController = NSHostingController(rootView: tooltipView)

        // Create popover
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true

        // Show from status bar button
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        self.tooltipPopover = popover

        // Auto-dismiss after 2 seconds
        tooltipTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.tooltipPopover?.close()
            self?.tooltipPopover = nil
        }
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            onboardingWindow?.titlebarAppearsTransparent = true
            onboardingWindow?.titleVisibility = .hidden
            onboardingWindow?.backgroundColor = .black
            onboardingWindow?.isReleasedWhenClosed = false
            onboardingWindow?.delegate = self

            let onboardingView = OnboardingView {
                self.closeOnboarding()
            }
            onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
            onboardingWindow?.center()
        }

        // Show app in Dock
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        hideFromDockIfNoWindows()
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
            settingsWindow?.title = "TypeBetter Settings"
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }

        // Show app in Dock
        NSApp.setActivationPolicy(.regular)
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

    private func hideFromDockIfNoWindows() {
        // Check if any managed windows are still open
        let hasVisibleWindows = (settingsWindow?.isVisible == true) || (onboardingWindow?.isVisible == true)
        if !hasVisibleWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Clear reference and hide from dock if needed
        if window === settingsWindow {
            settingsWindow = nil
        } else if window === onboardingWindow {
            onboardingWindow = nil
        }

        // Delay slightly to allow window to fully close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.hideFromDockIfNoWindows()
        }
    }
}

// MARK: - Menu Bar Tooltip View

struct MenuBarTooltipView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isError ? .red : .green)

            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
