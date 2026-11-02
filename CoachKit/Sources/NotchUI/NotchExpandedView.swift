import SwiftUI

/// Contenu de l'état déplié : texte affiché sous la notch. Le panel prend la hauteur du texte jusqu'à un plafond ;
/// au-delà, le texte défile.
struct NotchExpandedView: View {
    var text: String

    var body: some View {
        ScrollView(.vertical) {
            NotchExpandedText(text: text)
        }
        // Suit la fin du texte pendant qu'il s'écrit.
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }
}

/// Texte et marges de l'état déplié. Le contrôleur mesure cette vue pour fixer la hauteur du panel.
struct NotchExpandedText: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}
