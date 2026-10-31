import SwiftUI

/// Vue racine affichée dans le panel de la notch.
struct NotchView: View {
    var style: NotchPlacement.Style
    var contentTopInset: CGFloat = 0
    var content: NotchContent = .empty

    var body: some View {
        ZStack(alignment: .top) {
            background
            if case .text(let text) = content {
                NotchExpandedView(text: text)
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
        case (.notch, .text):
            UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                .fill(.black)
        case (.pill, .empty):
            Capsule()
                .fill(.black)
        case (.pill, .text):
            RoundedRectangle(cornerRadius: 18)
                .fill(.black)
        }
    }
}
