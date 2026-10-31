import SwiftUI

@main struct NotchCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Seul moyen de quitter : l'app n'a ni icône dans le Dock ni barre de menus (LSUIElement).
        MenuBarExtra("NotchCoach", systemImage: "waveform") {
            Button("Quitter NotchCoach") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
