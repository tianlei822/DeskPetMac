import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

struct PetGreetingRitualVisualPreview {
  let name: String
  let data: Data
}

enum PetGreetingRitualVisualSequence {
  private static let greetings: [(name: String, greeting: PetGreeting)] = [
    ("first", .firstMeeting),
    ("welcome", .welcomeBack),
    ("long", .longTimeNoSee),
  ]

  @MainActor
  static func render() throws -> [PetGreetingRitualVisualPreview] {
    try PetKind.allCases.flatMap { petKind in
      try greetings.map { greeting in
        let ritual = PetGreetingRitualPlanner.ritual(
          for: PetGreetingRitualContext(
            greeting: greeting.greeting,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.8
          )
        )
        let pose = try #require(ritual.pose)
        let moment = PersonalityMoment(
          id: "visual-greeting.\(petKind.rawValue).\(greeting.name)",
          petKind: petKind,
          category: .interaction,
          pose: pose,
          line: ritual.line
        )
        let name = "\(petKind.rawValue)-greeting-\(greeting.name).png"
        return PetGreetingRitualVisualPreview(
          name: name,
          data: try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: petKind,
              state: .personality,
              weather: .cozy,
              appearance: .light,
              motionSetting: .reduced
            ),
            personalityMoment: moment
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

@Suite("Pet greeting-ritual visuals")
struct PetGreetingRitualVisualTests {
  @Test("every companion renders all three personality greetings")
  @MainActor
  func everyCompanionRendersThreeGreetings() throws {
    let previews = try PetGreetingRitualVisualSequence.render()

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

  @Test("greeting export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_GREETING_RITUAL_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetGreetingRitualVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 9)
  }
}
