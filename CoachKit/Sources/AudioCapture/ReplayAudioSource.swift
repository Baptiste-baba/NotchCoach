import AVFoundation
import Foundation
import os

private let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "AudioCapture")

/// Mode replay : lit un fichier stéréo à vitesse réelle à la place d'un vrai call (canal gauche = moi,
/// canal droit = prospect) et fournit chaque canal en 16 kHz mono Float32, comme la capture réelle.
/// Une source ne sert qu'une fois : après `stop()` ou la fin du fichier, `start()` n'a plus d'effet.
public actor ReplayAudioSource: AudioSource {
    /// Taille d'un morceau émis : 4096 échantillons, soit 256 ms.
    static let chunkFrameCount = 4096

    private enum State {
        case idle
        case playing(Task<Void, Never>)
        case finished
    }

    private let file: URL
    private let meChunks: AsyncStream<AudioChunk>
    private let meContinuation: AsyncStream<AudioChunk>.Continuation
    private let prospectChunks: AsyncStream<AudioChunk>
    private let prospectContinuation: AsyncStream<AudioChunk>.Continuation
    private var state = State.idle

    public init(file: URL) {
        self.file = file
        (meChunks, meContinuation) = AsyncStream.makeStream()
        (prospectChunks, prospectContinuation) = AsyncStream.makeStream()
    }

    public nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk> {
        switch speaker {
        case .me: meChunks
        case .prospect: prospectChunks
        }
    }

    /// Ouvre le fichier et commence la lecture à vitesse réelle.
    public func start() throws(AudioCaptureError) {
        guard case .idle = state else { return }
        // Vérifié à part : pour un fichier absent, AVAudioFile ne renvoie qu'un code Core Audio illisible.
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw .replayFileNotFound(path: file.path)
        }
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: file)
        } catch {
            throw .replayFileUnreadable(path: file.path, reason: error.localizedDescription)
        }
        let channelCount = Int(audioFile.processingFormat.channelCount)
        guard channelCount == 2 else {
            throw .replayFileNotStereo(channelCount: channelCount)
        }
        guard let reader = StereoReader(file: audioFile, frameCount: Self.chunkFrameCount) else {
            throw .unsupportedReplayFormat
        }
        state = .playing(Task { await play(reader) })
    }

    /// Arrête la lecture et termine les deux flux.
    public func stop() {
        if case .playing(let task) = state {
            task.cancel()
        }
        finish()
    }

    private func play(_ reader: StereoReader) async {
        let clock = ContinuousClock()
        let origin = clock.now
        var position = 0
        while !Task.isCancelled, let block = reader.next() {
            let startTime = Double(position) / Double(AudioChunk.sampleRate)
            position += block.left.count
            // Dans un vrai call, l'audio n'est disponible qu'une fois prononcé : le morceau est émis à sa fin.
            try? await clock.sleep(until: origin + .seconds(Double(position) / Double(AudioChunk.sampleRate)))
            guard !Task.isCancelled else { break }
            meContinuation.yield(AudioChunk(samples: block.left, startTime: startTime))
            prospectContinuation.yield(AudioChunk(samples: block.right, startTime: startTime))
        }
        finish()
    }

    private func finish() {
        state = .finished
        meContinuation.finish()
        prospectContinuation.finish()
    }
}

/// Lit un fichier audio stéréo par blocs, rééchantillonnés en 16 kHz Float32 et séparés en deux canaux.
private final class StereoReader {
    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let output: AVAudioPCMBuffer
    private var reachedEnd = false

    /// `nil` si le format du fichier ne peut pas être converti.
    init?(file: AVAudioFile, frameCount: Int) {
        guard
            let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(AudioChunk.sampleRate),
                channels: 2,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: file.processingFormat, to: target),
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(frameCount))
        else { return nil }
        self.file = file
        self.converter = converter
        self.output = output
    }

    /// Bloc suivant, ou `nil` à la fin du fichier. Le dernier bloc peut être plus court. Une erreur de lecture
    /// ou de conversion est journalisée et termine la lecture, comme la fin du fichier.
    func next() -> (left: [Float], right: [Float])? {
        output.frameLength = 0
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { [self] packetCount, inputStatus in
            guard !reachedEnd,
                  let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: packetCount)
            else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            do {
                try file.read(into: input, frameCount: packetCount)
            } catch {
                logger.error("Lecture du fichier de replay interrompue : \(error.localizedDescription, privacy: .public)")
            }
            guard input.frameLength > 0 else {
                reachedEnd = true
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error {
            logger.error("Conversion du fichier de replay impossible : \(conversionError?.localizedDescription ?? "erreur inconnue", privacy: .public)")
            return nil
        }
        guard output.frameLength > 0, let channels = output.floatChannelData else { return nil }
        let count = Int(output.frameLength)
        return (
            Array(UnsafeBufferPointer(start: channels[0], count: count)),
            Array(UnsafeBufferPointer(start: channels[1], count: count))
        )
    }
}
