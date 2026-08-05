import AppKit
import DeskPetCore
import Foundation
import SwiftUI
import Testing

@testable import DeskPetMac

struct PetDirectTouchRigVisualSample {
  let name: String
  let progress: Double
  let comboCount: Int
  let scale: Double
  let tiltDegrees: Double
  let offset: CGSize

  init(
    name: String,
    progress: Double,
    comboCount: Int = 1,
    scale: Double = 1,
    tiltDegrees: Double = 0,
    offset: CGSize = .zero
  ) {
    self.name = name
    self.progress = progress
    self.comboCount = comboCount
    self.scale = scale
    self.tiltDegrees = tiltDegrees
    self.offset = offset
  }
}

enum PetDirectTouchRigVisualSequence {
  static let samples = [
    PetDirectTouchRigVisualSample(name: "pat-enter", progress: 0.18),
    PetDirectTouchRigVisualSample(name: "pat-peak", progress: 0.5),
    PetDirectTouchRigVisualSample(
      name: "combo-three",
      progress: 0.5,
      comboCount: 3
    ),
    PetDirectTouchRigVisualSample(
      name: "combo-five",
      progress: 0.375,
      comboCount: 5
    ),
    PetDirectTouchRigVisualSample(
      name: "scratch",
      progress: 0.5,
      scale: 1.025,
      tiltDegrees: 2.5,
      offset: CGSize(width: 0, height: 3)
    ),
    PetDirectTouchRigVisualSample(
      name: "swipe-right",
      progress: 0.32,
      tiltDegrees: 7.5,
      offset: CGSize(width: 11.3, height: 0)
    ),
    PetDirectTouchRigVisualSample(
      name: "swipe-up",
      progress: 0.32,
      tiltDegrees: -7.5,
      offset: CGSize(width: 0, height: -11.3)
    ),
  ]

  @MainActor
  static func renderedData(
    petKind: PetKind,
    sample: PetDirectTouchRigVisualSample
  ) throws -> Data {
    try PetVisualSnapshotRenderer.pngData(
      for: PetDirectTouchRigPreview(
        petKind: petKind,
        sample: sample
      ),
      size: PetDirectTouchRigPreview.size,
      artifactName: "\(petKind.rawValue)-\(sample.name).png"
    )
  }

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
}

private struct PetDirectTouchRigPreview: View {
  static let size = CGSize(width: 220, height: 218)

  let petKind: PetKind
  let sample: PetDirectTouchRigVisualSample

  var body: some View {
    let duration = PetAnimationDynamics.patDuration(
      comboCount: sample.comboCount
    )
    let elapsed = duration * sample.progress
    let bodyPose = PetAnimationDynamics.patPose(
      for: petKind,
      elapsed: elapsed,
      comboCount: sample.comboCount
    )
    let rigPose = PetUnifiedRigDirectTouchMotion.pose(
      pet: petKind,
      elapsed: elapsed,
      comboCount: sample.comboCount,
      reduceMotion: false
    )

    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.96, green: 0.94, blue: 0.98),
          Color(red: 0.84, green: 0.87, blue: 0.96),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Ellipse()
        .fill(.black.opacity(0.17))
        .frame(
          width: 112 / bodyPose.scale,
          height: 14 / bodyPose.scale
        )
        .blur(radius: 4)
        .offset(y: 82)

      if let artwork = PetArtworkLoader.image(
        named: PetArtworkManifest(petKind: petKind).base
      ) {
        PetUnifiedRigArtwork(
          kind: petKind,
          artwork: artwork,
          pose: rigPose,
          tailPose: .neutral
        )
        .scaleEffect(bodyPose.scale * sample.scale, anchor: .bottom)
        .rotationEffect(
          .degrees(bodyPose.tiltDegrees + sample.tiltDegrees)
        )
        .offset(
          x: bodyPose.x + sample.offset.width,
          y: bodyPose.y + sample.offset.height
        )
        .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
      }
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .clipped()
  }
}

@Suite("Pet direct-touch unified-rig visuals")
struct PetDirectTouchRigVisualTests {
  @Test("every companion renders distinct direct-touch responses")
  @MainActor
  func everyCompanionRendersDistinctResponses() throws {
    #expect(PetDirectTouchRigVisualSequence.samples.count == 7)

    for petKind in PetKind.allCases {
      let rendered = try PetDirectTouchRigVisualSequence.samples.map { sample in
        try PetDirectTouchRigVisualSequence.renderedData(
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

  @Test("direct-touch export is opt-in and collision safe")
  @MainActor
  func exportsDirectTouchResponsesOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_DIRECT_TOUCH_RIG_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetDirectTouchRigVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 21)
  }
}
