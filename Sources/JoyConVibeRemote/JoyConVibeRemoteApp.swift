import AppKit
import Combine
import SwiftUI

// A plain AppKit entry point. A SwiftUI App needs at least one scene, and
// its placeholder Settings scene would open as an empty window whenever the
// app became a regular app or received a reopen event.
@main
enum JoyConVibeRemoteMain {
    @MainActor private static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var settings: RemoteSettings?
    private var model: AppModel?
    private var settingsWindow: SettingsWindowController?
    private var statusCancellable: AnyCancellable?
    private var shownStatusTitle: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.mainMenu = makeMainMenu()

        let settings = RemoteSettings()
        let model = AppModel(settings: settings)
        self.settings = settings
        self.model = model

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(
            width: StatusMenuView.panelWidth,
            height: StatusMenuView.initialHeight
        )
        let hostingController = NSHostingController(
            rootView: StatusMenuView(
                model: model,
                settings: settings,
                onPreferredHeightChange: { [weak self] height in
                    self?.updatePopoverHeight(height)
                }
            )
        )
        popover.contentViewController = hostingController
        hostingController.view.frame = NSRect(
            origin: .zero,
            size: popover.contentSize
        )
        // Build the SwiftUI hierarchy during app launch so clicking the menu
        // bar icon only has to position an already-laid-out panel.
        hostingController.view.layoutSubtreeIfNeeded()

        model.onShowStatus = { [weak self] in
            self?.showPopover()
        }
        let settingsWindow = SettingsWindowController(model: model, settings: settings)
        self.settingsWindow = settingsWindow
        model.onOpenSettings = { [weak self] page in
            self?.showSettings(page)
        }
        statusCancellable = model.$status.sink { [weak self] status in
            self?.updateStatusItem(for: status)
        }

        model.start()
        if !model.accessibilityTrusted {
            // The status page lists every missing permission with a button
            // for each, which guides a first launch better than the popover.
            showSettings(.status)
        }
    }

    /// The menu bar shown while the settings window makes this a regular app.
    private func makeMainMenu() -> NSMenu {
        let appName = "Joy-Con Vibe Remote"
        let appMenu = NSMenu(title: appName)
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "隐藏 \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.windowsMenu = windowMenu
        return mainMenu
    }

    @objc private func openSettingsFromMenu() {
        showSettings(nil)
    }

    func showSettings(_ page: SettingsPage?) {
        popover.performClose(nil)
        settingsWindow?.show(page)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Clicking the Dock icon while the window is open brings it forward.
        showSettings(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // Permission probing is not required to present the panel. Refresh it
        // on the next run-loop turn so the click responds immediately.
        DispatchQueue.main.async { [weak model] in
            model?.refreshPermissions()
        }
    }

    private func updatePopoverHeight(_ height: CGFloat) {
        let preferredSize = NSSize(width: StatusMenuView.panelWidth, height: height)
        guard abs(popover.contentSize.height - height) > 0.5 else { return }
        popover.contentSize = preferredSize
        popover.contentViewController?.preferredContentSize = preferredSize
    }

    private func updateStatusItem(for status: RemoteStatus) {
        // Calibration progress changes on every report but keeps one icon.
        guard status.title != shownStatusTitle else { return }
        shownStatusTitle = status.title
        let image = NSImage(
            systemSymbolName: status.symbolName,
            accessibilityDescription: status.title
        )
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = "Joy-Con Vibe Remote · \(status.title)"
    }
}
