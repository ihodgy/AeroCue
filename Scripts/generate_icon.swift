// One-off icon generator: draws a rounded dark square with a large "⌥" glyph
// and rasterizes it into an .iconset, then compiles that into AppIcon.icns.
// Run with: swift Scripts/generate_icon.swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let fm = FileManager.default
let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? fm.removeItem(at: iconsetURL)
try! fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func draw(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = CGFloat(size) * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)

    let glyph = "⌥"
    let fontSize = CGFloat(size) * 0.62
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: style,
    ]
    let str = NSAttributedString(string: glyph, attributes: attrs)
    let strSize = str.size()
    let origin = NSPoint(x: (CGFloat(size) - strSize.width) / 2, y: (CGFloat(size) - strSize.height) / 2 - CGFloat(size) * 0.02)
    str.draw(at: origin)

    image.unlockFocus()
    return image
}

func write(_ image: NSImage, to url: URL) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

for size in sizes {
    let img1x = draw(size: size)
    write(img1x, to: iconsetURL.appendingPathComponent("icon_\(size)x\(size).png"))
    if size <= 512 {
        let img2x = draw(size: size * 2)
        write(img2x, to: iconsetURL.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}

print("Wrote iconset to \(iconsetURL.path)")
