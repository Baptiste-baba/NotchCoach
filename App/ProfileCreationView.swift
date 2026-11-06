import SwiftUI

/// Fenêtre « Nouveau profil » : un nom et une description de la situation, à partir desquels Claude écrit le prompt.
struct ProfileCreationView: View {
    static let windowID = "new-profile"

    let profiles: ProfileController

    var body: some View {
        EmptyView()
    }
}
