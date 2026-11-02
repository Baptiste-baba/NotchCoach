// Génère `call-objection-prix.wav`, un faux call commercial pour le mode replay, avec les voix françaises
// de macOS : canal gauche = moi, canal droit = prospect, 16 kHz.
//
// Usage, depuis la racine du repo : swift Fixtures/generate-call-objection-prix.swift

import AVFoundation
import Foundation

enum Voice: String {
    case me = "Jacques"
    case prospect = "Flo (Français (France))"
}

let dialogue: [(Voice, String)] = [
    (.me, "Bonjour Madame Martin, merci d'avoir pris le temps pour cet appel."),
    (.prospect, "Bonjour. Oui, j'ai lu votre proposition hier soir."),
    (.me, "Parfait. Qu'est-ce que vous en avez pensé ?"),
    (.prospect, "La solution nous intéresse, mais honnêtement, le prix est beaucoup trop élevé pour nous."),
    (.me, "Je comprends. Vous le comparez à quoi, exactement ?"),
    (.prospect, "Un concurrent nous propose à peu près la même chose pour presque moitié moins cher."),
    (.me, "D'accord. Est-ce que leur offre inclut l'accompagnement et la formation de vos équipes ?"),
    (.prospect, "Je ne crois pas, non. Mais de toute façon, on n'a pas de budget avant le prochain trimestre."),
    (.me, "Très bien. Si on trouvait une façon d'étaler le paiement, est-ce que ça changerait les choses pour vous ?"),
    (.prospect, "Peut-être. Il faudrait que j'en parle à mon directeur financier avant de m'engager."),
]

let sampleRate = 16_000.0
/// Silence entre deux prises de parole : plus long que celui qu'attend le VAD pour déclarer une phrase finie.
let pauseBetweenTurns = 1.6
let output = URL(fileURLWithPath: "Fixtures/call-objection-prix.wav")

func silence(seconds: Double) -> [Float] {
    [Float](repeating: 0, count: Int(seconds * sampleRate))
}

/// Fait dire `text` par `voice` et renvoie l'audio en 16 kHz mono Float32.
func speak(_ text: String, voice: Voice, in directory: URL) throws -> [Float] {
    let file = directory.appendingPathComponent(UUID().uuidString + ".caf")
    let say = Process()
    say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    say.arguments = ["-v", voice.rawValue, "--data-format=LEF32@16000", "-o", file.path, text]
    try say.run()
    say.waitUntilExit()
    guard say.terminationStatus == 0 else {
        throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "say a échoué pour la voix \(voice.rawValue)"])
    }
    let audio = try AVAudioFile(forReading: file)
    let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length))!
    try audio.read(into: buffer)
    return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
}

let workDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: workDirectory) }

var left = silence(seconds: 1)
var right = silence(seconds: 1)
for (voice, text) in dialogue {
    let speech = try speak(text, voice: voice, in: workDirectory)
    let quiet = [Float](repeating: 0, count: speech.count)
    left += voice == .me ? speech : quiet
    right += voice == .prospect ? speech : quiet
    left += silence(seconds: pauseBetweenTurns)
    right += silence(seconds: pauseBetweenTurns)
}

/// Écrit le WAV stéréo 16 bits. Dans une fonction : le fichier est refermé à la sortie, ce qui finalise l'en-tête
/// (une variable globale d'un script n'est jamais libérée).
func writeStereo(left: [Float], right: [Float], to url: URL) throws {
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]
    let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(left.count))!
    buffer.frameLength = AVAudioFrameCount(left.count)
    left.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: left.count) }
    right.withUnsafeBufferPointer { buffer.floatChannelData![1].update(from: $0.baseAddress!, count: right.count) }
    try file.write(from: buffer)
}

try writeStereo(left: left, right: right, to: output)

print("\(output.path) : \(String(format: "%.1f", Double(left.count) / sampleRate)) s, \(dialogue.count) prises de parole")
