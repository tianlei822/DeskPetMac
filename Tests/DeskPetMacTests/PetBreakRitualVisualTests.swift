import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

enum PetBreakRitualVisualSequence {
  private static let phases: [(String, PetVisualSnapshotState)] = [
    ("stretching", .breakStretch),
    ("prompting", .reminder),
  ]

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      phases.map { phaseName, state in
        (
          PetVisualSnapshotCase(
            petKind: petKind,
            state: state,
            weather: .cozy,
            appearance: .light,
            motionSetting: .reduced
          ),
          "\(petKind.rawValue)-break-\(phaseName).png"
        )
      }
    }
    let existing = previews.compactMap { preview -> String? in
      let name = preview.1
      return fileManager.fileExists(
        atPath: outputDirectory.appendingPathComponent(name).path
      ) ? name : nil
    }
    guard existing.isEmpty else {
      throw PetVisualSnapshotRenderer.RenderError
        .artifactsAlreadyExist(existing)
    }

    for (snapshot, name) in previews {
      let data = try PetVisualSnapshotRenderer.pngData(for: snapshot)
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }
}

@Suite("Pet break-ritual visual sequence")
struct PetBreakRitualVisualTests {
  @Test("every companion stretches before its reminder appears")
  @MainActor
  func everyCompanionRendersBothPhases() throws {
    for petKind in PetKind.allCases {
      let stretching = try PetVisualSnapshotRenderer.pngData(
        for: PetVisualSnapshotCase(
          petKind: petKind,
          state: .breakStretch,
          weather: .cozy,
          appearance: .light,
          motionSetting: .reduced
        )
      )
      let prompting = try PetVisualSnapshotRenderer.pngData(
        for: PetVisualSnapshotCase(
          petKind: petKind,
          state: .reminder,
          weather: .cozy,
          appearance: .light,
          motionSetting: .reduced
        )
      )
      let stretchingBitmap = try #require(NSBitmapImageRep(data: stretching))
      let promptingBitmap = try #require(NSBitmapImageRep(data: prompting))

      #expect(stretchingBitmap.pixelsWide == 260)
      #expect(stretchingBitmap.pixelsHigh == 290)
      #expect(promptingBitmap.pixelsWide == 260)
      #expect(promptingBitmap.pixelsHigh == 290)
      #expect(stretching != prompting)
    }
  }

  @Test("sequence export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_BREAK_RITUAL_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetBreakRitualVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 6)
  }
}
