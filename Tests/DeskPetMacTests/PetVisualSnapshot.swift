import DeskPetCore
import SwiftUI

@testable import DeskPetMac

enum PetVisualSnapshotState: String, CaseIterable, Equatable, Sendable {
  case idle
  case hover
  case pat
  case sleep
  case wakeStretch = "wake-stretch"
  case wakeOrient = "wake-orient"
  case dance
  case nuzzle
  case personality
  case breakStretch = "break-stretch"
  case reminder
  case toy
  case rootMotion = "root-motion"
}

enum PetVisualAppearance: String, CaseIterable, Equatable, Sendable {
  case light
  case dark
  case highContrast = "high-contrast"

  var colorScheme: ColorScheme {
    switch self {
    case .light:
      .light
    case .dark, .highContrast:
      .dark
    }
  }

}

enum PetVisualMotionSetting: String, CaseIterable, Equatable, Sendable {
  case full
  case reduced

  var reduceMotion: Bool { self == .reduced }
}

struct PetVisualSnapshotCase: Equatable, Sendable {
  let petKind: PetKind
  let state: PetVisualSnapshotState
  let weather: PetWeatherMood
  let appearance: PetVisualAppearance
  let motionSetting: PetVisualMotionSetting

  var artifactName: String {
    [
      petKind.rawValue,
      state.rawValue,
      weather.rawValue,
      appearance.rawValue,
      motionSetting.rawValue,
    ].joined(separator: "-") + ".png"
  }

  static var standardMatrix: [PetVisualSnapshotCase] {
    PetKind.allCases.flatMap { petKind in
      PetVisualSnapshotState.allCases.flatMap { state in
        PetWeatherMood.allCases.flatMap { weather in
          PetVisualAppearance.allCases.flatMap { appearance in
            PetVisualMotionSetting.allCases.map { motionSetting in
              PetVisualSnapshotCase(
                petKind: petKind,
                state: state,
                weather: weather,
                appearance: appearance,
                motionSetting: motionSetting
              )
            }
          }
        }
      }
    }
  }
}

struct PetVisualSnapshotScene: View {
  static let sceneSize = CGSize(
    width: PetBubbleGeometry.standard.sceneWidth,
    height: 290
  )

  let snapshot: PetVisualSnapshotCase
  let rootMotionFrameOverride: PetRootMotionFrame?
  let bubblePlacementOverride: PetBubblePlacement?
  let personalityMomentOverride: PersonalityMoment?
  let contrastModeOverride: PetAccessibilityContrastMode?
  let attentionElapsedOverride: TimeInterval?
  let relationshipGestureElapsedOverride: TimeInterval?

  private let weatherSize = CGSize(width: 220, height: 218)
  private let artworkSize = CGSize(
    width: PetBubbleGeometry.standard.artworkWidth,
    height: 198
  )
  private let renderTime: TimeInterval = 12_345.625

  init(
    snapshot: PetVisualSnapshotCase,
    rootMotionFrame: PetRootMotionFrame? = nil,
    bubblePlacement: PetBubblePlacement? = nil,
    personalityMoment: PersonalityMoment? = nil,
    contrastMode: PetAccessibilityContrastMode? = nil,
    attentionElapsed: TimeInterval? = nil,
    relationshipGestureElapsed: TimeInterval? = nil
  ) {
    self.snapshot = snapshot
    self.rootMotionFrameOverride = rootMotionFrame
    self.bubblePlacementOverride = bubblePlacement
    self.personalityMomentOverride = personalityMoment
    self.contrastModeOverride = contrastMode
    self.attentionElapsedOverride = attentionElapsed
    self.relationshipGestureElapsedOverride = relationshipGestureElapsed
  }

  var body: some View {
    ZStack(alignment: .top) {
      wallpaper

      VStack(spacing: 6) {
        Spacer(minLength: 38)
        ZStack {
          WeatherBackdrop(
            profile: weatherProfile,
            pointerOffset: pointerOffset,
            reduceMotion: snapshot.motionSetting.reduceMotion
          )
          WeatherMidground(
            profile: weatherProfile,
            pointerOffset: pointerOffset,
            reduceMotion: snapshot.motionSetting.reduceMotion
          )

          RealisticPetBody(
            kind: snapshot.petKind,
            weatherProfile: weatherProfile,
            isHovering: snapshot.state == .hover,
            pulse: snapshot.state == .pat ? 1 : 0,
            comboCount: snapshot.state == .pat ? 2 : 0,
            activity: activity,
            pointerOffset: pointerOffset,
            autonomyState: .neutral,
            reduceMotion: snapshot.motionSetting.reduceMotion,
            motionPreview: nil,
            rootMotionFrame: rootMotionFrame,
            dragLeanAt: { _ in .neutral },
            cursorAttention: { _ in nil },
            onDelight: {},
            artworkOverride: artworkResourceName
          )
          .frame(width: artworkSize.width, height: artworkSize.height)

          if snapshot.state == .toy {
            PetToyView(kind: .forPet(snapshot.petKind))
              .position(
                x: weatherSize.width * 0.76,
                y: weatherSize.height * 0.52
              )
          }

          WeatherForeground(
            profile: weatherProfile,
            pointerOffset: pointerOffset,
            reduceMotion: snapshot.motionSetting.reduceMotion
          )
        }
        .frame(width: weatherSize.width, height: weatherSize.height)
        .offset(
          x: bubbleSceneHorizontalOffset,
          y: bubbleSceneVerticalOffset
        )

        Spacer(minLength: 6)
      }
      .padding(10)

      bubble
        .frame(maxWidth: .infinity, alignment: bubbleAlignment)
        .padding(.horizontal, bubbleHorizontalPadding)
        .padding(.top, bubbleTopOffset)
    }
    .frame(width: Self.sceneSize.width, height: Self.sceneSize.height)
    .clipped()
    .environment(\.colorScheme, snapshot.appearance.colorScheme)
    .environment(
      \.petAccessibilityContrastOverride,
      contrastModeOverride
    )
    .environment(\.petWindowIsVisible, true)
    .environment(\.petRenderTimeOverride, renderTime)
    .environment(\.petAttentionElapsedOverride, attentionElapsedOverride)
    .environment(
      \.petRelationshipGestureElapsedOverride,
      relationshipGestureElapsedOverride
    )
  }

  private var weatherProfile: WeatherSceneProfile {
    WeatherSceneProfile(mood: snapshot.weather)
  }

  private var pointerOffset: CGSize {
    snapshot.state == .hover
      ? CGSize(width: 0.34, height: -0.18)
      : .zero
  }

  private var activity: PetActivity {
    switch snapshot.state {
    case .sleep:
      .sleeping
    case .wakeStretch:
      .waking(.stretch)
    case .wakeOrient:
      .waking(.perk)
    case .dance:
      .dancing
    case .nuzzle:
      .nuzzling
    case .personality:
      .personality(
        personalityMomentOverride?.pose ?? .perk,
        relationshipGesture: personalityMomentOverride?.relationshipGesture
      )
    case .breakStretch, .reminder:
      .reminder
    case .rootMotion:
      .roaming
    case .idle, .hover, .pat, .toy:
      .autonomous(.selfCare)
    }
  }

  private var artworkResourceName: String? {
    let manifest = PetArtworkManifest(petKind: snapshot.petKind)
    return switch snapshot.state {
    case .idle, .dance, .toy:
      manifest.base
    case .hover:
      nil
    case .pat:
      manifest.pat
    case .sleep:
      manifest.sleep
    case .wakeStretch:
      manifest.resourceName(for: .personality(.stretch))
    case .wakeOrient:
      manifest.resourceName(for: .personality(.perk))
    case .nuzzle:
      manifest.blink
    case .personality:
      if personalityMomentOverride?.relationshipGesture != nil {
        nil
      } else {
        manifest.resourceName(
          for: .personality(personalityMomentOverride?.pose ?? .perk)
        )
      }
    case .breakStretch, .reminder:
      manifest.resourceName(for: .personality(.stretch))
    case .rootMotion:
      nil
    }
  }

  private var rootMotionFrame: PetRootMotionFrame? {
    guard snapshot.state == .rootMotion else { return nil }
    if let rootMotionFrameOverride { return rootMotionFrameOverride }
    let plan = PetRootMotionPlan.resolve(
      startX: 200,
      visibleMinX: 0,
      visibleMaxX: 900,
      windowWidth: Self.sceneSize.width,
      desiredDistance: 120,
      preferredDirection: .right
    )
    return plan.frame(
      at: plan.preparationDuration + plan.movementDuration * 0.45
    )
  }

  @ViewBuilder
  private var bubble: some View {
    switch snapshot.state {
    case .personality:
      PersonalityBubble(
        moment: personalityMomentOverride
          ?? PersonalityMoment(
            id: "visual-snapshot",
            petKind: snapshot.petKind,
            category: .general,
            pose: .perk,
            line: "I am right here with you."
          ),
        layout: bubbleLayout
          ?? PetBubbleLayout.resolve(
            kind: .personality,
            petKind: snapshot.petKind
          )
      )
    case .reminder:
      BreakBubbleContent(onDone: {}, onSnooze: {})
    case .idle, .hover, .pat, .sleep, .wakeStretch, .wakeOrient, .dance,
      .nuzzle, .breakStretch, .toy, .rootMotion:
      EmptyView()
    }
  }

  private var bubbleLayout: PetBubbleLayout? {
    let kind: PetBubbleKind? =
      switch snapshot.state {
      case .personality: .personality
      case .reminder: .reminder
      case .idle, .hover, .pat, .sleep, .wakeStretch, .wakeOrient, .dance,
        .nuzzle, .breakStretch, .toy, .rootMotion:
        nil
      }
    guard let kind else { return nil }
    return PetBubbleLayout.resolve(
      kind: kind,
      petKind: snapshot.petKind,
      placement: bubblePlacementOverride ?? .center
    )
  }

  private var bubbleSceneVerticalOffset: CGFloat {
    CGFloat(bubbleLayout?.sceneVerticalOffset ?? 0)
  }

  private var bubbleSceneHorizontalOffset: CGFloat {
    CGFloat(bubbleLayout?.sceneHorizontalOffset ?? 0)
  }

  private var bubbleTopOffset: CGFloat {
    CGFloat(bubbleLayout?.bubbleTopOffset ?? 6)
  }

  private var bubbleHorizontalPadding: CGFloat {
    switch bubbleLayout?.placement {
    case .sideLeading, .sideTrailing:
      PetBubbleGeometry.standard.sideHorizontalPadding
    case .leading, .center, .trailing, .none:
      PetBubbleGeometry.standard.horizontalPadding
    }
  }

  private var bubbleAlignment: Alignment {
    switch bubbleLayout?.placement ?? .center {
    case .leading, .sideLeading:
      .topLeading
    case .center:
      .top
    case .trailing, .sideTrailing:
      .topTrailing
    }
  }

  @ViewBuilder
  private var wallpaper: some View {
    switch snapshot.appearance {
    case .light:
      LinearGradient(
        colors: [
          Color(red: 0.95, green: 0.97, blue: 0.98),
          Color(red: 0.78, green: 0.87, blue: 0.92),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .dark:
      LinearGradient(
        colors: [
          Color(red: 0.10, green: 0.13, blue: 0.18),
          Color(red: 0.03, green: 0.05, blue: 0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .highContrast:
      Color.black
    }
  }
}
