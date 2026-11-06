import Prompting
import SwiftUI

/// Fenêtre « Nouveau profil » : un nom et une description de la situation, à partir desquels Claude écrit le prompt.
struct ProfileCreationView: View {
    static let windowID = "new-profile"

    let profiles: ProfileController
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var name = ""
    @State private var description = ""
    /// Génération en cours ; annulée par « Annuler » ou à la fermeture de la fenêtre.
    @State private var generation: Task<Void, Never>?
    @State private var errorMessage: String?

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
            .disabled(isGenerating)
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if isGenerating {
                    ProgressView().controlSize(.small)
                    Text("Claude écrit le prompt…").foregroundStyle(.secondary)
                }
                Spacer()
                if isGenerating {
                    Button("Annuler") {
                        generation?.cancel()
                    }
                }
                Button("Créer le profil", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onDisappear {
            generation?.cancel()
        }
    }

    private var isGenerating: Bool { generation != nil }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canCreate: Bool {
        !isGenerating && !trimmedName.isEmpty && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func create() {
        errorMessage = nil
        generation = Task {
            defer { generation = nil }
            do throws(PromptingError) {
                try await profiles.createProfile(named: trimmedName, description: description)
                name = ""
                description = ""
                dismissWindow(id: Self.windowID)
            } catch .generationCancelled {
                // Annulée par l'utilisateur : la saisie est gardée, sans message.
            } catch {
                // La saisie est gardée, pour corriger le nom ou réessayer.
                errorMessage = error.localizedDescription
            }
        }
    }
}
