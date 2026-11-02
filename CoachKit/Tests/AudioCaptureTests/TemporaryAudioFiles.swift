import AVFoundation
import Foundation

/// Fichiers audio de synthèse pour les tests, dans un dossier temporaire supprimé avec l'instance.
final class TemporaryAudioFiles {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReplayAudioSourceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Écrit un WAV Float32 dont chaque canal garde une valeur constante, dans l'ordre de `channelValues`.
    func wav(sampleRate: Double = 16_000, frameCount: Int, channelValues: [Float]) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelValues.count,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
        ]
        // Le fichier est refermé, et son en-tête finalisé, à la sortie de la fonction.
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        for (channel, value) in channelValues.enumerated() {
            buffer.floatChannelData![channel].update(repeating: value, count: frameCount)
        }
        try file.write(from: buffer)
        return url
    }

    /// Fichier qui porte l'extension d'un WAV sans en être un.
    func notAudio() throws -> URL {
        let url = directory.appendingPathComponent("faux.wav")
        try Data("pas de l'audio".utf8).write(to: url)
        return url
    }
}
