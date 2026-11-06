import CallsUI
import SwiftUI

@main struct NotchCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchCoach", systemImage: "waveform") {
            MenuContent(appDelegate: appDelegate)
        }
        Window("Nouveau profil", id: ProfileCreationView.windowID) {
            ProfileCreationView(profiles: appDelegate.profileController)
        }
        .windowResizability(.contentSize)
        // Ouverte seulement depuis le menu, jamais au lancement.
        .defaultLaunchBehavior(.suppressed)
        Window("Calls enregistrés", id: CallsWindowView.windowID) {
            CallsWindowView(library: appDelegate.callLibrary)
        }
        .defaultSize(width: 1000, height: 660)
        // Jamais au lancement, ni à la fin d'un call : seulement depuis le menu.
        .defaultLaunchBehavior(.suppressed)
    }
}
