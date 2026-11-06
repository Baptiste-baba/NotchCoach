import Foundation
@testable import CallArchive

/// Dossier temporaire pour les tests, supprimé avec l'instance.
final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("CallArchiveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        try? FileManager.default.removeItem(at: url)
    }
}

/// Attend que `condition` devienne vraie, en la vérifiant régulièrement, au plus `timeout`.
func eventually(timeout: Duration = .seconds(5), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return await condition()
}

/// Barrière que le test ouvre quand il veut : tout ce qui l'attend reprend à ce moment-là.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Calendrier français, fuseau de Paris, semaines commençant le lundi : celui de l'utilisateur.
var paris: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    calendar.firstWeekday = 2
    return calendar
}

/// Date écrite en ISO 8601, avec son décalage : « 2026-11-06T16:20:00+01:00 ».
func date(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}

/// Call de vente de 14 minutes, avec deux répliques.
func makeCall(
    startDate: Date = date("2026-11-06T16:20:00+01:00"),
    duration: TimeInterval = 14 * 60,
    recapStatus: SavedCall.RecapStatus = .writing
) -> SavedCall {
    SavedCall(
        startDate: startDate,
        duration: duration,
        profile: SavedCall.Profile(name: "Vente", prompt: "Tu es un coach commercial.", playbook: "## Pricing\n49 € par mois"),
        transcript: [
            SavedCall.Line(speaker: .interlocutor, start: 16.2, text: "Le prix est trop élevé."),
            SavedCall.Line(speaker: .me, start: 47.9, text: "Vous le comparez à quoi ?"),
        ],
        recapStatus: recapStatus
    )
}

/// Compte rendu complet, avec un point à travailler cité à 00:47.
let sampleRecap = CallRecap(
    title: "Objection prix, Mme Martin",
    summary: CallRecap.Summary(overview: "Elle trouve l'offre trop chère.", keyPoints: ["Prix jugé trop élevé"], nextSteps: []),
    debrief: CallRecap.Debrief(
        strengths: ["Tu as creusé l'objection."],
        improvements: [
            CallRecap.Improvement(issue: "Remise trop tôt.", moment: 47, quote: "Vous le comparez à quoi ?", betterPhrasing: "Comparons les offres."),
        ]
    )
)
