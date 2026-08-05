#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count > 1 else {
  fputs("Usage: report-png-alpha-bounds.swift <image.png> [...]\n", stderr)
  exit(64)
}

for path in CommandLine.arguments.dropFirst() {
  let url = URL(fileURLWithPath: path)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Unable to decode \(path)\n", stderr)
    exit(65)
  }

  let bytesPerPixel = 4
  let bytesPerRow = image.width * bytesPerPixel
  var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
  guard let context = CGContext(
    data: &pixels,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    fputs("Unable to create bitmap context for \(path)\n", stderr)
    exit(70)
  }
  context.draw(
    image,
    in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
  )

  var minX = image.width
  var minY = image.height
  var maxX = -1
  var maxY = -1
  var visiblePixels = 0
  for y in 0..<image.height {
    for x in 0..<image.width {
      let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
      guard alpha >= 16 else { continue }
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x)
      maxY = max(maxY, y)
      visiblePixels += 1
    }
  }

  guard visiblePixels > 0 else {
    fputs("No visible pixels in \(path)\n", stderr)
    exit(65)
  }
  print(
    "\(path) width=\(image.width) height=\(image.height) "
      + "minX=\(minX) minY=\(minY) maxX=\(maxX) maxY=\(maxY) "
      + "visiblePixels=\(visiblePixels)"
  )
}
