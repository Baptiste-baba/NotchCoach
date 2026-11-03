import AVFoundation

/// Convertit l'audio capturé, quel que soit son format, au format de sortie du module : 16 kHz mono Float32.
/// Un convertisseur par flux continu : il garde son état d'un buffer à l'autre.
final class MonoResampler {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    /// Buffer en attente de conversion, rendu une seule fois au convertisseur.
    private var pendingInput: AVAudioPCMBuffer?

    /// `nil` si ce format ne peut pas être converti.
    init?(from format: AVAudioFormat) {
        guard
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(AudioChunk.sampleRate),
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: format, to: outputFormat)
        else { return nil }
        // Plusieurs canaux sont mélangés, au lieu de ne garder que le premier.
        converter.downmix = true
        self.converter = converter
        self.outputFormat = outputFormat
    }

    /// Échantillons à 16 kHz mono de `buffer`, au format donné à la création.
    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        // Marge pour les échantillons que le filtre du rééchantillonnage gardait du buffer précédent.
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }
        pendingInput = buffer
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { [self] _, inputStatus in
            guard let input = pendingInput else {
                // Pas `.endOfStream` : le flux continue au prochain buffer, le convertisseur garde son état.
                inputStatus.pointee = .noDataNow
                return nil
            }
            pendingInput = nil
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, let channel = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }
}
