import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let settings: RemoteSettings
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(model: AppModel, settings: RemoteSettings) {
        self.model = model
        self.settings = settings
    }

    /// Opens the window on `page`, or on the page it last showed when nil.
    func show(_ page: SettingsPage?) {
        if let page { navigation.page = page }
        let window = self.window ?? makeWindow()
        self.window = window
        // Closing only hides the window, so pages do not see onAppear again;
        // resume the live feeds for whichever page is showing.
        model.liveInput.isObserving = navigation.page == .status
        model.pressHighlight.isActive = navigation.page == .mapping && settings.highlightPressedButton
        // Show in the Dock and app switcher while the window is open. The
        // policy change lands asynchronously, and an activation requested
        // before it does is ignored, leaving the window behind other apps.
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        model.refreshPermissions()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsView.size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Joy-Con Vibe Remote"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(model: model, settings: settings, navigation: navigation)
        )
        window.delegate = self
        window.center()
        // Reopen where the user last left it.
        window.setFrameAutosaveName("SettingsWindow")
        return window
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refreshPermissions()
    }

    func windowWillClose(_ notification: Notification) {
        model.liveInput.isObserving = false
        model.pressHighlight.isActive = false
        NSApp.setActivationPolicy(.accessory)
    }
}
