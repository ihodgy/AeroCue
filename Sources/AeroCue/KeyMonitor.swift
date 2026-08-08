import Cocoa

/// Watches global keyboard flags for a solo, sustained hold of the Option key.
/// Fires `onTrigger` after `holdDuration` seconds of Option held alone, and
/// `onDismiss` on any of the standard ways to close an open cheat sheet
/// (Option released, Esc, or a click outside it) -- independent of whether
/// the sheet was actually opened via a hold, since it may have been opened
/// manually from the status menu instead.
final class KeyMonitor {
    var holdDuration: TimeInterval = 5.0
    var onTrigger: (() -> Void)?
    var onDismiss: (() -> Void)?

    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var timer: Timer?
    private var optionHeldAlone = false

    func start() {
        stop()

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.onDismiss?()
        }
    }

    func stop() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        flagsMonitor = nil
        keyMonitor = nil
        mouseMonitor = nil
        timer?.invalidate()
        timer = nil
        optionHeldAlone = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isOptionOnly = flags == .option

        if isOptionOnly && !optionHeldAlone {
            optionHeldAlone = true
            armTimer()
        } else if !isOptionOnly && optionHeldAlone {
            optionHeldAlone = false
            timer?.invalidate()
            timer = nil
            onDismiss?()
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // kVK_Escape -- always closes an open sheet.
            onDismiss?()
        }
        guard optionHeldAlone else { return }
        // Any other keypress while holding Option means they're firing an actual
        // shortcut, not asking for help -- stop the pending "help me" timer, but
        // leave an already-visible sheet up (Esc/release/click still close it).
        optionHeldAlone = false
        timer?.invalidate()
        timer = nil
    }

    private func armTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.onTrigger?()
        }
    }
}

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's own "AeroCue would like to control this computer" prompt.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
