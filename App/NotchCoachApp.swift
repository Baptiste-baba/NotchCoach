import SwiftUI

@main struct NotchCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Seul moyen de quitter : l'app n'a ni icône dans le Dock ni barre de menus (LSUIElement).
        MenuBarExtra("NotchCoach", systemImage: "waveform") {
            if appDelegate.callController.isCallActive {
                Button("Arrêter le call") {
                    appDelegate.callController.stopCall()
                }
            } else {
                Button("Démarrer un call") {
                    appDelegate.callController.startCall()
                }
            }
            Divider()
            Button("Modifier le playbook…") {
                appDelegate.editPlaybook()
            }
            Divider()
            #if DEBUG
            Button("Tester Claude") {
                appDelegate.claudeDebugProbe.run()
            }
            Divider()
            #endif
            Button("Quitter NotchCoach") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
