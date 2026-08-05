import AppKit
import DeskPetCore
import Foundation
import SwiftUI
import Testing

@testable import DeskPetMac

struct PetTouchCalloutPreview {
  let name: String
  let line: String
  let data: Data
}

enum PetTouchResponseVisualSequence {
  private static let previewSize = CGSize(width: 260, height: 120)
  private static let contrastModes: [(name: String, mode: PetAccessibilityContrastMode)] = [
    ("standard", .standard),
    ("increased", .increased),
  ]

  @MainActor
  static func render() throws -> [PetTouchCalloutPreview] {
    try PetKind.allCases.flatMap { petKind in
      let response = PetTouchResponsePlanner.response(
        for: PetTouchResponseContext(
          petKind: petKind,
          action: .scratch(.earOrTemple),
          mood: .cozy,
          bondLevel: .companion,
          familiarity: 0.8,
          interruptedActivity: .autonomous
        )
      )
      return try contrastModes.map { contrastMode in
        let name =
          [
            petKind.rawValue,
            "context-touch-callout",
            contrastMode.name,
          ].joined(separator: "-") + ".png"
        return PetTouchCalloutPreview(
          name: name,
          line: response.line,
          data: try PetVisualSnapshotRenderer.pngData(
            for: TouchCalloutCanvas(
              line: response.line,
              contrastMode: contrastMode.mode
            ),
            size: previewSize,
            artifactName: name
          )
        )
      }
    }
  }

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let previews = try render()
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let existing = previews.compactMap { preview -> String? in
      fileManager.fileExists(
        atPath: outputDirectory.appendingPathComponent(preview.name).path
      ) ? preview.name : nil
    }
    guard existing.isEmpty else {
      throw PetVisualSnapshotRenderer.RenderError.artifactsAlreadyExist(
        existing
      )
    }

    for preview in previews {
      try preview.data.write(
        to: outputDirectory.appendingPathComponent(preview.name),
        options: .withoutOverwriting
      )
    }
  }
}

private struct TouchCalloutCanvas: View {
  let line: String
  let contrastMode: PetAccessibilityContrastMode

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.95, green: 0.97, blue: 0.98),
          Color(red: 0.78, green: 0.87, blue: 0.92),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      PetInteractionCallout(text: line)
        .offset(x: 48)
    }
    .frame(width: 260, height: 120)
    .environment(\.colorScheme, .light)
    .environment(\.petAccessibilityContrastOverride, contrastMode)
  }
}

@Suite("Pet contextual touch-response visuals")
struct PetTouchResponseVisualTests {
  @Test("the longest familiar callouts fit the production component")
  @MainActor
  func familiarCalloutsFit() throws {
    let previews = try PetTouchResponseVisualSequence.render()

    #expect(previews.count == 6)
    #expect(Set(previews.map(\.data)).count == 6)
    for preview in previews {
      let hostingView = NSHostingView(
        rootView: PetInteractionCallout(text: preview.line)
      )
      let size = hostingView.fittingSize
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))

      #expect(size.width <= 124)
      #expect(size.height <= 54)
      #expect(bitmap.pixelsWide == 260)
      #expect(bitmap.pixelsHigh == 120)
      #expect(preview.data.count > 1_000)
    }
    for petKind in PetKind.allCases {
      let standard = try #require(
        previews.first {
          $0.name == "\(petKind.rawValue)-context-touch-callout-standard.png"
        }
      )
      let increased = try #require(
        previews.first {
          $0.name == "\(petKind.rawValue)-context-touch-callout-increased.png"
        }
      )
      #expect(standard.data != increased.data)
    }
  }

  @Test("touch-callout export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_TOUCH_CALLOUT_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetTouchResponseVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 6)
  }
}
