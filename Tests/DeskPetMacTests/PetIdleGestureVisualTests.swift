import AppKit
import DeskPetCore
import Foundation
import SwiftUI
import Testing

@testable import DeskPetMac

struct PetIdleGestureVisualSample {
  let name: String
  let event: PetMotionEvent
  let time: TimeInterval
}

enum PetIdleGestureVisualSequence {
  static let samples = [
    PetIdleGestureVisualSample(
      name: "idle-left",
      event: .idleAction1,
      time: 0.8
    ),
    PetIdleGestureVisualSample(
      name: "idle-right",
      event: .idleAction2,
      time: 0.8
    ),
    PetIdleGestureVisualSample(
      name: "look-left",
      event: .lookAround,
      time: 0.8
    ),
    PetIdleGestureVisualSample(
      name: "look-right",
      event: .lookAround,
      time: 2.08
    ),
    PetIdleGestureVisualSample(
      name: "perk-enter",
      event: .perkUp,
      time: 0.18
    ),
    PetIdleGestureVisualSample(
      name: "perk-peak",
      event: .perkUp,
      time: 0.9
    ),
    PetIdleGestureVisualSample(
      name: "perk-settle",
      event: .perkUp,
      time: 1.5
    ),
  ]

  @MainActor
  static func export(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      samples.map { sample in
        (
          petKind,
          sample,
          "\(petKind.rawValue)-\(sample.name).png"
        )
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
      let data = try renderedData(petKind: petKind, sample: sample)
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }

  @MainActor
  static func renderedData(
    petKind: PetKind,
    sample: PetIdleGestureVisualSample
  ) throws -> Data {
    try PetVisualSnapshotRenderer.pngData(
      for: PetIdleGestureRigPreview(
        petKind: petKind,
        event: sample.event,
        time: sample.time
      ),
      size: PetIdleGestureRigPreview.size,
      artifactName: "\(petKind.rawValue)-\(sample.name).png"
    )
  }
}

private struct PetIdleGestureRigPreview: View {
  static let size = CGSize(width: 220, height: 218)

  let petKind: PetKind
  let event: PetMotionEvent
  let time: TimeInterval

  var body: some View {
    let motion = PetMotionDirector.previewFrame(
      pet: petKind,
      event: event,
      time: time,
      reduceMotion: false
    )
    let pose = PetUnifiedRigMotion.pose(
      pet: petKind,
      motion: motion,
      rootMotion: nil,
      reduceMotion: false
    )

    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.95, green: 0.97, blue: 0.98),
          Color(red: 0.78, green: 0.87, blue: 0.92),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Ellipse()
        .fill(.black.opacity(0.17))
        .frame(width: 112 * motion.shadowScale, height: 14)
        .blur(radius: 4)
        .offset(x: motion.shadowOffset, y: 82)

      if let artwork = PetArtworkLoader.image(
        named: PetArtworkManifest(petKind: petKind).base
      ) {
        PetUnifiedRigArtwork(
          kind: petKind,
          artwork: artwork,
          pose: pose,
          tailPose: .neutral
        )
        .scaleEffect(
          x: motion.horizontalScale,
          y: motion.verticalScale,
          anchor: .bottom
        )
        .rotationEffect(.degrees(motion.tiltDegrees))
        .offset(
          x: motion.horizontalOffset,
          y: motion.verticalOffset
        )
        .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
      }
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .clipped()
  }
}

@Suite("Pet idle-gesture unified-rig visuals")
struct PetIdleGestureVisualTests {
  @Test("every companion renders distinct canonical idle gestures")
  @MainActor
  func everyCompanionRendersDistinctGestures() throws {
    #expect(PetIdleGestureVisualSequence.samples.count == 7)

    for petKind in PetKind.allCases {
      let rendered = try PetIdleGestureVisualSequence.samples.map { sample in
        try PetIdleGestureVisualSequence.renderedData(
          petKind: petKind,
          sample: sample
        )
      }
      for data in rendered {
        let bitmap = try #require(NSBitmapImageRep(data: data))
        #expect(bitmap.pixelsWide == 220)
        #expect(bitmap.pixelsHigh == 218)
        #expect(data.count > 1_000)
      }
      #expect(Set(rendered).count == rendered.count)
    }
  }

  @Test("idle-gesture export is opt-in and collision safe")
  @MainActor
  func exportsIdleGesturesOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_IDLE_RIG_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetIdleGestureVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 21)
  }
}
