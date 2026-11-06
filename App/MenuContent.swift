import AppKit
import CallsUI
import Prompting
import SwiftUI

/// Menu de l'app, dans la barre de menus.
struct MenuContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if appDelegate.callController.isCallActive {
            Button("Arrêter le call") {
                appDelegate.callController.stopCall()
            }
        } else {
            Button("Démarrer un call") {
                appDelegate.callController.startCall()
            }
        }
        Button("Calls enregistrés…") {
            NSApp.activate()
            openWindow(id: CallsWindowView.windowID)
        }
        Divider()
        Picker("Profil", selection: activeProfile) {
            ForEach(profiles.snapshot.profiles) { profile in
                Text(profile.name).tag(Optional(profile))
            }
        }
        Button("Modifier le prompt…") {
            profiles.editPrompt()
        }
        Button("Modifier le playbook…") {
            profiles.editPlaybook()
        }
        Button("Nouveau profil…") {
            // L'app n'a pas de fenêtre active : sans ça, la fenêtre s'ouvrirait derrière celle de l'app active.
            NSApp.activate()
            openWindow(id: ProfileCreationView.windowID)
        }
        Divider()
        #if DEBUG
        Button("Tester Claude") {
            appDelegate.claudeDebugProbe.run()
        }
        Divider()
        #endif
        // Seul moyen de quitter : l'app n'a ni icône dans le Dock ni barre de menus (LSUIElement).
        Button("Quitter NotchCoach") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var profiles: ProfileController { appDelegate.profileController }

    private var activeProfile: Binding<Profile?> {
        Binding(
            get: { profiles.snapshot.activeProfile },
            set: { profile in
                if let profile {
                    profiles.activate(profile)
                }
            }
        )
    }
}
