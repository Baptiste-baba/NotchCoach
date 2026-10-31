import AppKit

extension ScreenMetrics {
    /// Extrait les mesures d'un écran réel.
    @MainActor
    init(screen: NSScreen) {
        self.init(
            frame: screen.frame,
            safeAreaTopInset: screen.safeAreaInsets.top,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }
}
