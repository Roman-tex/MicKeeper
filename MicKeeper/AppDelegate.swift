import AppKit
import SwiftUI
import Observation

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var aboutWindow: NSWindowController?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var activationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self; button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(L10n.text("app.accessibility"))
        }
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: KeeperPanel(model: model, showAbout: { [weak self] in self?.showAbout() }))
        updateAppearance()
        if !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
            showPanel()
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.model.restartMonitoring() }
            })
        }
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.model.login.refresh() }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            model.keeper.setEnabled(!model.keeper.isEnabled)
        } else if popover.isShown {
            popover.performClose(sender)
        } else {
            showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    private func showPanel() {
        guard let button = statusItem?.button else { return }
        model.refreshForPresentation()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateAppearance() {
        withObservationTracking {
            let _ = model.language.selectedIdentifier
            let enabled = model.keeper.isEnabled
            let image = NSImage(named: enabled ? "MicrophoneOn" : "MicrophoneOff")?.copy() as? NSImage
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = image
            let state = L10n.text(enabled ? "app.state.enabled" : "app.state.disabled")
            let device = model.keeper.selectedName ?? L10n.text("app.device.none")
            let detail = model.issueMessage ?? L10n.text("app.tooltip.rightClick")
            statusItem.button?.toolTip = L10n.format("app.tooltip", state, device, detail)
            statusItem.button?.setAccessibilityValue(L10n.format("app.accessibility.value", state))
            aboutWindow?.window?.title = L10n.text("app.about.title")
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.updateAppearance() }
        }
    }

    private func showAbout() {
        popover.performClose(nil)
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView(updates: model.updates, language: model.language))
            let window = NSWindow(contentViewController: hosting)
            window.title = L10n.text("app.about.title")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            aboutWindow = NSWindowController(window: window)
        }
        NSApp.activate()
        aboutWindow?.showWindow(nil)
        aboutWindow?.window?.center()
        aboutWindow?.window?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
