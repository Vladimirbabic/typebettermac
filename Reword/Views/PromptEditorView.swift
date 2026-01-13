import SwiftUI

struct PromptEditorView: View {
    let prompt: RephrasePrompt?
    let onSave: (RephrasePrompt) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var instruction: String = ""

    var isEditing: Bool {
        prompt != nil
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Prompt" : "New Prompt")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("e.g., Professional, Casual, Shorter", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instruction")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $instruction)
                    .font(.body)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Tell the AI how to rephrase the text. Be specific about the tone, style, or changes you want.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    let newPrompt = RephrasePrompt(
                        id: prompt?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        instruction: instruction.trimmingCharacters(in: .whitespaces)
                    )
                    onSave(newPrompt)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 450, height: 350)
        .onAppear {
            if let prompt = prompt {
                name = prompt.name
                instruction = prompt.instruction
            }
        }
    }
}

#Preview("New Prompt") {
    PromptEditorView(
        prompt: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Edit Prompt") {
    PromptEditorView(
        prompt: RephrasePrompt(name: "Test", instruction: "Test instruction"),
        onSave: { _ in },
        onCancel: {}
    )
}
