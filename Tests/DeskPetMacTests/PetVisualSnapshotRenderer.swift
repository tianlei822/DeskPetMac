import AppKit
import DeskPetCore
import Foundation
import SwiftUI

@testable import DeskPetMac

enum PetVisualSnapshotRenderer {
  enum RenderError: Error, Equatable {
    case bitmapUnavailable(String)
    case pngEncodingFailed(String)
    case artifactsAlreadyExist([String])
  }

  @MainActor
  static func pngData(
    for snapshot: PetVisualSnapshotCase,
    rootMotionFrame: PetRootMotionFrame? = nil,
    bubblePlacement: PetBubblePlacement? = nil,
    personalityMoment: PersonalityMoment? = nil,
    contrastMode: PetAccessibilityContrastMode? = nil,
    attentionElapsed: TimeInterval? = nil,
    relationshipGestureElapsed: TimeInterval? = nil
  ) throws -> Data {
    let hostingView = NSHostingView(
      rootView: PetVisualSnapshotScene(
        snapshot: snapshot,
        rootMotionFrame: rootMotionFrame,
        bubblePlacement: bubblePlacement,
        personalityMoment: personalityMoment,
        contrastMode: contrastMode,
        attentionElapsed: attentionElapsed,
        relationshipGestureElapsed: relationshipGestureElapsed
      )
    )
    hostingView.frame = NSRect(
      origin: .zero,
      size: PetVisualSnapshotScene.sceneSize
    )
    hostingView.layoutSubtreeIfNeeded()

    guard
      let bitmap = hostingView.bitmapImageRepForCachingDisplay(
        in: hostingView.bounds
      )
    else {
      throw RenderError.bitmapUnavailable(snapshot.artifactName)
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw RenderError.pngEncodingFailed(snapshot.artifactName)
    }
    return data
  }

  @MainActor
  static func pngData<Content: View>(
    for view: Content,
    size: CGSize,
    artifactName: String
  ) throws -> Data {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.layoutSubtreeIfNeeded()

    guard
      let bitmap = hostingView.bitmapImageRepForCachingDisplay(
        in: hostingView.bounds
      )
    else {
      throw RenderError.bitmapUnavailable(artifactName)
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw RenderError.pngEncodingFailed(artifactName)
    }
    return data
  }

  @MainActor
  static func exportStandardMatrix(to outputDirectory: URL) throws {
    let snapshots = PetVisualSnapshotCase.standardMatrix
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    let existing = snapshots.compactMap { snapshot -> String? in
      let url = outputDirectory.appendingPathComponent(
        snapshot.artifactName,
        isDirectory: false
      )
      return fileManager.fileExists(atPath: url.path)
        ? snapshot.artifactName
        : nil
    }
    guard existing.isEmpty else {
      throw RenderError.artifactsAlreadyExist(existing)
    }

    for snapshot in snapshots {
      let data = try pngData(for: snapshot)
      try data.write(
        to: outputDirectory.appendingPathComponent(
          snapshot.artifactName,
          isDirectory: false
        ),
        options: .withoutOverwriting
      )
    }
  }

  @MainActor
  static func exportSideMountedSpeech(to outputDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let previews = PetKind.allCases.flatMap { petKind in
      [PetBubblePlacement.sideLeading, .sideTrailing].map { placement in
        let side = placement == .sideLeading ? "leading" : "trailing"
        return (
          PetVisualSnapshotCase(
            petKind: petKind,
            state: .personality,
            weather: .cozy,
            appearance: .light,
            motionSetting: .reduced
          ),
          placement,
          "\(petKind.rawValue)-side-\(side).png"
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
      throw RenderError.artifactsAlreadyExist(existing)
    }

    for (snapshot, placement, name) in previews {
      let data = try pngData(
        for: snapshot,
        bubblePlacement: placement
      )
      try data.write(
        to: outputDirectory.appendingPathComponent(name),
        options: .withoutOverwriting
      )
    }
  }
}
