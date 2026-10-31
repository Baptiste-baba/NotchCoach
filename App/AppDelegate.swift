import AppKit
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()

    #if DEBUG
    private(set) lazy var claudeDebugProbe = ClaudeDebugProbe(notch: notchPanelController)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchPanelController.show()
    }
}
