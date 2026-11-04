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
            show("Lancement de Claude impossible : \(error.localizedDescription)")
            return
        }
        response = ""
        timeToFirstToken = nil
        sentAt = .now
        show("…")
        let request = LLMRequest(id: nextRequestID, prompt: BundledPrompt.text(named: "claude-test-user"))
        nextRequestID += 1
        await session.send(request)
    }

    private func makeSession() -> ClaudeSession {
        let session = ClaudeSession(options: ClaudeSessionOptions(systemPrompt: BundledPrompt.text(named: "claude-test-system")))
        self.session = session
        Task {
            for await event in session.events {
                handle(event)
            }
        }
        Task {
            for await state in session.states {
                handle(state)
            }
        }
        return session
    }

    private func handle(_ state: SessionState) {
        switch state {
        case .restarting(let attempt):
            show("Claude s'est arrêté, redémarrage (tentative \(attempt))…")
        case .failed(let message):
            show(message)
        case .running, .stopped:
            break
        }
    }

    private func handle(_ event: LLMEvent) {
        switch event {
        case .delta(_, let text):
            if timeToFirstToken == nil, let sentAt {
                timeToFirstToken = .now - sentAt
            }
            response += text
            show(response)
        case .finished:
            guard let timeToFirstToken else { return }
            let milliseconds = Int(timeToFirstToken / .milliseconds(1))
            show("\(response)\n\npremier token : \(milliseconds) ms")
        case .failed(_, let message):
            show("Échec : \(message)")
        }
    }

    /// Montre une ligne dans la notch dépliée.
    private func show(_ text: String) {
        notch.display(NotchContent(lines: [NotchContent.Line(id: 0, text: text)]))
    }
}
#endif
