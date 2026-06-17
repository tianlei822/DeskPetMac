#!/usr/bin/env swift
import AppKit
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resourcesURL = root.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let bitmap = drawIcon(pixels: variant.pixels)
    let outputURL = iconsetURL.appendingPathComponent(variant.name)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: outputURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    fputs("iconutil failed with status \(iconutil.terminationStatus)\n", stderr)
    exit(iconutil.terminationStatus)
}

print(icnsURL.path)

private func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let side = CGFloat(pixels)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create icon bitmap")
    }
    bitmap.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()

    let tile = NSRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: side * 0.20, yRadius: side * 0.20)
    tilePath.addClip()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.97, green: 0.72, blue: 0.78, alpha: 1),
        NSColor(calibratedRed: 0.67, green: 0.54, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.88, alpha: 1)
    ])?.draw(in: tilePath, angle: -35)

    drawStatusHalo(side: side)
    drawPauli(side: side)

    NSColor.white.withAlphaComponent(0.32).setStroke()
    tilePath.lineWidth = max(1, side * 0.012)
    tilePath.stroke()

    return bitmap
}

private func drawStatusHalo(side: CGFloat) {
    NSColor(calibratedRed: 0.45, green: 0.96, blue: 0.90, alpha: 0.26).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: side * 0.18, y: side * 0.16, width: side * 0.64, height: side * 0.64))
    ring.lineWidth = side * 0.035
    ring.stroke()

    NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.30, alpha: 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: side * 0.63, y: side * 0.70, width: side * 0.11, height: side * 0.11)).fill()
}

private func drawPauli(side: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = side * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.018)
    shadow.set()

    let shell = NSColor(calibratedRed: 0.86, green: 0.94, blue: 0.95, alpha: 1)
    let shellDeep = NSColor(calibratedRed: 0.55, green: 0.70, blue: 0.75, alpha: 1)
    let dark = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.070, alpha: 1)
    let accent = NSColor(calibratedRed: 0.38, green: 0.95, blue: 0.88, alpha: 1)
    let pod = NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.38, alpha: 1)

    pod.setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.16, y: side * 0.39, width: side * 0.17, height: side * 0.26), xRadius: side * 0.07, yRadius: side * 0.07).fill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.67, y: side * 0.39, width: side * 0.17, height: side * 0.26), xRadius: side * 0.07, yRadius: side * 0.07).fill()

    shellDeep.setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.34, y: side * 0.20, width: side * 0.32, height: side * 0.16), xRadius: side * 0.07, yRadius: side * 0.07).fill()

    shell.setFill()
    let head = NSBezierPath(roundedRect: NSRect(x: side * 0.23, y: side * 0.30, width: side * 0.54, height: side * 0.43), xRadius: side * 0.12, yRadius: side * 0.12)
    head.fill()

    dark.setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.31, y: side * 0.40, width: side * 0.38, height: side * 0.24), xRadius: side * 0.08, yRadius: side * 0.08).fill()

    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.39, y: side * 0.515, width: side * 0.07, height: side * 0.055), xRadius: side * 0.018, yRadius: side * 0.018).fill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.54, y: side * 0.515, width: side * 0.07, height: side * 0.055), xRadius: side * 0.018, yRadius: side * 0.018).fill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.455, y: side * 0.455, width: side * 0.09, height: side * 0.025), xRadius: side * 0.012, yRadius: side * 0.012).fill()

    pod.setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.485, y: side * 0.72, width: side * 0.03, height: side * 0.10), xRadius: side * 0.015, yRadius: side * 0.015).fill()
    accent.setFill()
    NSBezierPath(ovalIn: NSRect(x: side * 0.455, y: side * 0.805, width: side * 0.09, height: side * 0.09)).fill()

    NSGraphicsContext.restoreGraphicsState()
}
