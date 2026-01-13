import Foundation
import AppKit
import ApplicationServices
import OSLog

final class TextCaptureService: @unchecked Sendable {

    private var previousApp: NSRunningApplication?
    private var lastActiveApp: NSRunningApplication?
    private var appObserver: NSObjectProtocol?
    private(set) var lastSelectionBounds: CGRect?

    init() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.lastActiveApp = app
                    Logger.textCapture.debug("Active app changed to: \(app.localizedName ?? "unknown")")
                }
            }
        }
    }

    deinit {
        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func captureFrontmostApp() {
        if let lastApp = lastActiveApp {
            previousApp = lastApp
            Logger.textCapture.debug("Using tracked app: \(lastApp.localizedName ?? "unknown")")
            return
        }

        let app = NSWorkspace.shared.frontmostApplication
        Logger.textCapture.debug("Current frontmost: \(app?.localizedName ?? "none")")

        if let app = app, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = app
            Logger.textCapture.debug("Captured app: \(app.localizedName ?? "unknown")")
        } else {
            Logger.textCapture.warning("Could not capture frontmost app")
        }
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    func getSelectedText() async -> String? {
        Logger.textCapture.info("Getting selected text...")

        guard AXIsProcessTrusted() else {
            Logger.textCapture.error("No accessibility permission")
            return nil
        }

        guard let targetApp = previousApp else {
            Logger.textCapture.error("No target app captured")
            return nil
        }

        Logger.textCapture.debug("Target app: \(targetApp.localizedName ?? "unknown") (pid: \(targetApp.processIdentifier))")

        let pasteboard = NSPasteboard.general
        let savedClipboard = pasteboard.string(forType: .string)

        pasteboard.clearContents()

        activateApp(targetApp)
        try? await Task.sleep(for: .milliseconds(300))

        sendKeyboardShortcut(keyCode: KeyCodes.c, command: true)
        try? await Task.sleep(for: .milliseconds(300))

        let copiedText = pasteboard.string(forType: .string)
        Logger.textCapture.debug("Clipboard after Cmd+C: \(copiedText?.prefix(50).description ?? "nil")")

        scheduleClipboardRestore(savedClipboard)

        if let text = copiedText, !text.isEmpty {
            Logger.textCapture.info("Got \(text.count) chars")
            return text
        } else {
            Logger.textCapture.warning("No text copied")
            return nil
        }
    }

    @MainActor
    func replaceSelectedText(with newText: String) async {
        guard let targetApp = previousApp else {
            Logger.textCapture.error("No target app for paste")
            return
        }

        let pasteboard = NSPasteboard.general
        let savedClipboard = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        Logger.textCapture.debug("Activating for paste: \(targetApp.localizedName ?? "unknown")")
        activateApp(targetApp)
        try? await Task.sleep(for: .milliseconds(200))

        Logger.textCapture.debug("Sending Cmd+V")
        sendKeyboardShortcut(keyCode: KeyCodes.v, command: true)

        scheduleClipboardRestore(savedClipboard)
    }

    private func scheduleClipboardRestore(_ savedContent: String?) {
        guard let saved = savedContent else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(TimingConstants.clipboardRestoreDelay))
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(saved, forType: .string)
            Logger.textCapture.debug("Clipboard restored")
        }
    }

    func getSelectionBounds() -> CGRect? {
        guard let targetApp = previousApp else { return nil }

        let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            Logger.textCapture.debug("Could not get focused element for bounds")
            return nil
        }

        let axElement = element as! AXUIElement

        // Try to get selected text range bounds
        if let bounds = getSelectedTextBounds(from: axElement) {
            lastSelectionBounds = bounds
            return bounds
        }

        // Fallback: get the focused element's position
        if let bounds = getElementBounds(from: axElement) {
            lastSelectionBounds = bounds
            return bounds
        }

        return nil
    }

    private func getSelectedTextBounds(from element: AXUIElement) -> CGRect? {
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        guard rangeResult == .success, let range = selectedRange else {
            return nil
        }

        var bounds: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        )

        guard boundsResult == .success,
              let boundsValue = bounds,
              CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
            return nil
        }

        var rect = CGRect.zero
        if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) {
            Logger.textCapture.debug("Got selection bounds: \(rect.debugDescription)")
            return rect
        }

        return nil
    }

    private func getElementBounds(from element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)

        guard let posValue = position,
              let sizeValue = size,
              CFGetTypeID(posValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        var elementSize = CGSize.zero

        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &elementSize)

        let rect = CGRect(origin: point, size: elementSize)
        Logger.textCapture.debug("Got element bounds (fallback): \(rect.debugDescription)")
        return rect
    }

    private func activateApp(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func sendKeyboardShortcut(keyCode: UInt32, command: Bool = false, shift: Bool = false) {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            Logger.textCapture.error("Failed to create keyboard events")
            return
        }

        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if shift { flags.insert(.maskShift) }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        usleep(50_000) // 50ms - minimal delay between key down/up
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
