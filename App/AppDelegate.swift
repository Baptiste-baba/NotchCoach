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
        fatalError("TODO")
    }
}
