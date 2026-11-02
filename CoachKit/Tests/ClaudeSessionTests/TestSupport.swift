import Foundation

/// Enregistre tout ce qu'émet un flux, pour l'inspecter pendant le test.
actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []

    func append(_ value: Value) {
        values.append(value)
    }
}

/// Consomme `stream` en arrière-plan ; la tâche renvoyée doit être annulée en fin de test.
func record<Value: Sendable>(_ stream: AsyncStream<Value>) -> (Recorder<Value>, Task<Void, Never>) {
    let recorder = Recorder<Value>()
    let task = Task {
        for await value in stream {
            await recorder.append(value)
        }
    }
    return (recorder, task)
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
        waiters = []
    }
}

/// Compte les appels, pour savoir combien de lancements ont commencé.
actor CallCounter {
    private(set) var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

/// Faux CLI `claude` : un script shell qui imite le protocole `stream-json` selon le contenu du prompt.
/// - `MEURS` : le process s'arrête.
/// - `ERREUR` : ligne `result` en échec, comme « Not logged in ».
/// - `LENT` : réponse normale, après 0,5 s.
/// - autre : réponse normale « Bonjour », précédée d'une ligne invalide.
/// Une demande d'interruption reçoit une `control_response`, sans autre effet.
enum FakeClaude {
    static let script = #"""
    #!/bin/sh
    answer() {
      echo '{"type":"system","subtype":"init","tools":[]}'
      echo 'ligne invalide'
      echo '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Bon"}}}'
      echo '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"jour"}}}'
      echo '{"type":"result","subtype":"success","is_error":false,"result":"Bonjour"}'
    }
    while IFS= read -r line; do
      case "$line" in
        *control_request*) echo '{"type":"control_response","response":{"subtype":"success"}}' ;;
        *MEURS*) exit 1 ;;
        *ERREUR*) echo '{"type":"result","subtype":"success","is_error":true,"result":"Not logged in"}' ;;
        *LENT*) sleep 0.5; answer ;;
        *) answer ;;
      esac
    done
    """#

    /// Script qui s'arrête dès son lancement.
    static let dyingScript = "#!/bin/sh\nexit 1\n"

    /// Écrit le script dans un fichier exécutable temporaire.
    static func install(_ contents: String = script) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "fake-claude-\(UUID().uuidString).sh")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}
