import AppKit
import Darwin
import Foundation

// Renders a 1024x1024 app icon (purple/indigo squircle + white hammer symbol).
// Usage: swift scripts/make-icon.swift <output.png>

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(1)
}
let outputURL = URL(fileURLWithPath: arguments[1])

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()

let inset: CGFloat = 58
let backgroundRect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let squircle = NSBezierPath(roundedRect: backgroundRect, xRadius: 224, yRadius: 224)
squircle.addClip()

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.52, green: 0.44, blue: 1.0, alpha: 1),
    NSColor(srgbRed: 0.27, green: 0.21, blue: 0.78, alpha: 1),
    NSColor(srgbRed: 0.13, green: 0.10, blue: 0.42, alpha: 1)
])
gradient?.draw(in: backgroundRect, angle: -62)

// Soft highlight in the upper left.
let glow = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.30),
    NSColor.white.withAlphaComponent(0.0)
])
glow?.draw(
    in: NSBezierPath(ovalIn: NSRect(x: 110, y: 430, width: 780, height: 780)),
    relativeCenterPosition: NSPoint(x: -0.15, y: 0.1)
)

// Inner rim.
NSColor.white.withAlphaComponent(0.18).setStroke()
let rim = NSBezierPath(
    roundedRect: backgroundRect.insetBy(dx: 2, dy: 2),
    xRadius: 222,
    yRadius: 222
)
rim.lineWidth = 3.5
rim.stroke()

// Hammer glyph.
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 460, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

if let symbol = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let natural = symbol.size
    let maxSide: CGFloat = 430
    let scale = min(maxSide / natural.width, maxSide / natural.height)
    let drawSize = NSSize(width: natural.width * scale, height: natural.height * scale)
    let target = NSRect(
        x: (side - drawSize.width) / 2,
        y: (side - drawSize.height) / 2 - 6,
        width: drawSize.width,
        height: drawSize.height
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()

    symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)

    NSShadow().set()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}

do {
    try png.write(to: outputURL)
} catch {
    FileHandle.standardError.write(Data("failed to write icon: \(error)\n".utf8))
    exit(1)
}
