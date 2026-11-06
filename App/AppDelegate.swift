import AppKit
import CallArchive
import CallsUI
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()
    private let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
    let profileController = ProfileController()
    /// Calls enregistrés : leur compte rendu s'écrit en arrière-plan, même après la fin du call.
    let callArchive: CallArchive = {
        let generator = CallRecapGenerator(instructions: BundledPrompt.text(named: "call-recap"))
        return CallArchive { try await generator.recap(of: $0) }
    }()
    private(set) lazy var callLibrary = CallLibrary(archive: callArchive)
    private(set) lazy var callController = CallController(
        notch: notchPanelController,
        profiles: profileController,
        archive: callArchive,
        replayFile: launchOptions.replayFile
    )

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        profileController.reload()
        Task { await callArchive.start() }
        callLibrary.start()
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
