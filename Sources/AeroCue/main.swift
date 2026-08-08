import Cocoa
import SwiftUI

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// Renders the cheat sheet offscreen to a PNG so layout can be verified without
// triggering the real overlay.
// Usage: --render-test <width> <height> <out.png> [config-path-label]
// The optional label replaces the real config path in the header, so
// screenshots for docs don't bake in a home directory.
if let i = CommandLine.arguments.firstIndex(of: "--render-test") {
    let args = CommandLine.arguments
    let w = Double(args[safe: i + 1] ?? "") ?? 1600
    let h = Double(args[safe: i + 2] ?? "") ?? 1000
    let out = args[safe: i + 3] ?? "/tmp/aerocue-render.png"
    let label = args[safe: i + 4]

    let bindings = AerospaceConfig.loadBindings()
    let modes = CheatSheetBuilder.build(from: bindings)
    let size = CGSize(width: w, height: h)
    let view = CheatSheetView(modes: modes, configPath: label ?? AerospaceConfig.locate()?.path, size: size)

    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.layoutSubtreeIfNeeded()

    print("hosting.frame=\(hosting.frame) fittingSize=\(hosting.fittingSize)")

    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        print("ERROR: could not create bitmap rep")
        exit(1)
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: could not encode PNG")
        exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: out))
    print("wrote \(out) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
    exit(0)
}

// Toggle the login item without going through the menu (handy for scripting).
if CommandLine.arguments.contains("--enable-login-item")
    || CommandLine.arguments.contains("--disable-login-item") {
    let enable = CommandLine.arguments.contains("--enable-login-item")
    LaunchAtLogin.set(enable)
    print("launch at login: \(LaunchAtLogin.isEnabled ? "enabled" : "disabled")")
    exit(LaunchAtLogin.isEnabled == enable ? 0 : 1)
}

if CommandLine.arguments.contains("--check-trust") {
    print("AXIsProcessTrusted: \(AXIsProcessTrusted())")
    exit(0)
}

if CommandLine.arguments.contains("--dump-bindings") {
    let bindings = AerospaceConfig.loadBindings()
    if let path = AerospaceConfig.locate() {
        print("Config: \(path.path)")
    } else {
        print("No aerospace.toml found")
    }
    for mode in CheatSheetBuilder.build(from: bindings) {
        print("\n[mode.\(mode.name)]")
        for category in mode.categories {
            print("  \(category.name):")
            for b in category.bindings {
                let combo = (b.combo.modifierSymbols + [b.combo.keySymbol]).joined()
                print("    \(b.rawKey.padding(toLength: 24, withPad: " ", startingAt: 0)) \(combo.padding(toLength: 12, withPad: " ", startingAt: 0)) \(b.actionDescription)")
            }
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
