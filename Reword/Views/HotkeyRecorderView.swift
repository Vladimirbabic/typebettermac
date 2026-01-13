import SwiftUI
import AppKit
import Carbon

struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @State private var isRecording = false

    var body: some View {
        HStack {
            HotkeyTextField(
                keyCode: $keyCode,
                modifiers: $modifiers,
                isRecording: $isRecording
            )
            .frame(width: 140, height: 28)

            if keyCode != 0 {
                Button("Clear") {
                    keyCode = 0
                    modifiers = 0
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct HotkeyTextField: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> HotkeyNSTextField {
        let textField = HotkeyNSTextField()
        textField.hotkeyDelegate = context.coordinator
        textField.isBordered = true
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .exterior
        updateDisplay(textField)
        return textField
    }

    func updateNSView(_ nsView: HotkeyNSTextField, context: Context) {
        updateDisplay(nsView)
    }

    private func updateDisplay(_ textField: NSTextField) {
        if isRecording {
            textField.stringValue = "Type shortcut..."
            textField.textColor = .systemBlue
        } else if keyCode == 0 {
            textField.stringValue = "Click to record"
            textField.textColor = .secondaryLabelColor
        } else {
            textField.stringValue = hotkeyString()
            textField.textColor = .labelColor
        }
    }

    private func hotkeyString() -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if let key = keyCodeToString(keyCode) { parts.append(key) }
        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt32) -> String? {
        KeyCodes.displayStrings[code]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, HotkeyTextFieldDelegate {
        var parent: HotkeyTextField

        init(_ parent: HotkeyTextField) {
            self.parent = parent
        }

        func hotkeyTextFieldDidStartRecording() {
            parent.isRecording = true
        }

        func hotkeyTextFieldDidEndRecording() {
            parent.isRecording = false
        }

        func hotkeyTextField(didRecordKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            let carbonMods = carbonModifiers(from: modifiers)

            let isFunctionKey = KeyCodes.functionKeys.contains(keyCode)
            let hasModifier = carbonMods & UInt32(cmdKey) != 0 || carbonMods & UInt32(controlKey) != 0

            // Allow function keys OR keys with Cmd/Ctrl
            guard isFunctionKey || hasModifier else {
                return
            }

            parent.keyCode = UInt32(keyCode)
            parent.modifiers = carbonMods
            parent.isRecording = false
        }

        private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var result: UInt32 = 0
            if flags.contains(.command) { result |= UInt32(cmdKey) }
            if flags.contains(.shift) { result |= UInt32(shiftKey) }
            if flags.contains(.option) { result |= UInt32(optionKey) }
            if flags.contains(.control) { result |= UInt32(controlKey) }
            return result
        }
    }
}

protocol HotkeyTextFieldDelegate: AnyObject {
    func hotkeyTextFieldDidStartRecording()
    func hotkeyTextFieldDidEndRecording()
    func hotkeyTextField(didRecordKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
}

class HotkeyNSTextField: NSTextField {
    weak var hotkeyDelegate: HotkeyTextFieldDelegate?
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            isRecording = true
            hotkeyDelegate?.hotkeyTextFieldDidStartRecording()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        hotkeyDelegate?.hotkeyTextFieldDidEndRecording()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            // Ignore pure modifier keys
            if KeyCodes.modifierOnlyKeys.contains(event.keyCode) {
                return
            }

            hotkeyDelegate?.hotkeyTextField(didRecordKeyCode: event.keyCode, modifiers: event.modifierFlags)
            window?.makeFirstResponder(nil)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

#Preview {
    HotkeyRecorderView(keyCode: .constant(0x0F), modifiers: .constant(UInt32(cmdKey | shiftKey)))
        .padding()
        .frame(width: 300)
}
