import AppKit
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()
    private let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
    private var transcriptionPipeline: TranscriptionPipeline?

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchPanelController.show()
        if let replayFile = launchOptions.replayFile {
            let pipeline = TranscriptionPipeline(replayFile: replayFile, notch: notchPanelController)
            transcriptionPipeline = pipeline
            pipeline.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        transcriptionPipeline?.stop()
    }
}
