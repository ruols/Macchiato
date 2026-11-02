#!/usr/bin/env swift
import AppKit
import Foundation

// Original SmallTools app icon. Keep this source deterministic: CI regenerates
// the complete AppIcon.appiconset from the same vector geometry for every build.
// The menu-bar coffee icon (MacchiatoBase) is intentionally not changed.
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Macchiato/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, Int)] = [
    ("AppIcon-16.png", 16), ("AppIcon-16@2x.png", 32),
    ("AppIcon-32.png", 32), ("AppIcon-32@2x.png", 64),
    ("AppIcon-128.png", 128), ("AppIcon-128@2x.png", 256),
    ("AppIcon-256.png", 256), ("AppIcon-256@2x.png", 512),
    ("AppIcon-512.png", 512), ("AppIcon-512@2x.png", 1024)
]

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func createPNG(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SmallToolsIcon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    defer {
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
    }

    let s = CGFloat(size)
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }
    func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect(x, y, w, h), xRadius: r * s, yRadius: r * s)
    }
    func gradient(_ path: NSBezierPath, _ top: NSColor, _ bottom: NSColor) {
        NSGradient(starting: bottom, ending: top)?.draw(in: path, angle: 90)
    }
    func shadow(_ blur: CGFloat, _ offset: CGFloat, _ opacity: CGFloat) {
        let effect = NSShadow()
        effect.shadowColor = rgb(0, 10, 18, opacity)
        effect.shadowBlurRadius = blur * s
        effect.shadowOffset = NSSize(width: 0, height: -offset * s)
        effect.set()
    }

    // Navy-teal rounded background with a slight dimensional border.
    let bg = rounded(0.045, 0.045, 0.91, 0.91, 0.23)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.025, 0.018, 0.27)
    gradient(bg, rgb(33, 87, 101), rgb(7, 38, 51))
    NSGraphicsContext.restoreGraphicsState()

    let inset = rounded(0.062, 0.062, 0.876, 0.876, 0.22)
    inset.lineWidth = max(0.7, 0.009 * s)
    rgb(133, 206, 211, 0.22).setStroke()
    inset.stroke()

    // One strong white toolbox silhouette at all icon sizes.
    let white = rgb(247, 251, 251)
    let brightTeal = rgb(50, 163, 164)
    let darkTeal = rgb(13, 91, 101)

    // Raised handle behind the lid.
    let handle = rounded(0.347, 0.648, 0.306, 0.145, 0.078)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.017, 0.009, 0.37)
    white.setFill()
    handle.fill()
    NSGraphicsContext.restoreGraphicsState()

    let handleHole = rounded(0.402, 0.650, 0.196, 0.084, 0.038)
    rgb(10, 58, 69).setFill()
    handleHole.fill()

    // Toolbox base and inset body.
    let base = rounded(0.209, 0.245, 0.582, 0.371, 0.105)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.027, 0.018, 0.42)
    white.setFill()
    base.fill()
    NSGraphicsContext.restoreGraphicsState()

    let center = rounded(0.244, 0.278, 0.512, 0.296, 0.077)
    gradient(center, rgb(39, 145, 151), rgb(16, 89, 103))

    // Seam and top lid.
    let lid = rounded(0.195, 0.487, 0.61, 0.163, 0.084)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.018, 0.010, 0.30)
    white.setFill()
    lid.fill()
    NSGraphicsContext.restoreGraphicsState()

    let lidPanel = rounded(0.229, 0.518, 0.542, 0.100, 0.060)
    gradient(lidPanel, rgb(79, 188, 186), rgb(19, 115, 127))

    // Clean bright seam over the toolbox front.
    let seam = rounded(0.202, 0.480, 0.596, 0.034, 0.014)
    white.setFill()
    seam.fill()

    // Center latch.
    let latch = rounded(0.445, 0.464, 0.110, 0.124, 0.031)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.010, 0.007, 0.20)
    white.setFill()
    latch.fill()
    NSGraphicsContext.restoreGraphicsState()
    let latchInset = rounded(0.468, 0.491, 0.064, 0.071, 0.012)
    rgb(214, 225, 227).setFill()
    latchInset.fill()

    // Small heart symbolizes a personal, carefully made collection of tools.
    let heart = NSBezierPath()
    heart.move(to: NSPoint(x: s * 0.500, y: s * 0.316))
    heart.curve(to: NSPoint(x: s * 0.420, y: s * 0.389),
                controlPoint1: NSPoint(x: s * 0.462, y: s * 0.349),
                controlPoint2: NSPoint(x: s * 0.414, y: s * 0.365))
    heart.curve(to: NSPoint(x: s * 0.500, y: s * 0.420),
                controlPoint1: NSPoint(x: s * 0.416, y: s * 0.432),
                controlPoint2: NSPoint(x: s * 0.474, y: s * 0.444))
    heart.curve(to: NSPoint(x: s * 0.580, y: s * 0.389),
                controlPoint1: NSPoint(x: s * 0.526, y: s * 0.444),
                controlPoint2: NSPoint(x: s * 0.584, y: s * 0.432))
    heart.curve(to: NSPoint(x: s * 0.500, y: s * 0.316),
                controlPoint1: NSPoint(x: s * 0.586, y: s * 0.365),
                controlPoint2: NSPoint(x: s * 0.538, y: s * 0.349))
    heart.close()
    brightTeal.setFill()
    heart.fill()
    heart.lineJoinStyle = .round
    heart.lineWidth = max(1.2, 0.018 * s)
    white.setStroke()
    heart.stroke()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SmallToolsIcon", code: 2)
    }
    return png
}

try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, size) in sizes {
    try createPNG(size: size).write(to: directory.appendingPathComponent(name), options: .atomic)
}
print("Generated new SmallTools heart-toolbox app icon in \(sizes.count) sizes.")
