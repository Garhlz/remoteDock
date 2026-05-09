import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyMenuBarVisibility()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.applyMenuBarVisibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private func applyMenuBarVisibility() {
        let isVisible = UserDefaults.standard.object(forKey: AppSettings.showMenuBarIconKey) as? Bool
            ?? AppSettings.defaultShowMenuBarIcon
        statusBarController.setVisible(isVisible)
    }
}
