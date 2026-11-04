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
        switch (style, content.isEmpty) {
        case (.notch, true):
            // Noir, coins inférieurs arrondis : se fond dans la notch matérielle qu'il prolonge.
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                .fill(.black)
        case (.notch, false):
            UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                .fill(.black)
        case (.pill, true):
            Capsule()
                .fill(.black)
        case (.pill, false):
            RoundedRectangle(cornerRadius: 18)
                .fill(.black)
        }
    }

    /// Texte de l'état déplié et sa couleur : le message passager, sinon la dernière ligne, en rouge pour une erreur.
    private var expandedText: (text: String, color: Color)? {
        if let notice = content.notice {
            return (notice, .white)
        }
        guard let line = content.lines.last else { return nil }
        return (line.text, line.isError ? .red : .white)
    }
}
