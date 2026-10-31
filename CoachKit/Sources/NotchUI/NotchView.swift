import SwiftUI

/// Vue racine affichée dans le panel de la notch.
struct NotchView: View {
    var style: NotchPlacement.Style

    var body: some View {
        shape
            // Sur la notch, toute la fenêtre est hors zone sûre : sans ça, SwiftUI pousse le contenu hors du panel.
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var shape: some View {
        switch style {
        case .notch:
            // Noir, coins inférieurs arrondis : se fond dans la notch matérielle qu'il prolonge.
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                .fill(.black)
        case .pill:
            Capsule()
                .fill(.black)
        }
    }
}
