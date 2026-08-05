import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

struct PetRelationshipGestureVisualSample {
  let name: String
  let elapsed: TimeInterval
}

enum PetRelationshipGestureVisualSequence {
  enum SequenceError: Error {
    case missingCue(PetKind, PetInteractionPreference)
  }

  private static let preferences: [PetInteractionPreference] = [
    .scratch,
    .nuzzle,
    .dance,
    .toy,
  ]

  static let samples = [
    PetRelationshipGestureVisualSample(name: "enter", elapsed: 0.18),
    PetRelationshipGestureVisualSample(name: "hold", elapsed: 1.2),
    PetRelationshipGestureVisualSample(name: "settle", elapsed: 3.2),
  ]

  @MainActor
  static func render(
    usingGestures: Bool = true
  ) throws -> [(name: String, data: Data)] {
    try render(
      samples: [PetRelationshipGestureVisualSample(name: "hold", elapsed: 1.2)],
      usingGestures: usingGestures
    )
  }

  @MainActor
  static func renderSequence(
    usingGestures: Bool = true
  ) throws -> [(name: String, data: Data)] {
    try render(samples: samples, usingGestures: usingGestures)
  }

  @MainActor
  private static func render(
    samples: [PetRelationshipGestureVisualSample],
    usingGestures: Bool
  ) throws -> [(name: String, data: Data)] {
    try PetKind.allCases.flatMap { petKind in
      try preferences.flatMap { preference in
        guard let cue = PetRelationshipCuePlanner.cue(
          for: PetRelationshipCueContext(
            petKind: petKind,
            preferredInteraction: preference,
            familiarity: 0.8,
            rhythmAffinity: 0.8,
            autonomyDrive: .seekAttention,
            isPresentationBlocked: false
          )
        ) else {
          throw SequenceError.missingCue(petKind, preference)
        }
        return try samples.map { sample in
          let moment = PersonalityMoment(
            id: "visual.\(cue.id)",
            petKind: petKind,
            category: .interaction,
            pose: cue.pose,
            relationshipGesture: usingGestures ? cue.gesture : nil,
            line: cue.line
          )
          let suffix = samples.count == 1 ? "" : "-\(sample.name)"
          let name = [
            petKind.rawValue,
            "relationship",
            cue.gesture.rawValue,
          ].joined(separator: "-") + suffix + ".png"
          return (
            name: name,
            data: try PetVisualSnapshotRenderer.pngData(
              for: PetVisualSnapshotCase(
                petKind: petKind,
                state: .personality,
                weather: .cozy,
                appearance: .light,
                motionSetting: .full
              ),
              personalityMoment: moment,
              relationshipGestureElapsed: sample.elapsed
            )
          )
        }
      }
    }
  }

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let previews = try renderSequence()
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

@Suite("Pet relationship-gesture visuals")
struct PetRelationshipGestureVisualTests {
  @Test("every relationship gesture changes production body language")
  @MainActor
  func everyGestureChangesProductionBodyLanguage() throws {
    let previews = try PetRelationshipGestureVisualSequence.render()
    let controls = try PetRelationshipGestureVisualSequence.render(
      usingGestures: false
    )

    #expect(previews.count == 12)
    #expect(controls.count == 12)
    #expect(Set(previews.map(\.name)).count == 12)
    #expect(Set(previews.map(\.data)).count == 12)
    for (preview, control) in zip(previews, controls) {
      #expect(preview.name == control.name)
      #expect(preview.data != control.data)
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))
      #expect(bitmap.pixelsWide == 260)
      #expect(bitmap.pixelsHigh == 290)
      #expect(preview.data.count > 1_000)
    }
  }

  @Test("every relationship gesture renders distinct enter hold and settle stages")
  @MainActor
  func everyGestureRendersDistinctStages() throws {
    let previews = try PetRelationshipGestureVisualSequence.renderSequence()

    #expect(PetRelationshipGestureVisualSequence.samples.count == 3)
    #expect(previews.count == 36)
    #expect(Set(previews.map(\.name)).count == 36)
    #expect(Set(previews.map(\.data)).count == 36)
    for preview in previews {
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))
      #expect(bitmap.pixelsWide == 260)
      #expect(bitmap.pixelsHigh == 290)
      #expect(preview.data.count > 1_000)
    }
  }

  @Test("relationship gesture export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_RELATIONSHIP_GESTURE_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetRelationshipGestureVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 36)
  }
}
