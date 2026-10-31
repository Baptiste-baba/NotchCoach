import CoreGraphics

/// Mesures d'un écran utiles au placement du panel, extraites de `NSScreen`.
/// Toutes les valeurs sont en points, dans le repère global d'AppKit (origine en bas à gauche).
struct ScreenMetrics: Equatable, Sendable {
    /// Cadre complet de l'écran (`NSScreen.frame`).
    var frame: CGRect
    /// Hauteur réservée en haut de l'écran (`NSScreen.safeAreaInsets.top`) : hauteur de la notch, 0 sans notch.
    var safeAreaTopInset: CGFloat
    /// Zone de la barre de menus à gauche de la notch (`NSScreen.auxiliaryTopLeftArea`), `nil` sans notch.
    var auxiliaryTopLeftArea: CGRect?
    /// Zone de la barre de menus à droite de la notch (`NSScreen.auxiliaryTopRightArea`), `nil` sans notch.
    var auxiliaryTopRightArea: CGRect?
}
