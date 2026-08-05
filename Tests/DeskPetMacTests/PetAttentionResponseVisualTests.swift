import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

enum PetAttentionResponseVisualSequence {
  private static let stages: [(name: String, elapsed: TimeInterval)] = [
    ("eye-lead", 0.05),
    ("head-follow", 0.30),
    ("settled", 0.80),
  ]

  @MainActor
  static func render() throws -> [(name: String, data: Data)] {
    try PetKind.allCases.flatMap { petKind in
      try stages.map { stage in
        let name = "\(petKind.rawValue)-attention-\(stage.name).png"
        return (
          name: name,
          data: try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: petKind,
              state: .hover,
              weather: .cozy,
              appearance: .light,
              motionSetting: .full
            ),
            attentionElapsed: stage.elapsed
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
      throw PetVisualSnapshotRenderer.RenderError.artifactsAlreadyExist(existing)
    }

    for preview in previews {
      try preview.data.write(
        to: outputDirectory.appendingPathComponent(preview.name),
        options: .withoutOverwriting
      )
    }
  }
}

@Suite("Pet attention-response visuals")
struct PetAttentionResponseVisualTests {
  @Test("every companion renders three distinct attention stages")
  @MainActor
  func everyCompanionRendersAttentionStages() throws {
    let previews = try PetAttentionResponseVisualSequence.render()

    #expect(previews.count == 9)
    #expect(Set(previews.map(\.name)).count == 9)
    #expect(Set(previews.map(\.data)).count == 9)
    for pet in PetKind.allCases {
      let petPreviews = previews.filter {
        $0.name.hasPrefix("\(pet.rawValue)-")
      }
      #expect(petPreviews.count == 3)
      #expect(Set(petPreviews.map(\.data)).count == 3)
    }
    for preview in previews {
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))
      #expect(bitmap.pixelsWide == 260)
      #expect(bitmap.pixelsHigh == 290)
      #expect(preview.data.count > 1_000)
    }
  }

  @Test("attention export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_ATTENTION_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetAttentionResponseVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 9)
  }
}
