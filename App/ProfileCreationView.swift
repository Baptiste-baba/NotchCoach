import SwiftUI

/// Fenêtre « Nouveau profil » : un nom et une description de la situation, à partir desquels Claude écrit le prompt.
struct ProfileCreationView: View {
    static let windowID = "new-profile"

    let profiles: ProfileController
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var name = ""
    @State private var description = ""
    @State private var isGenerating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nom du profil").font(.headline)
                TextField("Nom du profil", text: $name, prompt: Text("Entretien iOS"))
                    .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Situation").font(.headline)
                TextEditor(text: $description)
                    .font(.body)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                Text("Qui tu es, avec qui tu parles, ce que tu attends des suggestions. Claude écrit le prompt du profil et les rubriques de son playbook, que tu rempliras.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if isGenerating {
                    ProgressView().controlSize(.small)
                    Text("Claude écrit le prompt, environ 30 secondes…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Créer le profil", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canCreate: Bool {
        !isGenerating && !trimmedName.isEmpty && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func create() {
        isGenerating = true
        Task {
            try? await profiles.createProfile(named: trimmedName, description: description)
            isGenerating = false
            name = ""
            description = ""
            dismissWindow(id: Self.windowID)
        }
    }
}
