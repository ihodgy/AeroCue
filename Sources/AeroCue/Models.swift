import Foundation

/// One key -> command(s) binding, scoped to an AeroSpace mode (e.g. "main", "service").
struct KeyBinding: Identifiable, Hashable {
    let id = UUID()
    let mode: String
    let rawKey: String
    let commands: [String]

    var category: String { Categorizer.category(for: commands) }
    var combo: KeyCombo { KeyCombo(raw: rawKey) }
    var actionDescription: String {
        commands.map(Categorizer.humanize).joined(separator: "  →  ")
    }
}

/// A parsed key combo, split into ordered modifier symbols + the main key symbol.
struct KeyCombo: Hashable {
    let modifierSymbols: [String]
    let keySymbol: String

    init(raw: String) {
        let parts = raw.split(separator: "-").map(String.init)
        guard !parts.isEmpty else {
            modifierSymbols = []
            keySymbol = raw
            return
        }
        let mainKey = parts.last!
        let mods = parts.dropLast().map { $0.lowercased() }

        // Canonical Apple modifier order: control, option, shift, command.
        let order = ["ctrl", "alt", "shift", "cmd"]
        let modSymbols: [String: String] = [
            "ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘",
        ]
        modifierSymbols = order.filter { mods.contains($0) }.compactMap { modSymbols[$0] }
        keySymbol = KeyCombo.symbol(forKeyName: mainKey)
    }

    private static let namedSymbols: [String: String] = [
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "leftsquarebracket": "[", "rightsquarebracket": "]",
        "minus": "−", "equal": "=", "semicolon": ";", "quote": "'",
        "backslash": "\\", "comma": ",", "period": ".", "slash": "/",
        "grave": "`", "space": "Space", "enter": "⏎", "tab": "⇥",
        "backspace": "⌫", "esc": "⎋", "escape": "⎋", "capslock": "⇪",
        "delete": "⌦", "forwarddelete": "⌦",
        "home": "↖", "end": "↘", "pageup": "⇞", "pagedown": "⇟",
    ]

    static func symbol(forKeyName name: String) -> String {
        let lower = name.lowercased()
        if let sym = namedSymbols[lower] { return sym }
        if lower.hasPrefix("f"), let n = Int(lower.dropFirst()), n >= 1, n <= 20 {
            return "F\(n)"
        }
        if lower.hasPrefix("keypad") {
            return "Keypad " + humanizeCamel(String(name.dropFirst(6)))
        }
        if name.count == 1 { return name.uppercased() }
        return humanizeCamel(name)
    }

    private static func humanizeCamel(_ s: String) -> String {
        guard !s.isEmpty else { return s }
        var result = ""
        for (i, ch) in s.enumerated() {
            if ch.isUppercase && i != 0 { result.append(" ") }
            result.append(ch)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}

enum Categorizer {
    static func category(for commands: [String]) -> String {
        guard let first = commands.first else { return "Other" }
        let verb = first.split(separator: " ").first.map(String.init) ?? first
        switch verb {
        case "focus", "focus-monitor":
            return "Focus"
        case "move":
            return "Move Window"
        case "workspace", "workspace-back-and-forth":
            return "Workspaces"
        // Kept separate from "Workspaces": with 10 workspaces these two groups
        // are ~10 rows each, and one 20-row card unbalances the whole layout.
        case "move-node-to-workspace", "move-workspace-to-monitor", "move-node-to-monitor":
            return "Send to Workspace"
        case "resize":
            return "Resize"
        case "layout", "fullscreen", "join-with":
            return "Layout"
        case "mode":
            return "Modes"
        case "exec-and-forget", "exec":
            return "Launch Apps"
        default:
            return "Other"
        }
    }

    static func humanize(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        guard let verb = parts.first else { return command }
        let rest = parts.count > 1 ? parts[1] : ""
        let niceVerb = verb.replacingOccurrences(of: "-", with: " ")
        return rest.isEmpty ? niceVerb : "\(niceVerb) \(rest)"
    }
}
