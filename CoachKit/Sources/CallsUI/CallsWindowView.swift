import CallArchive
import SwiftUI

/// Fenêtre « Calls enregistrés » : la liste des calls à gauche, le call choisi à droite.
public struct CallsWindowView: View {
    public static let windowID = "calls"

    let library: CallLibrary

    public init(library: CallLibrary) {
        self.library = library
    }

    public var body: some View {
        EmptyView()
    }
}
