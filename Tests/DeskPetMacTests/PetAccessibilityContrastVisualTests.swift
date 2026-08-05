import AppKit
import DeskPetCore
import Foundation
import SwiftUI
import Testing

@testable import DeskPetMac

struct PetAccessibilityContrastPreview {
  let name: String
  let data: Data
  let expectedSize: CGSize
}

enum PetAccessibilityContrastVisualSequence {
  private static let contrastModes:
    [(
      name: String,
      mode: PetAccessibilityContrastMode
    )] = [
      ("standard", .standard),
      ("increased", .increased),
    ]

  @MainActor
  static func render() throws -> [PetAccessibilityContrastPreview] {
    let suiteName = "PetAccessibilityContrastVisualSequence.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      throw PetVisualSnapshotRenderer.RenderError.bitmapUnavailable(
        "contrast-preview-defaults"
      )
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let model = PetViewModel(
      defaults: defaults,
      postsReminderNotifications: false
    )
    var previews: [PetAccessibilityContrastPreview] = []

    for contrastMode in contrastModes {
      let personalityName = "\(contrastMode.name)-personality.png"
      previews.append(
        PetAccessibilityContrastPreview(
          name: personalityName,
          data: try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: .cat,
              state: .personality,
              weather: .cozy,
              appearance: .dark,
              motionSetting: .reduced
            ),
            contrastMode: contrastMode.mode
          ),
          expectedSize: PetVisualSnapshotScene.sceneSize
        ))

      let reminderName = "\(contrastMode.name)-reminder.png"
      previews.append(
        PetAccessibilityContrastPreview(
          name: reminderName,
          data: try PetVisualSnapshotRenderer.pngData(
            for: PetVisualSnapshotCase(
              petKind: .dog,
              state: .reminder,
              weather: .cozy,
              appearance: .light,
              motionSetting: .reduced
            ),
            contrastMode: contrastMode.mode
          ),
          expectedSize: PetVisualSnapshotScene.sceneSize
        ))

      let statusName = "\(contrastMode.name)-status.png"
      let statusSize = CGSize(width: 250, height: 105)
      previews.append(
        PetAccessibilityContrastPreview(
          name: statusName,
          data: try PetVisualSnapshotRenderer.pngData(
            for: ContrastPreviewCanvas(
              contrastMode: contrastMode.mode,
              colorScheme: .dark
            ) {
              StatusBubble(model: model, mood: .cozy)
            },
            size: statusSize,
            artifactName: statusName
          ),
          expectedSize: statusSize
        ))

      let menuName = "\(contrastMode.name)-menu.png"
      let menuSize = CGSize(width: 300, height: 600)
      previews.append(
        PetAccessibilityContrastPreview(
          name: menuName,
          data: try PetVisualSnapshotRenderer.pngData(
            for: ContrastPreviewCanvas(
              contrastMode: contrastMode.mode,
              colorScheme: .light
            ) {
              PetMenuView(model: model)
            },
            size: menuSize,
            artifactName: menuName
          ),
          expectedSize: menuSize
        ))
    }

    return previews
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
      throw PetVisualSnapshotRenderer.RenderError
        .artifactsAlreadyExist(existing)
    }

    for preview in previews {
      try preview.data.write(
        to: outputDirectory.appendingPathComponent(preview.name),
        options: .withoutOverwriting
      )
    }
  }
}

private struct ContrastPreviewCanvas<Content: View>: View {
  let contrastMode: PetAccessibilityContrastMode
  let colorScheme: ColorScheme
  @ViewBuilder let content: Content

  init(
    contrastMode: PetAccessibilityContrastMode,
    colorScheme: ColorScheme,
    @ViewBuilder content: () -> Content
  ) {
    self.contrastMode = contrastMode
    self.colorScheme = colorScheme
    self.content = content()
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: colorScheme == .dark
          ? [Color(red: 0.12, green: 0.15, blue: 0.20), .black]
          : [Color.white, Color(red: 0.82, green: 0.88, blue: 0.92)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      content
    }
    .environment(\.colorScheme, colorScheme)
    .environment(\.petAccessibilityContrastOverride, contrastMode)
  }
}

@Suite("Pet accessibility contrast visuals")
struct PetAccessibilityContrastVisualTests {
  @Test("all four companion surfaces render in both contrast modes")
  @MainActor
  func allSurfacesRenderInBothModes() throws {
    let previews = try PetAccessibilityContrastVisualSequence.render()
    #expect(previews.count == 8)

    for preview in previews {
      let bitmap = try #require(NSBitmapImageRep(data: preview.data))
      #expect(bitmap.pixelsWide == Int(preview.expectedSize.width))
      #expect(bitmap.pixelsHigh == Int(preview.expectedSize.height))
      #expect(preview.data.count > 1_000)
    }

    for surface in ["personality", "reminder", "status", "menu"] {
      let standard = try #require(
        previews.first { $0.name == "standard-\(surface).png" }
      )
      let increased = try #require(
        previews.first { $0.name == "increased-\(surface).png" }
      )
      #expect(standard.data != increased.data)
    }
  }

  @Test("contrast export is opt-in and collision safe")
  @MainActor
  func exportsSequenceOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_ACCESSIBILITY_CONTRAST_SNAPSHOT_OUTPUT"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: true)
    try PetAccessibilityContrastVisualSequence.export(to: output)

    let pngCount = try FileManager.default.contentsOfDirectory(
      at: output,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }.count
    #expect(pngCount == 8)
  }
}
