import Foundation

enum AerospaceConfig {
    /// Mirrors AeroSpace's own lookup order: XDG config dir, then ~/.aerospace.toml.
    static func locate() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            let candidate = URL(fileURLWithPath: xdg).appendingPathComponent("aerospace/aerospace.toml")
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        let xdgDefault = home.appendingPathComponent(".config/aerospace/aerospace.toml")
        if fm.fileExists(atPath: xdgDefault.path) { return xdgDefault }

        let dotfile = home.appendingPathComponent(".aerospace.toml")
        if fm.fileExists(atPath: dotfile.path) { return dotfile }

        return nil
    }

    static func loadBindings() -> [KeyBinding] {
        guard let url = locate(), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return TomlBindingParser.parse(text)
    }
}

/// A narrow parser: it understands just enough TOML to pull key/command bindings
/// out of `[mode.<name>.binding]` tables and ignores everything else in the file
/// (gaps, workspace assignments, on-window-detected rules, etc).
enum TomlBindingParser {
    static func parse(_ text: String) -> [KeyBinding] {
        var bindings: [KeyBinding] = []
        var currentMode: String? = nil

        let lines = text.components(separatedBy: .newlines)
        var i = 0
        let modeHeader = try! NSRegularExpression(pattern: #"^\[mode\.([A-Za-z0-9_-]+)\.binding\]\s*$"#)
        let otherHeader = try! NSRegularExpression(pattern: #"^\[+[^\]]"#)
        let keyValue = try! NSRegularExpression(pattern: #"^([A-Za-z0-9_+-]+)\s*=\s*(.+)$"#)

        while i < lines.count {
            let rawLine = lines[i]
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            defer { i += 1 }

            if line.isEmpty { continue }

            let full = NSRange(line.startIndex..<line.endIndex, in: line)

            if let m = modeHeader.firstMatch(in: line, range: full), let r = Range(m.range(at: 1), in: line) {
                currentMode = String(line[r])
                continue
            }
            if otherHeader.firstMatch(in: line, range: full) != nil {
                currentMode = nil
                continue
            }
            guard let mode = currentMode else { continue }
            guard let m = keyValue.firstMatch(in: line, range: full),
                  let keyRange = Range(m.range(at: 1), in: line),
                  let valueRange = Range(m.range(at: 2), in: line) else { continue }

            let key = String(line[keyRange])
            var valueText = String(line[valueRange])

            // Arrays may span multiple lines: keep consuming until brackets balance.
            if valueText.hasPrefix("[") {
                while balance(valueText) > 0, i + 1 < lines.count {
                    i += 1
                    valueText += " " + stripComment(lines[i])
                }
            }

            let commands = parseValue(valueText)
            if !commands.isEmpty {
                bindings.append(KeyBinding(mode: mode, rawKey: key, commands: commands))
            }
        }
        return bindings
    }

    private static func balance(_ s: String) -> Int {
        s.reduce(0) { $0 + ($1 == "[" ? 1 : ($1 == "]" ? -1 : 0)) }
    }

    /// Strips a trailing `# comment`, respecting single/double quotes.
    private static func stripComment(_ line: String) -> String {
        var inSingle = false
        var inDouble = false
        for (idx, ch) in line.enumerated() {
            if ch == "'" && !inDouble { inSingle.toggle() }
            else if ch == "\"" && !inSingle { inDouble.toggle() }
            else if ch == "#" && !inSingle && !inDouble {
                let i = line.index(line.startIndex, offsetBy: idx)
                return String(line[line.startIndex..<i])
            }
        }
        return line
    }

    /// Parses a TOML value that is either a quoted string or an array of quoted strings.
    private static func parseValue(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") {
            let inner = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return splitQuotedList(inner)
        }
        if let s = unquote(trimmed) { return [s] }
        return []
    }

    private static func splitQuotedList(_ text: String) -> [String] {
        var results: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        for ch in text {
            if ch == "'" && !inDouble {
                inSingle.toggle()
                current.append(ch)
            } else if ch == "\"" && !inSingle {
                inDouble.toggle()
                current.append(ch)
            } else if ch == "," && !inSingle && !inDouble {
                if let s = unquote(current.trimmingCharacters(in: .whitespaces)) { results.append(s) }
                current = ""
            } else {
                current.append(ch)
            }
        }
        if let s = unquote(current.trimmingCharacters(in: .whitespaces)) { results.append(s) }
        return results
    }

    private static func unquote(_ s: String) -> String? {
        guard s.count >= 2 else { return s.isEmpty ? nil : s }
        if (s.hasPrefix("'") && s.hasSuffix("'")) || (s.hasPrefix("\"") && s.hasSuffix("\"")) {
            return String(s.dropFirst().dropLast())
        }
        return s.isEmpty ? nil : s
    }
}
