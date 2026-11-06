import AppKit
import SwiftUI

/// Couleurs et polices de la fenêtre des calls, tirées de l'icône de l'app.
enum CallsStyle {
    /// Sélection et répliques de l'utilisateur. Plus clair en mode sombre, où le violet de l'icône manque de contraste
    /// pour du texte.
    static let violet = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0x9D / 255, green: 0x8C / 255, blue: 0xFF / 255, alpha: 1)
            : NSColor(srgbRed: 0x6B / 255, green: 0x4E / 255, blue: 0xFF / 255, alpha: 1)
    })
    /// Titres : l'encre de la notch, ou le texte normal en mode sombre, où elle serait illisible.
    static let ink = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .labelColor
            : NSColor(srgbRed: 0x16 / 255, green: 0x12 / 255, blue: 0x3A / 255, alpha: 1)
    })
    /// Étincelles du débrief : ce qui a marché, ce qui est à travailler.
    static let strength = Color(red: 0x3D / 255, green: 0xD6 / 255, blue: 0x8C / 255)
    static let improvement = Color(red: 0xF2 / 255, green: 0xB7 / 255, blue: 0x05 / 255)
    /// Texte du résumé et du débrief : New York, le serif d'Apple, comme un carnet qu'on relit.
    static let reading = Font.system(size: 15, design: .serif)
    static let readingLineSpacing: CGFloat = 4
    /// Moins de 80 caractères par ligne.
    static let readingWidth: CGFloat = 620
}
