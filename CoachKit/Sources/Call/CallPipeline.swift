import AudioCapture
import Conversation
import Prompting
import Transcription

/// Relie, pendant un call, la source audio, la transcription des deux canaux, la conversation, le playbook et la
/// session Claude, et publie ce que la notch affiche. Un pipeline ne sert qu'à un call.
public actor CallPipeline {
    /// Ce que la notch doit afficher, du démarrage à la fin du call. Un seul consommateur. Le flux se termine avec
    /// le call.
    public nonisolated let displays: AsyncStream<CoachDisplay>

    private let displaysContinuation: AsyncStream<CoachDisplay>.Continuation
    private let source: any AudioSource
    private let models: ParakeetModels
    private let playbookFile: PlaybookFile
    private let coachInstructions: String

    /// `models` peut servir d'un call à l'autre : seul le premier les charge. `coachInstructions` : consignes du coach,
    /// avec l'emplacement du playbook.
    public init(source: any AudioSource, models: ParakeetModels, playbookFile: PlaybookFile, coachInstructions: String) {
        (displays, displaysContinuation) = AsyncStream.makeStream()
        self.source = source
        self.models = models
        self.playbookFile = playbookFile
        self.coachInstructions = coachInstructions
    }

    /// Déroule le call : lit le playbook, prépare les modèles et lance Claude, puis transcrit la source et suggère
    /// des réponses. Revient à la fin du call : source terminée et dernière suggestion repliée, appel à `stop()`, ou
    /// démarrage impossible.
    public func run() async {
        fatalError("TODO")
    }

    /// Arrête le call tout de suite : la source, la conversation et Claude.
    public func stop() async {
        fatalError("TODO")
    }
}
