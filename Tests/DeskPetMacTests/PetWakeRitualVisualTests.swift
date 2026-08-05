import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

enum PetWakeRitualVisualSequence {
  private static let phases: [(name: String, state: PetVisualSnapshotState)] = [
    ("sleep", .sleep),
    ("stretch", .wakeStretch),
    ("orient", .wakeOrient),
  ]

  @MainActor
  static func render() throws -> [(name: String, data: Data)] {
    try PetKind.allCases.flatMap { petKind in
      try phases.map { phase in
        let name = "\(petKind.rawValue)-wake-\(phase.name).png"
        return (
          name: name,
          data: try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: petKind,
              state: phase.state,
              weather: .cozy,
              appearance: .light,
              motionSetting: .reduced
            )
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

@Suite("Pet wake-ritual visuals")
struct PetWakeRitualVisualTests {
  @Test("every companion renders sleep and two distinct bubble-free wake stages")
  @MainActor
  func everyCompanionRendersWakeStages() throws {
    let previews = try PetWakeRitualVisualSequence.render()

    #expect(previews.count == 9)
    #expect(Set(previews.map(\.name)).count == 9)
    #expect(Set(previews.map(\.data)).count == 9)
    for preview in previews {
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))
      #expect(bitmap.pixelsWide == 260)
      #expect(bitmap.pixelsHigh == 290)
      #expect(preview.data.count > 1_000)
    }
  }

  @Test("wake export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_WAKE_RITUAL_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetWakeRitualVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 9)
  }
}
