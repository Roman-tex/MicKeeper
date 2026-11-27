import AppKit
import SwiftUI
import Observation
import MicKeeperCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let statusIcon = StatusIconView()
    private var shownRestorations = 0
    private let menu = NSMenu()
    private var isMenuTracking = false
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
            button.addSubview(statusIcon)
            NSLayoutConstraint.activate([
                statusIcon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                statusIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
        }
        shownRestorations = model.keeper.restorations
        menu.autoenablesItems = false
        updateAppearance()
        if !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
            Task { @MainActor [weak self] in self?.showMenu() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.model.restartMonitoring()
                    self?.model.updates.automatic.refresh()
                }
            })
        }
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.model.login.refresh() }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu.cancelTracking()
            isMenuTracking = false
            model.keeper.setEnabled(!model.keeper.isEnabled)
        } else if isMenuTracking {
            menu.cancelTracking()
            isMenuTracking = false
        } else {
            showMenu()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenu()
        return true
    }

    private func showMenu() {
        guard !isMenuTracking, let button = statusItem?.button else { return }
        rebuildMenu()
        isMenuTracking = true
        button.highlight(true)
        defer { isMenuTracking = false; button.highlight(false) }
        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY), in: button)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let holding = NSMenuItem(title: L10n.text("menu.holding.toggle"), action: #selector(toggleHolding), keyEquivalent: "")
        holding.target = self
        holding.state = model.keeper.isEnabled ? .on : .off
        menu.addItem(holding)

        let selectedKey = model.keeper.isEnabled ? "menu.selected" : "menu.selected.disabled"
        let selectedName = model.keeper.selectedName ?? L10n.text("menu.none")
        let selected = NSMenuItem(title: "\(L10n.text(selectedKey)) \(selectedName)", action: nil, keyEquivalent: "")
        selected.submenu = deviceMenu()
        selected.isEnabled = model.keeper.isEnabled && !model.keeper.devices.isEmpty
        menu.addItem(selected)

        if let issue = model.issueMessage {
            menu.addItem(.separator())
            menu.addItem(issueMenuItem(issue, retryAction: #selector(retryFromMenu)))
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: L10n.text("menu.login"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = model.login.isEnabled ? .on : .off
        login.isEnabled = !model.login.isBusy && !model.login.requiresApproval
        menu.addItem(login)
        if model.login.requiresApproval {
            let approval = NSMenuItem(title: L10n.text("menu.login.approval"), action: nil, keyEquivalent: "")
            approval.isEnabled = false
            menu.addItem(approval)
            let settings = NSMenuItem(title: L10n.text("menu.login.openSettings"), action: #selector(openLoginSettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
            let cancel = NSMenuItem(title: L10n.text("menu.login.cancel"), action: #selector(cancelLogin), keyEquivalent: "")
            cancel.target = self
            cancel.isEnabled = !model.login.isBusy
            menu.addItem(cancel)
        }
        if let error = model.login.errorMessage {
            menu.addItem(issueMenuItem(error))
        }

        menu.addItem(.separator())
        if case .available = model.updates.state {
            let update = NSMenuItem(title: L10n.text("menu.updateAvailable"), action: #selector(openAvailableUpdate), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        }
        let about = NSMenuItem(title: L10n.text("menu.about"), action: #selector(showAboutFromMenu), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: L10n.text("menu.quit"), action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)
    }

    private func issueMenuItem(_ message: String, retryAction: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text("menu.error"), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        item.toolTip = message
        let details = NSMenu()
        details.autoenablesItems = false

        // Only the explanatory text needs a view: keep the parent row and all
        // actions as standard menu items, and constrain long system messages.
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 280
        label.maximumNumberOfLines = 8
        label.cell?.truncatesLastVisibleLine = true
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 280),
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])
        content.setFrameSize(content.fittingSize)
        let description = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        description.view = content
        details.addItem(description)
        if let retryAction {
            details.addItem(.separator())
            let retry = NSMenuItem(title: L10n.text("menu.retry"), action: retryAction, keyEquivalent: "")
            retry.target = self
            details.addItem(retry)
        }
        item.submenu = details
        return item
    }

    private func deviceMenu() -> NSMenu {
        let deviceMenu = NSMenu()
        deviceMenu.autoenablesItems = false
        if model.keeper.devices.isEmpty {
            let empty = NSMenuItem(title: L10n.text("menu.none"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            deviceMenu.addItem(empty)
            return deviceMenu
        }
        for (index, device) in model.keeper.devices.enumerated() {
            let item = NSMenuItem(title: deviceLabel(device, index: index), action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.id
            item.state = device.id == model.keeper.selectedUID ? .on : .off
            item.isEnabled = model.keeper.isEnabled
            deviceMenu.addItem(item)
        }
        return deviceMenu
    }

    private func deviceLabel(_ device: AudioDevice, index: Int) -> String {
        let duplicates = model.keeper.devices.filter { $0.name == device.name }.count > 1
        return duplicates ? "\(device.name) · \(index + 1)" : device.name
    }

    @objc private func toggleHolding() {
        model.keeper.setEnabled(!model.keeper.isEnabled)
    }

    @objc private func retryFromMenu() {
        model.retry()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let device = model.keeper.devices.first(where: { $0.id == id }) else { return }
        model.keeper.select(device)
    }

    @objc private func toggleLogin() {
        let value = !model.login.isEnabled
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.model.login.setEnabled(value)
        }
    }

    @objc private func openLoginSettings() {
        model.login.openSettings()
    }

    @objc private func cancelLogin() {
        Task { @MainActor [weak self] in
            await self?.model.login.setEnabled(false)
        }
    }

    @objc private func showAboutFromMenu() {
        showAbout()
    }

    @objc private func openAvailableUpdate() {
        guard case .available(let url) = model.updates.state else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }

    private func updateAppearance() {
        withObservationTracking {
            let _ = model.language.selectedIdentifier
            let enabled = model.keeper.isEnabled
            let symbol = model.statusSymbol
            let restorations = model.keeper.restorations
            // A state change already animates; bounce only for a restore while holding.
            let wasHolding = statusIcon.symbol == .holding
            statusIcon.show(symbol)
            if restorations > shownRestorations, wasHolding { statusIcon.acknowledgeRestore() }
            shownRestorations = restorations
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
        menu.cancelTracking()
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
