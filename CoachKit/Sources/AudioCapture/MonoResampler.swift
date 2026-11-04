import AVFoundation

/// Convertit l'audio capturé, quel que soit son format, au format de sortie du module : 16 kHz mono Float32.
/// Un convertisseur par flux continu : il garde son état d'un buffer à l'autre.
final class MonoResampler {
    private let converter: AVAudioConverter

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
    }

    /// Échantillons à 16 kHz mono de `buffer`, au format donné à la création. Le filtre du rééchantillonnage garde
    /// les tout derniers, rendus avec le buffer suivant.
    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let outputFormat = converter.outputFormat
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        var samples: [Float] = []
        var offset: AVAudioFrameCount = 0
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return samples }
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { packetCount, inputStatus in
                // Le convertisseur ne lit pas plus de `packetCount` images à la fois et ignorerait le reste :
                // l'entrée lui est donnée par tranches.
                let count = min(packetCount, buffer.frameLength - offset)
                guard count > 0, let slice = Self.slice(of: buffer, from: offset, count: count) else {
                    // Pas `.endOfStream` : le flux continue au prochain buffer, le convertisseur garde son état.
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                offset += count
                inputStatus.pointee = .haveData
                return slice
            }
            guard status != .error, let channel = output.floatChannelData else { return samples }
            samples.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
            // Sortie pleine avant la fin de l'entrée : un tour de plus.
            guard status == .haveData, offset < buffer.frameLength else { return samples }
        }
    }

    /// Images `start..<start + count` de `buffer`, copiées dans un nouveau buffer du même format.
    private static func slice(
        of buffer: AVAudioPCMBuffer,
        from start: AVAudioFrameCount,
        count: AVAudioFrameCount
    ) -> AVAudioPCMBuffer? {
        guard let slice = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: count) else { return nil }
        slice.frameLength = count
        // Par canal si le format n'est pas entrelacé, sinon pour tous les canaux à la fois.
        let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(slice.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            guard let fromData = from.mData, let toData = to.mData else { return nil }
            toData.copyMemory(
                from: fromData.advanced(by: Int(start) * bytesPerFrame),
                byteCount: Int(count) * bytesPerFrame
            )
        }
        return slice
    }
}
