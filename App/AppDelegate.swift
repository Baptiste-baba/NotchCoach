import AppKit
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()
    private let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
    private var callPipeline: CallPipeline?

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchPanelController.show()
        if let replayFile = launchOptions.replayFile {
            let pipeline = CallPipeline(replayFile: replayFile, notch: notchPanelController)
            callPipeline = pipeline
            pipeline.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        callPipeline?.stop()
    }
}
