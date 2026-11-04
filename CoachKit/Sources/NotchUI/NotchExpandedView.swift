import SwiftUI

/// Contenu de l'état déplié : l'historique du call, puis le message passager. Le panel prend la hauteur de la dernière
/// ligne, jusqu'à un plafond : les précédentes sont au-dessus, en faisant défiler vers le haut.
struct NotchExpandedView: View {
    var content: NotchContent
    @State private var position = ScrollPosition(edge: .bottom)

    var body: some View {
        ScrollView(.vertical) {
            // Mise en page des seules lignes visibles : un long call en compte une centaine, et la dernière change à
            // chaque mot.
            LazyVStack(spacing: 0) {
                ForEach(content.lines) { line in
                    NotchExpandedText(text: line.text, color: line.isError ? .red : .white)
                }
                if let notice = content.notice {
                    NotchExpandedText(text: notice, color: .white.opacity(0.6))
                }
            }
        }
        .scrollPosition($position)
        // Suit la fin de la dernière ligne pendant qu'elle s'écrit.
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        // Une nouvelle ligne ramène en bas, même après avoir remonté l'historique.
        .onChange(of: content.lines.last?.id) {
            position.scrollTo(edge: .bottom)
        }
        .onChange(of: content.notice) {
            position.scrollTo(edge: .bottom)
        }
    }
}

/// Texte et marges de l'état déplié. Le contrôleur mesure cette vue pour fixer la hauteur du panel.
struct NotchExpandedText: View {
    var text: String
    var color: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}
