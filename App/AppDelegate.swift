import AppKit
import NotchUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchPanelController = NotchPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchPanelController.show()
    }
}
