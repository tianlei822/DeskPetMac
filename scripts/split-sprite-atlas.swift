#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4 else {
  fputs(
    "Usage: split-sprite-atlas.swift <atlas.png> <output-directory> <prefix>\n",
    stderr
  )
  exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
let prefix = CommandLine.arguments[3]

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
  fputs("Unable to decode atlas at \(sourceURL.path)\n", stderr)
  exit(65)
}

let columns = 2
let rows = 2
guard image.width.isMultiple(of: columns),
      image.height.isMultiple(of: rows) else {
  fputs("Atlas dimensions must be divisible by 2 × 2\n", stderr)
  exit(65)
}

try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)

let frameWidth = image.width / columns
let frameHeight = image.height / rows
let seamInset = 2
guard frameWidth > seamInset * 2,
      frameHeight > seamInset * 2 else {
  fputs("Atlas cells are too small for the seam inset\n", stderr)
  exit(65)
}
for row in 0..<rows {
  for column in 0..<columns {
    let index = row * columns + column + 1
    let frameURL = outputDirectory
      .appendingPathComponent("\(prefix)\(index).png")
    guard !FileManager.default.fileExists(atPath: frameURL.path) else {
      fputs("Refusing to overwrite \(frameURL.path)\n", stderr)
      exit(73)
    }

    let crop = CGRect(
      x: column * frameWidth + seamInset,
      y: row * frameHeight + seamInset,
      width: frameWidth - seamInset * 2,
      height: frameHeight - seamInset * 2
    )
    guard let frame = image.cropping(to: crop),
          let destination = CGImageDestinationCreateWithURL(
            frameURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
          ) else {
      fputs("Unable to create frame \(index)\n", stderr)
      exit(74)
    }

    CGImageDestinationAddImage(destination, frame, nil)
    guard CGImageDestinationFinalize(destination) else {
      fputs("Unable to write frame \(index)\n", stderr)
      exit(74)
    }
  }
}

print("Wrote \(columns * rows) frames to \(outputDirectory.path)")
