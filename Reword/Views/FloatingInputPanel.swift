import SwiftUI
import AppKit

// Custom panel that can become key even when borderless
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class FloatingInputController {
    static let shared = FloatingInputController()

    private var panel: NSPanel?
    private var onSubmit: ((String) -> Void)?

    func show(selectedText: String, selectionBounds: CGRect?, onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
        hide()

        // Determine position - prefer selection bounds, fallback to mouse
        let targetPoint: NSPoint
        if let bounds = selectionBounds {
            // Position above the selection (convert from screen coordinates)
            // Note: Accessibility bounds are in screen coords with origin at top-left
            // NSScreen coords have origin at bottom-left, so we need to convert
            let screenHeight = NSScreen.main?.frame.height ?? 1000
            let flippedY = screenHeight - bounds.origin.y
            targetPoint = NSPoint(x: bounds.origin.x + bounds.width / 2, y: flippedY + 20)
        } else {
            targetPoint = NSEvent.mouseLocation
        }

        // Create borderless panel that can receive keyboard input
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false  // We use SwiftUI shadow instead
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let inputView = FloatingInputView(
            selectedTextPreview: String(selectedText.prefix(80)) + (selectedText.count > 80 ? "..." : ""),
            onSubmit: { [weak self] instruction in
                self?.onSubmit?(instruction)
                self?.hide()
            },
            onCancel: { [weak self] in
                self?.hide()
            }
        )

        panel.contentView = NSHostingView(rootView: inputView)

        // Position near selection/mouse
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var panelX = targetPoint.x - 250  // Center the 500px wide panel
        var panelY = targetPoint.y

        // Keep on screen
        panelX = max(screenFrame.minX + 20, min(panelX, screenFrame.maxX - 520))
        panelY = max(screenFrame.minY + 20, min(panelY, screenFrame.maxY - 260))

        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))

        // Show panel without activating the whole app (which would show settings)
        // Use orderFrontRegardless to bring panel to front
        panel.orderFrontRegardless()
        panel.makeKey()

        // Activate app but immediately ensure only our panel is visible
        // by setting the panel as the only key window
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        // Close any other windows that might have appeared
        for window in NSApp.windows where window !== panel && window.isVisible {
            if window.title == "TypeBetter Settings" || window.contentView is NSHostingView<EmptyView> {
                window.orderOut(nil)
            }
        }

        self.panel = panel
    }

    func hide() {
        panel?.close()
        panel = nil
    }
}

struct FloatingInputView: View {
    let selectedTextPreview: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    // Brand colors
    private let accentGradient = LinearGradient(
        colors: [Color(red: 139/255, green: 92/255, blue: 246/255), Color(red: 168/255, green: 85/255, blue: 247/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @State private var instruction: String = ""
    @State private var selectedLanguage: TranslateLanguage = .none
    @State private var keyboardMonitor: Any?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main input area
            VStack(spacing: 16) {
                // Input field with glow effect
                HStack(spacing: 14) {
                    SparklesIcon(gradient: accentGradient)

                    TextField("What should I do with this text?", text: $instruction)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular))
                        .focused($isFocused)
                        .onSubmit { submit() }

                    if !instruction.isEmpty {
                        Button(action: submit) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(accentGradient)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

                // Selected text preview
                if !selectedTextPreview.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text(selectedTextPreview)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                            .truncationMode(.tail)

                        Spacer()
                    }
                    .padding(.horizontal, 6)
                }
            }
            .padding(20)

            // Subtle separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Quick actions row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(SettingsManager.shared.quickActions.enumerated()), id: \.element.id) { index, action in
                        QuickActionChip(
                            label: action.name,
                            icon: action.icon,
                            buttonColor: action.buttonColor,
                            shortcutNumber: index < 9 ? index + 1 : nil
                        ) {
                            onSubmit(action.prompt)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 14)

            // Bottom bar with translate and hints
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Picker("", selection: $selectedLanguage) {
                    ForEach(TranslateLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChangeCompat(of: selectedLanguage) { newValue in
                    if newValue != .none {
                        onSubmit(newValue.translationPrompt)
                    }
                }

                Spacer()

                // Keyboard hint
                HStack(spacing: 6) {
                    Text("esc")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)

                    Text("to cancel")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
        }
        .frame(width: 500)
        .background(
            ZStack {
                // Base dark background
                Color(red: 28/255, green: 28/255, blue: 30/255)

                // Subtle gradient overlay
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
        .shadow(color: Color.purple.opacity(0.1), radius: 60, x: 0, y: 10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onExitCommand {
            onCancel()
        }
    }

    private func submit() {
        guard !instruction.isEmpty else { return }
        onSubmit(instruction)
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle if input field is empty (so user can still type)
            guard instruction.isEmpty else { return event }

            // Check for number keys 1-9
            let key = event.charactersIgnoringModifiers ?? ""
            if let number = Int(key), number >= 1 && number <= 9 {
                let actions = SettingsManager.shared.quickActions
                let index = number - 1
                if index < actions.count {
                    onSubmit(actions[index].prompt)
                    return nil // Consume the event
                }
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
}


struct QuickActionChip: View {
    let label: String
    let icon: String
    var buttonColor: ButtonColor = .none
    var shortcutNumber: Int? = nil
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Shortcut number badge
                if let number = shortcutNumber {
                    Text("\(number)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(isHovered ? 0.2 : 0.12))
                        )
                }

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(chipBackground)
            .foregroundColor(chipForeground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(chipBorder, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }

    private var hasColor: Bool {
        buttonColor.name != "Default"
    }

    private var chipBackground: Color {
        if hasColor {
            return isHovered ? buttonColor.color.opacity(0.2) : buttonColor.color.opacity(0.1)
        } else {
            return isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
        }
    }

    private var chipForeground: Color {
        if hasColor {
            return isHovered ? buttonColor.color : buttonColor.color.opacity(0.85)
        } else {
            return isHovered ? .white : .white.opacity(0.75)
        }
    }

    private var chipBorder: Color {
        if hasColor {
            return isHovered ? buttonColor.color.opacity(0.4) : buttonColor.color.opacity(0.2)
        } else {
            return isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
        }
    }
}

// Helper for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// Sparkles icon with optional animation for macOS 14+
struct SparklesIcon: View {
    let gradient: LinearGradient

    var body: some View {
        if #available(macOS 14.0, *) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(gradient)
                .symbolEffect(.pulse, options: .repeating)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(gradient)
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
