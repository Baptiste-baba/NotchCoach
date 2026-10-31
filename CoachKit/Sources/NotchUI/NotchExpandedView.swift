import SwiftUI

/// Contenu de l'état déplié : texte affiché sous la notch.
struct NotchExpandedView: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}
