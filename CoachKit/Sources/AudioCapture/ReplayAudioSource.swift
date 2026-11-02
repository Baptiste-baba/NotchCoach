import AVFoundation
import Foundation

/// Mode replay : lit un fichier stéréo à vitesse réelle à la place d'un vrai call (canal gauche = moi,
/// canal droit = prospect) et fournit chaque canal en 16 kHz mono Float32, comme la capture réelle.
public actor ReplayAudioSource {
    /// Taille d'un morceau émis : 4096 échantillons, soit 256 ms.
    static let chunkFrameCount = 4096

    private let file: URL
    private let meChunks: AsyncStream<AudioChunk>
    private let meContinuation: AsyncStream<AudioChunk>.Continuation
    private let prospectChunks: AsyncStream<AudioChunk>
    private let prospectContinuation: AsyncStream<AudioChunk>.Continuation
    private var playback: Task<Void, Never>?

    public init(file: URL) {
        self.file = file
        (meChunks, meContinuation) = AsyncStream.makeStream()
        (prospectChunks, prospectContinuation) = AsyncStream.makeStream()
    }

    /// Audio d'un canal. Le flux se termine à la fin du fichier ou à l'arrêt.
    public nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk> {
        switch speaker {
        case .me: meChunks
        case .prospect: prospectChunks
        }
    }

    /// Ouvre le fichier et commence la lecture à vitesse réelle.
    public func start() throws {
        let reader = try StereoReader(file: AVAudioFile(forReading: file), frameCount: Self.chunkFrameCount)
        playback = Task { await play(reader) }
    }

    /// Arrête la lecture et termine les deux flux.
    public func stop() {
        playback?.cancel()
        playback = nil
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

    init(file: AVAudioFile, frameCount: Int) {
        let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(AudioChunk.sampleRate),
            channels: 2,
            interleaved: false
        )!
        self.file = file
        converter = AVAudioConverter(from: file.processingFormat, to: target)!
        output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(frameCount))!
    }

    /// Bloc suivant, ou `nil` à la fin du fichier. Le dernier bloc peut être plus court.
    func next() -> (left: [Float], right: [Float])? {
        output.frameLength = 0
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { [self] packetCount, inputStatus in
            guard !reachedEnd else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: packetCount)!
            try? file.read(into: input, frameCount: packetCount)
            guard input.frameLength > 0 else {
                reachedEnd = true
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, output.frameLength > 0, let channels = output.floatChannelData else { return nil }
        let count = Int(output.frameLength)
        return (
            Array(UnsafeBufferPointer(start: channels[0], count: count)),
            Array(UnsafeBufferPointer(start: channels[1], count: count))
        )
    }
}
