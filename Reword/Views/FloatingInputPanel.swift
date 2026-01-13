import SwiftUI
import AppKit

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

        // Create panel - use titled style but hide title bar for proper focus
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 220),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

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
        var panelX = targetPoint.x - 240
        var panelY = targetPoint.y

        // Keep on screen
        panelX = max(screenFrame.minX + 20, min(panelX, screenFrame.maxX - 500))
        panelY = max(screenFrame.minY + 20, min(panelY, screenFrame.maxY - 200))

        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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

    @State private var instruction: String = ""
    @State private var selectedLanguage: TranslateLanguage = .none
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main input area
            VStack(spacing: 12) {
                // Input field
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    TextField("What should I do with this text?", text: $instruction)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isFocused)
                        .onSubmit { submit() }

                    if !instruction.isEmpty {
                        Button(action: submit) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)

                // Selected text preview
                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(selectedTextPreview)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(16)

            Divider()

            // Quick actions row
            HStack(spacing: 6) {
                QuickActionChip(label: "Improve", icon: "wand.and.stars") {
                    onSubmit("Improve this text to be clearer and more professional")
                }

                QuickActionChip(label: "Fix Grammar", icon: "checkmark.circle") {
                    onSubmit("Fix any grammar and spelling errors")
                }

                QuickActionChip(label: "Shorter", icon: "arrow.down.left.and.arrow.up.right") {
                    onSubmit("Make this more concise while keeping the meaning")
                }

                QuickActionChip(label: "Formal", icon: "person.text.rectangle") {
                    onSubmit("Rewrite in a formal professional tone")
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Translate row
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("Translate to:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedLanguage) {
                    ForEach(TranslateLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChangeCompat(of: selectedLanguage) { newValue in
                    if newValue != .none {
                        onSubmit(newValue.translationPrompt)
                    }
                }

                Spacer()

                Text("esc to cancel")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 480)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onExitCommand {
            onCancel()
        }
    }

    private func submit() {
        guard !instruction.isEmpty else { return }
        onSubmit(instruction)
    }
}


struct QuickActionChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isHovered ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundColor(isHovered ? .accentColor : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
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
