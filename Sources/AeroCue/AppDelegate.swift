import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let keyMonitor = KeyMonitor()
    private let cheatSheet = CheatSheetController()
    private var permissionPollTimer: Timer?

    private let holdDurationKey = "holdDuration"
    private let durationOptions: [TimeInterval] = [2, 3, 5, 8]

    private var holdDuration: TimeInterval {
        get {
            let v = UserDefaults.standard.double(forKey: holdDurationKey)
            return v > 0 ? v : 5.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: holdDurationKey)
            keyMonitor.holdDuration = newValue
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only apps have no window to signal "still in use," so AppKit's
        // automatic-termination heuristic suspends them a few seconds after launch
        // and their status item disappears. Opt out explicitly.
        ProcessInfo.processInfo.disableAutomaticTermination("AeroCue is a menu bar utility with no windows")
        ProcessInfo.processInfo.disableSuddenTermination()

        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()

        keyMonitor.holdDuration = holdDuration
        keyMonitor.onTrigger = { [weak self] in self?.cheatSheet.show() }
        keyMonitor.onDismiss = { [weak self] in self?.cheatSheet.hide() }

        ensureAccessibilityThenStart()
    }

    private func ensureAccessibilityThenStart() {
        if AccessibilityPermission.isTrusted {
            keyMonitor.start()
            refreshStatusIcon()
            return
        }
        // Deliberately no system prompt here. AXIsProcessTrusted() keeps
        // returning false for the rest of this process's life even after the
        // grant lands, so prompting on every launch produces a grant-relaunch-
        // grant loop. The menu bar shows a ⚠️ with an explicit
        // "Open Accessibility Settings…" action instead, on the user's terms.
        refreshStatusIcon()

        // Still poll, in case the answer does flip (it does on some systems).
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            guard AccessibilityPermission.isTrusted else { return }
            timer.invalidate()
            self.permissionPollTimer = nil
            self.keyMonitor.start()
            self.refreshStatusIcon()
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        refreshStatusIcon()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Losing Accessibility access is otherwise invisible -- the hold just stops
    /// working -- so surface it right in the menu bar icon. Rebuilding the app
    /// changes its ad-hoc code signature, which revokes the grant every time.
    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        let trusted = AccessibilityPermission.isTrusted
        let symbol = trusted ? "option" : "exclamationmark.triangle.fill"
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "AeroCue") {
            img.isTemplate = true
            button.image = img
            button.title = ""
        } else {
            button.image = nil
            button.title = trusted ? "⌥" : "⚠"
        }
        button.toolTip = trusted
            ? "AeroCue -- hold ⌥ to show AeroSpace shortcuts"
            : "AeroCue needs Accessibility access to detect the ⌥ hold"
    }

    /// Rebuilt on every open so the permission warning and the checkmarks
    /// always reflect current state.
    private func populateMenu() {
        menu.removeAllItems()

        if !AccessibilityPermission.isTrusted {
            let warn = NSMenuItem(title: "⚠️  Accessibility access needed", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)

            let openSettings = NSMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            openSettings.target = self
            menu.addItem(openSettings)

            let relaunch = NSMenuItem(
                title: "Relaunch AeroCue (after granting)",
                action: #selector(relaunch),
                keyEquivalent: ""
            )
            relaunch.target = self
            menu.addItem(relaunch)

            menu.addItem(.separator())
        }

        let showNow = NSMenuItem(title: "Show Shortcuts Now", action: #selector(showNow), keyEquivalent: "")
        showNow.target = self
        menu.addItem(showNow)

        menu.addItem(.separator())

        let durationItem = NSMenuItem(title: "Hold Duration", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu()
        for seconds in durationOptions {
            let item = NSMenuItem(title: "\(Int(seconds)) seconds", action: #selector(setDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = (seconds == holdDuration) ? .on : .off
            durationMenu.addItem(item)
        }
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let revealItem = NSMenuItem(title: "Reveal aerospace.toml", action: #selector(revealConfig), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AeroCue", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func showNow() {
        cheatSheet.show()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// A process that has already been told "not trusted" can keep getting that
    /// answer even after the user grants access, so offer a clean restart.
    @objc private func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    @objc private func setDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        holdDuration = seconds
        populateMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        populateMenu()
    }

    @objc private func revealConfig() {
        guard let url = AerospaceConfig.locate() else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        populateMenu()
        refreshStatusIcon()
    }
}
