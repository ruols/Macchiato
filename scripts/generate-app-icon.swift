#!/usr/bin/env swift
import AppKit
import Foundation

// Original minimalist toolbox mark; no third-party image or font assets.
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Macchiato/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, Int)] = [
    ("AppIcon-16.png", 16), ("AppIcon-16@2x.png", 32),
    ("AppIcon-32.png", 32), ("AppIcon-32@2x.png", 64),
    ("AppIcon-128.png", 128), ("AppIcon-128@2x.png", 256),
    ("AppIcon-256.png", 256), ("AppIcon-256@2x.png", 512),
    ("AppIcon-512.png", 512), ("AppIcon-512@2x.png", 1024)
]

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
    defer {
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
    }
    let s = CGFloat(size)
    NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: s*0.012, y: s*0.012,
        width: s*0.976, height: s*0.976),
        xRadius: s*0.22, yRadius: s*0.22).fill()

    // White-outline toolbox: lid, handle and single clasp.
    NSColor.white.setStroke()
    let width = max(1.3, s*0.046)
    let handle = NSBezierPath(roundedRect: NSRect(x: s*0.37, y: s*0.59,
        width: s*0.26, height: s*0.17), xRadius: s*0.04, yRadius: s*0.04)
    handle.lineWidth = width
    handle.stroke()

    let body = NSBezierPath(roundedRect: NSRect(x: s*0.23, y: s*0.27,
        width: s*0.54, height: s*0.40), xRadius: s*0.07, yRadius: s*0.07)
    body.lineWidth = width
    body.stroke()

    let seam = NSBezierPath()
    seam.move(to: NSPoint(x: s*0.25, y: s*0.47))
    seam.line(to: NSPoint(x: s*0.75, y: s*0.47))
    seam.lineWidth = width * 0.78
    seam.stroke()

    NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: s*0.46, y: s*0.43,
        width: s*0.08, height: s*0.095), xRadius: s*0.014, yRadius: s*0.014).fill()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SmallToolsIcon", code: 2)
    }
    return png
}

try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, size) in sizes {
    try createPNG(size: size).write(to: directory.appendingPathComponent(name), options: .atomic)
}
print("Generated 小工具 icon assets.")
