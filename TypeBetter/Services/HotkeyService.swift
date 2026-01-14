import Foundation
import Carbon
import AppKit
import OSLog

final class HotkeyService {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private static var sharedInstance: HotkeyService?

    init() {
        HotkeyService.sharedInstance = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeyChanged,
            object: nil
        )
    }

    deinit {
        unregisterHotkey()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func hotkeySettingsChanged() {
        guard let callback = self.callback else { return }
        unregisterHotkey()
        registerHotkey(callback: callback)
    }

    func registerHotkey(callback: @escaping () -> Void) {
        self.callback = callback

        let settings = SettingsManager.shared
        let keyCode = settings.hotkeyKeyCode
        let modifiers = settings.hotkeyModifiers

        guard keyCode != 0 else {
            Logger.hotkey.warning("No hotkey configured")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }

            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            if status == noErr && hotkeyID.id == HotkeyConstants.id {
                DispatchQueue.main.async {
                    HotkeyService.sharedInstance?.callback?()
                }
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        let hotkeyID = EventHotKeyID(signature: HotkeyConstants.signature, id: HotkeyConstants.id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            Logger.hotkey.error("Failed to register hotkey: \(status)")
        } else {
            Logger.hotkey.info("Hotkey registered: keyCode=\(keyCode), modifiers=\(modifiers)")
        }
    }

    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
            Logger.hotkey.debug("Hotkey unregistered")
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
