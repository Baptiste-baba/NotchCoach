import CoreGraphics

/// Placement calculé du panel sur un écran.
struct NotchPlacement: Equatable, Sendable {
    enum Style: Equatable, Sendable {
        /// Aligné sur la notch matérielle, en haut de l'écran.
        case notch
        /// Pilule centrée en haut de l'écran, quand il n'y a pas de notch (écran externe).
        case pill
    }

    /// Cadre du panel, dans le repère global d'AppKit.
    var frame: CGRect
    var style: Style
    /// Hauteur réservée en haut du panel à la notch matérielle : le contenu commence en dessous.
    var contentTopInset: CGFloat = 0
}
