import AppKit
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

struct PetRootMotionVisualSample {
  let name: String
  let frame: PetRootMotionFrame
}

enum PetRootMotionVisualSequence {
  static func samples(
    direction: PetRootMotionDirection
  ) -> [PetRootMotionVisualSample] {
    let plan = PetRootMotionPlan.resolve(
      startX: 500,
      visibleMinX: 0,
      visibleMaxX: 1440,
      windowWidth: 260,
      desiredDistance: 120,
      preferredDirection: direction
    )
    let noticeDuration = plan.preparationDuration * 0.34
    let anticipateDuration = plan.preparationDuration * 0.36
    let anticipateEnd = noticeDuration + anticipateDuration
    let turnDuration = plan.preparationDuration - anticipateEnd
    let samples: [(String, Double)] = [
      ("notice", noticeDuration * 0.55),
      ("anticipate", noticeDuration + anticipateDuration * 0.65),
      ("turn", anticipateEnd + turnDuration * 0.55),
      ("walk", plan.preparationDuration + plan.movementDuration * 0.35),
      ("slow", plan.preparationDuration + plan.movementDuration * 0.89),
      (
        "settle",
        plan.preparationDuration + plan.movementDuration
          + plan.settlingDuration * 0.55
      ),
      ("completed", plan.duration),
    ]
    return samples.map { name, elapsed in
      PetRootMotionVisualSample(
        name: name,
        frame: plan.frame(at: elapsed)
      )
    }
  }

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      [PetRootMotionDirection.left, .right].flatMap { direction in
        samples(direction: direction).map { sample in
          (
            petKind,
            direction,
            sample,
            artifactName(
              petKind: petKind,
              direction: direction,
              sample: sample
            )
          )
        }
      }
    }
    let existing = previews.compactMap { preview -> String? in
      let name = preview.3
      return fileManager.fileExists(
        atPath: outputDirectory.appendingPathComponent(name).path
      ) ? name : nil
    }
    guard existing.isEmpty else {
      throw PetVisualSnapshotRenderer.RenderError
        .artifactsAlreadyExist(existing)
    }

    for (petKind, _, sample, name) in previews {
      let data = try PetVisualSnapshotRenderer.pngData(
        for: PetVisualSnapshotCase(
          petKind: petKind,
          state: .rootMotion,
          weather: .cozy,
          appearance: .light,
          motionSetting: .full
        ),
        rootMotionFrame: sample.frame
      )
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }

  private static func artifactName(
    petKind: PetKind,
    direction: PetRootMotionDirection,
    sample: PetRootMotionVisualSample
  ) -> String {
    let directionName = direction == .left ? "left" : "right"
    return "\(petKind.rawValue)-\(directionName)-\(sample.name).png"
  }
}

enum PetTransitionClipVisualSequence {
  static let progresses = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]

  static func samples() -> [PetRootMotionVisualSample] {
    let plan = PetRootMotionPlan.resolve(
      startX: 500,
      visibleMinX: 0,
      visibleMaxX: 1440,
      windowWidth: 260,
      desiredDistance: 120,
      preferredDirection: .right
    )
    let noticeDuration = plan.preparationDuration * 0.34
    let anticipateDuration = plan.preparationDuration * 0.36
    let anticipateEnd = noticeDuration + anticipateDuration
    let turnDuration = plan.preparationDuration - anticipateEnd
    return PetTransitionPose.allCases.flatMap { pose in
      progresses.enumerated().map { index, progress in
        let phaseProgress = min(0.999_999, progress)
        let elapsed = switch pose {
        case .anticipate:
          noticeDuration + anticipateDuration * phaseProgress
        case .turn:
          anticipateEnd + turnDuration * phaseProgress
        case .settle:
          plan.preparationDuration + plan.movementDuration
            + plan.settlingDuration * phaseProgress
        }
        return PetRootMotionVisualSample(
          name: "\(pose.rawValue)-\(index + 1)",
          frame: plan.frame(at: elapsed)
        )
      }
    }
  }

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      samples().map { sample in
        (petKind, sample, "\(petKind.rawValue)-\(sample.name).png")
      }
    }
    let existing = previews.compactMap { preview -> String? in
      let name = preview.2
      return fileManager.fileExists(
        atPath: outputDirectory.appendingPathComponent(name).path
      ) ? name : nil
    }
    guard existing.isEmpty else {
      throw PetVisualSnapshotRenderer.RenderError
        .artifactsAlreadyExist(existing)
    }

    for (petKind, sample, name) in previews {
      let data = try PetVisualSnapshotRenderer.pngData(
        for: PetVisualSnapshotCase(
          petKind: petKind,
          state: .rootMotion,
          weather: .cozy,
          appearance: .light,
          motionSetting: .full
        ),
        rootMotionFrame: sample.frame
      )
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }

}

enum PetUnifiedRigVisualSequence {
  static func opposingGaitFrames() -> [(String, PetRootMotionFrame)] {
    let plan = PetRootMotionPlan.resolve(
      startX: 500,
      visibleMinX: 0,
      visibleMaxX: 1440,
      windowWidth: 260,
      desiredDistance: 120,
      preferredDirection: .right
    )
    return [("leading", 0.25), ("trailing", 0.75)].map { name, phase in
      let movementProgress = phase / Double(plan.stepCount)
      return (
        name,
        plan.frame(
          at: plan.preparationDuration
            + plan.movementDuration * movementProgress
        )
      )
    }
  }

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      opposingGaitFrames().map { name, frame in
        (petKind, frame, "\(petKind.rawValue)-gait-\(name).png")
      }
    }
    let existing = previews.compactMap { preview -> String? in
      let name = preview.2
      return fileManager.fileExists(
        atPath: outputDirectory.appendingPathComponent(name).path
      ) ? name : nil
    }
    guard existing.isEmpty else {
      throw PetVisualSnapshotRenderer.RenderError
        .artifactsAlreadyExist(existing)
    }

    for (petKind, frame, name) in previews {
      let data = try PetVisualSnapshotRenderer.pngData(
        for: PetVisualSnapshotCase(
          petKind: petKind,
          state: .rootMotion,
          weather: .cozy,
          appearance: .light,
          motionSetting: .full
        ),
        rootMotionFrame: frame
      )
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }
}

@Suite("Pet root-motion visual sequence")
struct PetRootMotionVisualTests {
  @Test("every companion renders opposing unified-rig gait phases")
  @MainActor
  func everyCompanionRendersOpposingGaitPhases() throws {
    let samples = PetUnifiedRigVisualSequence.opposingGaitFrames()
    #expect(samples.count == 2)

    for petKind in PetKind.allCases {
      let rendered = try samples.map { _, frame in
        try PetVisualSnapshotRenderer.pngData(
          for: PetVisualSnapshotCase(
            petKind: petKind,
            state: .rootMotion,
            weather: .cozy,
            appearance: .light,
            motionSetting: .full
          ),
          rootMotionFrame: frame
        )
      }
      #expect(rendered[0] != rendered[1])
    }
  }

  @Test("every transition clip frame renders through production artwork")
  @MainActor
  func everyTransitionClipFrameRendersOffscreen() throws {
    let samples = PetTransitionClipVisualSequence.samples()
    #expect(samples.count == 12)

    for petKind in PetKind.allCases {
      var renderedByPose: [PetTransitionPose: [Data]] = [:]
      for (poseIndex, pose) in PetTransitionPose.allCases.enumerated() {
        let range = (poseIndex * 4)..<(poseIndex * 4 + 4)
        let rendered = try range.map { index in
          let data = try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: petKind,
              state: .rootMotion,
              weather: .cozy,
              appearance: .light,
              motionSetting: .full
            ),
            rootMotionFrame: samples[index].frame
          )
          let bitmap = try #require(NSBitmapImageRep(data: data))
          #expect(bitmap.pixelsWide == 260)
          #expect(bitmap.pixelsHigh == 290)
          #expect(data.count > 1_000)
          return data
        }
        #expect(Set(rendered).count == 4)
        renderedByPose[pose] = rendered
      }
      #expect(renderedByPose.count == 3)
    }
  }

  @Test("every companion renders each locomotion phase in both directions")
  @MainActor
  func everyPhaseRendersOffscreen() throws {
    for petKind in PetKind.allCases {
      var directionPreviews: [PetRootMotionDirection: [Data]] = [:]

      for direction in [PetRootMotionDirection.left, .right] {
        let samples = PetRootMotionVisualSequence.samples(
          direction: direction
        )
        #expect(
          samples.map(\.frame.phase) == [
            .notice,
            .anticipate,
            .turning,
            .walking,
            .slowing,
            .settling,
            .completed,
          ])

        let rendered = try samples.map { sample in
          let data = try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: petKind,
              state: .rootMotion,
              weather: .cozy,
              appearance: .light,
              motionSetting: .full
            ),
            rootMotionFrame: sample.frame
          )
          let bitmap = try #require(NSBitmapImageRep(data: data))
          #expect(bitmap.pixelsWide == 260)
          #expect(bitmap.pixelsHigh == 290)
          #expect(data.count > 1_000)
          return data
        }
        #expect(Set(rendered).count >= 6)
        directionPreviews[direction] = rendered
      }

      let left = try #require(directionPreviews[.left])
      let right = try #require(directionPreviews[.right])
      #expect(left[1] != right[1])
      #expect(left[2] != right[2])
      #expect(left[5] != right[5])
    }
  }

  @Test("sequence export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_ROOT_MOTION_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetRootMotionVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 42)
  }

  @Test("transition clip export is opt-in and collision safe")
  @MainActor
  func exportsTransitionClipsOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_TRANSITION_CLIP_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetTransitionClipVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 36)
  }

  @Test("unified rig export is opt-in and collision safe")
  @MainActor
  func exportsUnifiedRigOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_UNIFIED_RIG_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetUnifiedRigVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 6)
  }
}
