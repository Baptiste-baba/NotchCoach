import AppKit
import NotchUI
import Prompting

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()
    private let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
    private let playbookFile = PlaybookFile(template: BundledPrompt.text(named: "playbook-template"))
    private var callPipeline: CallPipeline?

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchPanelController.show()
        if let replayFile = launchOptions.replayFile {
            let pipeline = CallPipeline(replayFile: replayFile, playbookFile: playbookFile, notch: notchPanelController)
            callPipeline = pipeline
            pipeline.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        callPipeline?.stop()
    }

    /// Ouvre le playbook dans l'éditeur par défaut, après l'avoir créé s'il n'existe pas encore.
    func editPlaybook() {
        do {
            try playbookFile.createIfMissing()
        } catch {
            showAlert(for: error)
            return
        }
        // Sans éditeur pour les fichiers Markdown, le fichier est montré dans le Finder.
        if !NSWorkspace.shared.open(playbookFile.url) {
            NSWorkspace.shared.activateFileViewerSelecting([playbookFile.url])
        }
    }

    private func showAlert(for error: PromptingError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Impossible d'ouvrir le playbook"
        alert.informativeText = "\(error.localizedDescription)\n\n\(playbookFile.url.path)"
        // L'app n'a pas de fenêtre : sans ça, l'alerte resterait derrière celle de l'app active.
        NSApp.activate()
        alert.runModal()
    }
}
