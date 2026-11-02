import SwiftUI

/// Vue racine affichée dans le panel de la notch.
struct NotchView: View {
    var style: NotchPlacement.Style
    var contentTopInset: CGFloat = 0
    var content: NotchContent = .empty

    var body: some View {
        ZStack(alignment: .top) {
            background
            if let expandedText {
                NotchExpandedView(text: expandedText.text, color: expandedText.color)
                    .padding(.top, contentTopInset)
            }
        }
        // Sur la notch, toute la fenêtre est hors zone sûre : sans ça, SwiftUI pousse le contenu hors du panel.
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var background: some View {
        switch (style, content) {
        case (.notch, .empty):
            // Noir, coins inférieurs arrondis : se fond dans la notch matérielle qu'il prolonge.
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                .fill(.black)
        case (.notch, .text), (.notch, .error):
            UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                .fill(.black)
        case (.pill, .empty):
            Capsule()
                .fill(.black)
        case (.pill, .text), (.pill, .error):
            RoundedRectangle(cornerRadius: 18)
                .fill(.black)
        }
    }

    /// Texte de l'état déplié et sa couleur : blanc, ou rouge pour une erreur.
    private var expandedText: (text: String, color: Color)? {
        switch content {
        case .empty: nil
        case .text(let text): (text, .white)
        case .error(let text): (text, .red)
        }
    }
}
