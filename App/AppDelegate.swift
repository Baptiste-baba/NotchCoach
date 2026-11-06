import AppKit
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()
    private let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
    let profileController = ProfileController()
    private(set) lazy var callController = CallController(
        notch: notchPanelController,
        profiles: profileController,
        replayFile: launchOptions.replayFile
    )

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        profileController.reload()
        notchPanelController.show()
        // En mode replay, le call démarre tout de suite.
        if launchOptions.replayFile != nil {
            callController.startCall()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        callController.stopCall()
    }
}
