import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 560)
        popover.contentViewController = NSHostingController(rootView: MenuBarHostsView())
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = menuBarIconImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        statusItem = item
    }

    private func removeStatusItem() {
        popover.performClose(nil)

        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func menuBarIconImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon = NSImage(
            systemSymbolName: "server.rack",
            accessibilityDescription: "RemoteDock"
        )?.withSymbolConfiguration(configuration)
        icon?.isTemplate = true
        return icon
    }
}
