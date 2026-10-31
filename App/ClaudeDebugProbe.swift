#if DEBUG
import ClaudeSession
import Foundation
import NotchUI

/// Outil de debug de l'étape 2 : envoie un prompt fixe à la session Claude et affiche la réponse dans la notch,
/// suivie du temps jusqu'au premier token.
final class ClaudeDebugProbe {
    private let notch: NotchPanelController
    private var session: ClaudeSession?
    private var nextRequestID = 1
    private var response = ""
    private var sentAt: ContinuousClock.Instant?
    private var timeToFirstToken: Duration?

    init(notch: NotchPanelController) {
        self.notch = notch
    }

    /// Lance la session au premier appel, puis envoie le prompt fixe.
    func run() {
        Task { await sendTestPrompt() }
    }

    private func sendTestPrompt() async {
        let session = self.session ?? makeSession()
        do {
            try await session.start()
        } catch {
            notch.display(.text("Lancement de Claude impossible : \(error.localizedDescription)"))
            return
        }
        response = ""
        timeToFirstToken = nil
        sentAt = .now
        notch.display(.text("…"))
        let request = LLMRequest(id: nextRequestID, prompt: Self.prompt(named: "claude-test-user"))
        nextRequestID += 1
        await session.send(request)
    }

    private func makeSession() -> ClaudeSession {
        let session = ClaudeSession(options: ClaudeSessionOptions(systemPrompt: Self.prompt(named: "claude-test-system")))
        self.session = session
        Task {
            for await event in session.events {
                handle(event)
            }
        }
        return session
    }

    private func handle(_ event: LLMEvent) {
        switch event {
        case .delta(_, let text):
            if timeToFirstToken == nil, let sentAt {
                timeToFirstToken = .now - sentAt
            }
            response += text
            notch.display(.text(response))
        case .finished:
            guard let timeToFirstToken else { return }
            let milliseconds = Int(timeToFirstToken / .milliseconds(1))
            notch.display(.text("\(response)\n\npremier token : \(milliseconds) ms"))
        }
    }

    private static func prompt(named name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
#endif
