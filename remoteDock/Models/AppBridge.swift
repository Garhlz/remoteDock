import AppKit

@MainActor
final class AppBridge {
    static let shared = AppBridge()

    var openMainWindow: (() -> Void)?

    private init() {}
}
