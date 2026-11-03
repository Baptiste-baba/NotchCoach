import AVFoundation

/// Convertit l'audio capturé, quel que soit son format, au format de sortie du module : 16 kHz mono Float32.
/// Un convertisseur par flux continu : il garde son état d'un buffer à l'autre.
final class MonoResampler {
    /// `nil` si ce format ne peut pas être converti.
    init?(from format: AVAudioFormat) {
        fatalError("TODO")
    }

    /// Échantillons à 16 kHz mono de `buffer`, au format donné à la création.
    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        fatalError("TODO")
    }
}
