import AppKit
import DeskPetCore
import SwiftUI

struct PetRigJointPose: Equatable {
  let x: Double
  let y: Double
  let rotationDegrees: Double

  static let neutral = PetRigJointPose(x: 0, y: 0, rotationDegrees: 0)
}

struct PetUnifiedRigPose: Equatable {
  let head: PetRigJointPose
  let frontLeading: PetRigJointPose
  let frontTrailing: PetRigJointPose
  let rear: PetRigJointPose

  static let neutral = PetUnifiedRigPose(
    head: .neutral,
    frontLeading: .neutral,
    frontTrailing: .neutral,
    rear: .neutral
  )

  var joints: [PetRigJointPose] {
    [head, frontLeading, frontTrailing, rear]
  }
}

enum PetUnifiedRigPolicy {
  static func usesCanonicalRelationshipArtwork(
    personalityPose: PersonalityPose?,
    relationshipGesture: PetRelationshipGesture?,
    reduceMotion: Bool
  ) -> Bool {
    personalityPose != nil && relationshipGesture != nil && !reduceMotion
  }

  static func usesCanonicalDirectTouchArtwork(
    isActive: Bool,
    reduceMotion: Bool
  ) -> Bool {
    isActive && !reduceMotion
  }

  static func usesCanonicalArtwork(
    motion: PetMotionFrame,
    rootMotion: PetRootMotionFrame?,
    reduceMotion: Bool
  ) -> Bool {
    guard !reduceMotion else { return false }
    guard rootMotion == nil else { return true }
    return switch motion.event {
    case .walk, .idleAction1, .idleAction2, .lookAround, .perkUp:
      true
    case .idle, .stretch:
      false
    }
  }
}

enum PetUnifiedRigRelationshipMotion {
  static func pose(
    pet: PetKind,
    gesture: PetRelationshipGesture,
    elapsed: TimeInterval,
    reduceMotion: Bool
  ) -> PetUnifiedRigPose {
    let bodyPose = PetRelationshipGestureMotion.pose(
      for: pet,
      gesture: gesture,
      elapsed: elapsed,
      reduceMotion: reduceMotion
    )

    switch gesture {
    case .inviteTouch:
      let amplitude = safeAmplitude((bodyPose.scale - 1) / 0.008)
      guard amplitude > 0 else { return .neutral }
      let direction = bodyPose.x < 0 ? -1.0 : 1.0
      let leadingIsLifted = direction < 0
      return PetUnifiedRigPose(
        head: pet == .pauli
          ? PetRigJointPose(
            x: direction * amplitude * 0.7,
            y: -amplitude * 0.25,
            rotationDegrees: direction * amplitude * 2.6
          )
          : .neutral,
        frontLeading: invitationPaw(
          direction: direction,
          amplitude: amplitude,
          isLifted: leadingIsLifted
        ),
        frontTrailing: invitationPaw(
          direction: direction,
          amplitude: amplitude,
          isLifted: !leadingIsLifted
        ),
        rear: PetRigJointPose(
          x: -direction * amplitude * 0.35,
          y: amplitude * 0.2,
          rotationDegrees: -direction * amplitude * 1.2
        )
      )
    case .leanClose:
      let amplitude = safeAmplitude((bodyPose.scale - 1) / 0.022)
      guard amplitude > 0 else { return .neutral }
      return PetUnifiedRigPose(
        head: pet == .pauli
          ? PetRigJointPose(
            x: bodyPose.x * 0.5,
            y: amplitude * 0.5,
            rotationDegrees: bodyPose.tiltDegrees * 0.8
          )
          : .neutral,
        frontLeading: PetRigJointPose(
          x: -amplitude * 0.72,
          y: amplitude * 0.3,
          rotationDegrees: -amplitude * 1.8
        ),
        frontTrailing: PetRigJointPose(
          x: amplitude * 0.72,
          y: amplitude * 0.3,
          rotationDegrees: amplitude * 1.8
        ),
        rear: PetRigJointPose(
          x: -bodyPose.x * 0.16,
          y: amplitude * 0.18,
          rotationDegrees: -bodyPose.tiltDegrees * 0.25
        )
      )
    case .sharedSway:
      let wave = safeWave(bodyPose.tiltDegrees / 3.6)
      guard abs(wave) > 0 else { return .neutral }
      return PetUnifiedRigPose(
        head: pet == .pauli
          ? PetRigJointPose(
            x: -wave * 0.65,
            y: -abs(wave) * 0.12,
            rotationDegrees: -wave * 2.2
          )
          : .neutral,
        frontLeading: PetRigJointPose(
          x: wave * 1.4,
          y: -max(0, wave) * 2.5,
          rotationDegrees: wave * 4
        ),
        frontTrailing: PetRigJointPose(
          x: -wave * 1.4,
          y: -max(0, -wave) * 2.5,
          rotationDegrees: -wave * 4
        ),
        rear: PetRigJointPose(
          x: -wave * 0.65,
          y: -max(0, -wave) * 0.8,
          rotationDegrees: -wave * 1.8
        )
      )
    case .anticipatePlay:
      let amplitude = safeAmplitude((bodyPose.scale - 1) / 0.030)
      guard amplitude > 0 else { return .neutral }
      return PetUnifiedRigPose(
        head: pet == .pauli
          ? PetRigJointPose(
            x: bodyPose.x * 0.2,
            y: -amplitude * 1.4,
            rotationDegrees: bodyPose.tiltDegrees * 0.35
          )
          : .neutral,
        frontLeading: PetRigJointPose(
          x: -amplitude * 0.95,
          y: amplitude * 0.65,
          rotationDegrees: -amplitude * 2
        ),
        frontTrailing: PetRigJointPose(
          x: amplitude * 0.95,
          y: amplitude * 0.65,
          rotationDegrees: amplitude * 2
        ),
        rear: PetRigJointPose(
          x: -bodyPose.x * 0.12,
          y: amplitude * 0.25,
          rotationDegrees: -bodyPose.tiltDegrees * 0.18
        )
      )
    }
  }

  private static func invitationPaw(
    direction: Double,
    amplitude: Double,
    isLifted: Bool
  ) -> PetRigJointPose {
    PetRigJointPose(
      x: direction * amplitude * (isLifted ? 0.7 : -0.2),
      y: amplitude * (isLifted ? -3.1 : 0.35),
      rotationDegrees: direction * amplitude * (isLifted ? 4.2 : -1.2)
    )
  }

  private static func safeAmplitude(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1.3, max(0, value))
  }

  private static func safeWave(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1.3, max(-1.3, value))
  }
}

enum PetUnifiedRigDirectTouchMotion {
  static func pose(
    pet: PetKind,
    elapsed: Double,
    comboCount: Int,
    reduceMotion: Bool
  ) -> PetUnifiedRigPose {
    let duration = PetAnimationDynamics.patDuration(comboCount: comboCount)
    guard !reduceMotion,
          elapsed.isFinite,
          elapsed > 0,
          elapsed < duration else {
      return .neutral
    }

    let bodyPose = PetAnimationDynamics.patPose(
      for: pet,
      elapsed: elapsed,
      comboCount: comboCount
    )
    let brace = min(2.1, max(0, (bodyPose.scale - 1) / 0.035))
    guard brace > 0 else { return .neutral }

    return PetUnifiedRigPose(
      head: pet == .pauli
        ? PetRigJointPose(
          x: bodyPose.x * 0.18,
          y: brace * 0.68,
          rotationDegrees: bodyPose.tiltDegrees * 0.24
        )
        : .neutral,
      frontLeading: PetRigJointPose(
        x: -brace * 0.78 + bodyPose.x * 0.12,
        y: brace * 0.7,
        rotationDegrees: -brace * 2.3 + bodyPose.tiltDegrees * 0.12
      ),
      frontTrailing: PetRigJointPose(
        x: brace * 0.78 + bodyPose.x * 0.12,
        y: brace * 0.7,
        rotationDegrees: brace * 2.3 + bodyPose.tiltDegrees * 0.12
      ),
      rear: PetRigJointPose(
        x: -bodyPose.x * 0.12,
        y: brace * 0.24,
        rotationDegrees: -bodyPose.tiltDegrees * 0.18
      )
    )
  }
}

enum PetUnifiedRigMotion {
  private struct Tuning {
    let horizontalTravel: Double
    let lift: Double
    let rotation: Double
    let rearScale: Double
  }

  static func pose(
    pet: PetKind,
    motion: PetMotionFrame,
    rootMotion: PetRootMotionFrame?,
    reduceMotion: Bool
  ) -> PetUnifiedRigPose {
    guard !reduceMotion else { return .neutral }

    if let rootMotion {
      return rootPose(pet: pet, frame: rootMotion)
    }
    switch motion.event {
    case .idleAction1, .idleAction2:
      return microActionPose(pet: pet, motion: motion)
    case .lookAround:
      return lookAroundPose(pet: pet, motion: motion)
    case .perkUp:
      return perkUpPose(pet: pet, motion: motion)
    case .walk:
      guard motion.stepCount > 0 else { return .neutral }
      let stridePosition = motion.eventProgress * Double(motion.stepCount)
      let phase = euclideanRemainder(stridePosition)
      let envelope = min(1, max(0, motion.artworkOpacity))
      return gaitPose(
        pet: pet,
        phase: phase,
        amplitude: envelope
      )
    case .idle, .stretch:
      return .neutral
    }
  }

  private static func rootPose(
    pet: PetKind,
    frame: PetRootMotionFrame
  ) -> PetUnifiedRigPose {
    let progress = safeProgress(frame.phaseProgress)
    let eased = smoothStep(progress)
    let direction = Double(frame.direction.rawValue)

    switch frame.phase {
    case .notice, .completed:
      return .neutral
    case .anticipate:
      return stancePose(
        x: -direction * 0.55 * eased,
        y: 1.45 * eased,
        rotation: direction * 1.8 * eased
      )
    case .turning:
      let arc = sin(progress * .pi)
      return PetUnifiedRigPose(
        head: pet == .pauli
          ? PetRigJointPose(
            x: direction * arc * 0.6,
            y: -arc * 0.25,
            rotationDegrees: direction * arc * 2.4
          )
          : .neutral,
        frontLeading: PetRigJointPose(
          x: direction * arc * 2.1,
          y: -arc * 0.7,
          rotationDegrees: direction * arc * 5.2
        ),
        frontTrailing: PetRigJointPose(
          x: -direction * arc * 1.35,
          y: arc * 0.4,
          rotationDegrees: -direction * arc * 3.8
        ),
        rear: PetRigJointPose(
          x: -direction * arc * 0.8,
          y: arc * 0.25,
          rotationDegrees: -direction * arc * 2.4
        )
      )
    case .walking:
      return gaitPose(pet: pet, phase: frame.stridePhase, amplitude: 1)
    case .slowing:
      return gaitPose(
        pet: pet,
        phase: frame.stridePhase,
        amplitude: 1 - eased
      )
    case .settling:
      let rebound = sin(progress * .pi) * (1 - progress)
      return stancePose(
        x: direction * rebound * 0.5,
        y: rebound * 1.1,
        rotation: -direction * rebound * 1.6
      )
    }
  }

  private static func gaitPose(
    pet: PetKind,
    phase: Double,
    amplitude: Double
  ) -> PetUnifiedRigPose {
    let tuning = tuning(for: pet)
    let safeAmplitude = min(1, max(0, amplitude))
    let wave =
      sin(euclideanRemainder(phase) * .pi * 2)
      * safeAmplitude
    let leadingLift = max(0, wave) * tuning.lift
    let trailingLift = max(0, -wave) * tuning.lift

    return PetUnifiedRigPose(
      head: pet == .pauli
        ? PetRigJointPose(
          x: -wave * 0.35,
          y: -abs(wave) * 0.12,
          rotationDegrees: -wave * 1.2
        )
        : .neutral,
      frontLeading: PetRigJointPose(
        x: wave * tuning.horizontalTravel,
        y: -leadingLift,
        rotationDegrees: wave * tuning.rotation
      ),
      frontTrailing: PetRigJointPose(
        x: -wave * tuning.horizontalTravel,
        y: -trailingLift,
        rotationDegrees: -wave * tuning.rotation
      ),
      rear: PetRigJointPose(
        x: -wave * tuning.horizontalTravel * tuning.rearScale,
        y: -trailingLift * tuning.rearScale,
        rotationDegrees: -wave * tuning.rotation * tuning.rearScale
      )
    )
  }

  private static func stancePose(
    x: Double,
    y: Double,
    rotation: Double
  ) -> PetUnifiedRigPose {
    PetUnifiedRigPose(
      head: .neutral,
      frontLeading: PetRigJointPose(
        x: x,
        y: y,
        rotationDegrees: rotation
      ),
      frontTrailing: PetRigJointPose(
        x: -x,
        y: y,
        rotationDegrees: -rotation
      ),
      rear: PetRigJointPose(
        x: -x * 0.45,
        y: y * 0.6,
        rotationDegrees: -rotation * 0.45
      )
    )
  }

  private static func microActionPose(
    pet: PetKind,
    motion: PetMotionFrame
  ) -> PetUnifiedRigPose {
    let progress = safeProgress(motion.eventProgress)
    let envelope = sin(progress * .pi)
    let direction = motion.event == .idleAction1 ? -1.0 : 1.0
    let liftedY = -3.4 * envelope
    let plantedY = 0.45 * envelope

    return PetUnifiedRigPose(
      head: pet == .pauli
        ? PetRigJointPose(
          x: direction * envelope * 1.1,
          y: -envelope * 0.45,
          rotationDegrees: direction * envelope * 4
        )
        : .neutral,
      frontLeading: PetRigJointPose(
        x: direction * envelope * 0.7,
        y: direction < 0 ? liftedY : plantedY,
        rotationDegrees: direction * envelope * 4.2
      ),
      frontTrailing: PetRigJointPose(
        x: -direction * envelope * 0.7,
        y: direction > 0 ? liftedY : plantedY,
        rotationDegrees: -direction * envelope * 4.2
      ),
      rear: PetRigJointPose(
        x: -direction * envelope * 0.35,
        y: envelope * 0.3,
        rotationDegrees: -direction * envelope * 1.6
      )
    )
  }

  private static func lookAroundPose(
    pet: PetKind,
    motion: PetMotionFrame
  ) -> PetUnifiedRigPose {
    let progress = safeProgress(motion.eventProgress)
    let lift = sin(progress * .pi)
    let scan = min(1, max(-1, motion.horizontalOffset / 0.85))

    return PetUnifiedRigPose(
      head: pet == .pauli
        ? PetRigJointPose(
          x: scan * 1.35,
          y: -lift * 0.35,
          rotationDegrees: scan * 3.2
        )
        : .neutral,
      frontLeading: PetRigJointPose(
        x: scan * 0.5,
        y: lift * 0.2,
        rotationDegrees: scan * 1.2
      ),
      frontTrailing: PetRigJointPose(
        x: -scan * 0.5,
        y: lift * 0.2,
        rotationDegrees: -scan * 1.2
      ),
      rear: PetRigJointPose(
        x: -scan * 0.25,
        y: lift * 0.12,
        rotationDegrees: -scan * 0.6
      )
    )
  }

  private static func perkUpPose(
    pet: PetKind,
    motion: PetMotionFrame
  ) -> PetUnifiedRigPose {
    let progress = safeProgress(motion.eventProgress)
    let envelope = sin(progress * .pi)
    let bounce = sin(progress * .pi * 3) * envelope

    return PetUnifiedRigPose(
      head: pet == .pauli
        ? PetRigJointPose(
          x: bounce * 0.2,
          y: -envelope * 2,
          rotationDegrees: bounce * 1.4
        )
        : .neutral,
      frontLeading: PetRigJointPose(
        x: -envelope * 0.85,
        y: envelope * 0.35,
        rotationDegrees: -envelope * 1.8
      ),
      frontTrailing: PetRigJointPose(
        x: envelope * 0.85,
        y: envelope * 0.35,
        rotationDegrees: envelope * 1.8
      ),
      rear: PetRigJointPose(
        x: 0,
        y: envelope * 0.25,
        rotationDegrees: 0
      )
    )
  }

  private static func tuning(for pet: PetKind) -> Tuning {
    switch pet {
    case .cat:
      Tuning(
        horizontalTravel: 2.8,
        lift: 4.2,
        rotation: 7.5,
        rearScale: 0.62
      )
    case .pauli:
      Tuning(
        horizontalTravel: 3.2,
        lift: 5.2,
        rotation: 9.5,
        rearScale: 0
      )
    case .dog:
      Tuning(
        horizontalTravel: 3.4,
        lift: 5.5,
        rotation: 8.2,
        rearScale: 0.58
      )
    }
  }

  private static func safeProgress(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private static func smoothStep(_ value: Double) -> Double {
    value * value * (3 - 2 * value)
  }

  private static func euclideanRemainder(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    let remainder = value.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
  }
}

enum PetRigLayer: CaseIterable {
  case head
  case frontLeading
  case frontTrailing
  case rear
}

struct PetRigLayerMask: Shape {
  let kind: PetKind
  let layer: PetRigLayer

  func path(in rect: CGRect) -> Path {
    PetRigMaskGeometry.path(
      points: PetRigMaskGeometry.points(kind: kind, layer: layer),
      in: rect
    )
  }
}

struct PetRigLayerCutoutMask: Shape {
  let kind: PetKind
  let layer: PetRigLayer

  func path(in rect: CGRect) -> Path {
    let points = PetRigMaskGeometry.points(kind: kind, layer: layer)
    guard !points.isEmpty else { return Path() }
    let minimumY = points.map(\.1).min() ?? 0
    let maximumY = points.map(\.1).max() ?? 0
    let minimumX = points.map(\.0).min() ?? 0
    let maximumX = points.map(\.0).max() ?? 0
    let centerX = (minimumX + maximumX) * 0.5
    let cutout = points.map { x, y in
      let horizontalInset = layer == .head ? 0.026 : 0.007
      let insetX =
        x <= centerX
        ? x + horizontalInset
        : x - horizontalInset
      let insetY: Double
      if y <= minimumY + 0.03 {
        insetY = y + (layer == .head ? 0.024 : 0.016)
      } else if layer == .head, y >= maximumY - 0.03 {
        insetY = y - 0.03
      } else {
        insetY = y
      }
      return (insetX, insetY)
    }
    return PetRigMaskGeometry.path(points: cutout, in: rect)
  }
}

private enum PetRigMaskGeometry {
  static func points(
    kind: PetKind,
    layer: PetRigLayer
  ) -> [(Double, Double)] {
    switch (kind, layer) {
    case (.cat, .head):
      return [
        (0.27, 0.11), (0.52, 0.11), (0.54, 0.43),
        (0.50, 0.51), (0.32, 0.51), (0.27, 0.42),
      ]
    case (.cat, .frontLeading):
      return [(0.34, 0.57), (0.45, 0.58), (0.47, 0.91), (0.33, 0.91)]
    case (.cat, .frontTrailing):
      return [(0.43, 0.57), (0.55, 0.57), (0.56, 0.91), (0.44, 0.91)]
    case (.cat, .rear):
      return [(0.56, 0.53), (0.70, 0.54), (0.70, 0.84), (0.57, 0.84)]
    case (.pauli, .head):
      return [
        (0.28, 0.01), (0.68, 0.01), (0.70, 0.46),
        (0.64, 0.55), (0.35, 0.55), (0.28, 0.46),
      ]
    case (.pauli, .frontLeading):
      return [(0.31, 0.65), (0.50, 0.65), (0.50, 0.95), (0.28, 0.95)]
    case (.pauli, .frontTrailing):
      return [(0.49, 0.65), (0.69, 0.65), (0.71, 0.95), (0.49, 0.95)]
    case (.pauli, .rear):
      return []
    case (.dog, .head):
      return [
        (0.23, 0.20), (0.58, 0.20), (0.60, 0.49),
        (0.54, 0.61), (0.29, 0.61), (0.23, 0.50),
      ]
    case (.dog, .frontLeading):
      return [(0.28, 0.52), (0.45, 0.53), (0.45, 0.96), (0.27, 0.96)]
    case (.dog, .frontTrailing):
      return [(0.44, 0.54), (0.61, 0.54), (0.62, 0.96), (0.44, 0.96)]
    case (.dog, .rear):
      return [(0.60, 0.49), (0.71, 0.50), (0.72, 0.78), (0.61, 0.78)]
    }
  }

  static func path(
    points: [(Double, Double)],
    in rect: CGRect
  ) -> Path {
    guard let first = points.first else { return Path() }

    var path = Path()
    path.move(to: point(first, in: rect))
    for item in points.dropFirst() {
      path.addLine(to: point(item, in: rect))
    }
    path.closeSubpath()
    return path
  }

  private static func point(
    _ normalized: (Double, Double),
    in rect: CGRect
  ) -> CGPoint {
    CGPoint(
      x: rect.minX + rect.width * normalized.0,
      y: rect.minY + rect.height * normalized.1
    )
  }
}

struct PetUnifiedRigArtwork: View {
  let kind: PetKind
  let artwork: NSImage
  let pose: PetUnifiedRigPose
  let tailPose: PetTailPose

  var body: some View {
    ZStack {
      rigLayer(.rear, pose: pose.rear)
      stableBody
      rigLayer(.frontLeading, pose: pose.frontLeading)
      rigLayer(.frontTrailing, pose: pose.frontTrailing)
      if kind == .pauli {
        rigLayer(.head, pose: pose.head)
      }
      flexibleTail
    }
    .compositingGroup()
  }

  private var stableBody: some View {
    artworkImage
      .mask {
        ZStack {
          Rectangle().fill(.white)
          ForEach(articulatedLayers, id: \.self) { layer in
            PetRigLayerCutoutMask(kind: kind, layer: layer)
              .fill(.white)
              .blendMode(.destinationOut)
          }
          if kind == .cat || kind == .dog {
            PetTailMask(kind: kind, segment: .movingRegion)
              .fill(.white)
              .blendMode(.destinationOut)
          }
        }
        .compositingGroup()
      }
  }

  @ViewBuilder
  private func rigLayer(
    _ layer: PetRigLayer,
    pose: PetRigJointPose
  ) -> some View {
    artworkImage
      .mask {
        PetRigLayerMask(kind: kind, layer: layer).fill(.white)
      }
      .rotationEffect(
        .degrees(pose.rotationDegrees),
        anchor: jointAnchor(for: layer)
      )
      .offset(x: pose.x, y: pose.y)
  }

  @ViewBuilder
  private var flexibleTail: some View {
    if kind == .cat || kind == .dog {
      artworkImage
        .mask {
          PetTailMask(kind: kind, segment: .middle).fill(.white)
        }
        .rotationEffect(
          .degrees(tailPose.midDegrees),
          anchor: tailAnchors.middle
        )

      artworkImage
        .mask {
          PetTailMask(kind: kind, segment: .tip).fill(.white)
        }
        .rotationEffect(
          .degrees(tailPose.tipDegrees),
          anchor: tailAnchors.tip
        )
        .rotationEffect(
          .degrees(tailPose.midDegrees),
          anchor: tailAnchors.middle
        )
    }
  }

  private var artworkImage: some View {
    Image(nsImage: artwork)
      .resizable()
      .interpolation(.high)
      .aspectRatio(contentMode: .fit)
      .frame(width: 190, height: 198)
  }

  private var articulatedLayers: [PetRigLayer] {
    PetRigLayer.allCases.filter { layer in
      layer != .head || kind == .pauli
    }
  }

  private func jointAnchor(for layer: PetRigLayer) -> UnitPoint {
    switch (kind, layer) {
    case (.cat, .head): UnitPoint(x: 0.41, y: 0.50)
    case (.cat, .frontLeading): UnitPoint(x: 0.40, y: 0.60)
    case (.cat, .frontTrailing): UnitPoint(x: 0.49, y: 0.60)
    case (.cat, .rear): UnitPoint(x: 0.63, y: 0.56)
    case (.pauli, .head): UnitPoint(x: 0.49, y: 0.54)
    case (.pauli, .frontLeading): UnitPoint(x: 0.40, y: 0.67)
    case (.pauli, .frontTrailing): UnitPoint(x: 0.59, y: 0.67)
    case (.pauli, .rear): .center
    case (.dog, .head): UnitPoint(x: 0.42, y: 0.59)
    case (.dog, .frontLeading): UnitPoint(x: 0.37, y: 0.55)
    case (.dog, .frontTrailing): UnitPoint(x: 0.53, y: 0.56)
    case (.dog, .rear): UnitPoint(x: 0.66, y: 0.52)
    }
  }

  private var tailAnchors: (middle: UnitPoint, tip: UnitPoint) {
    switch kind {
    case .cat:
      (UnitPoint(x: 0.66, y: 0.30), UnitPoint(x: 0.67, y: 0.125))
    case .dog:
      (UnitPoint(x: 0.55, y: 0.255), UnitPoint(x: 0.54, y: 0.125))
    case .pauli:
      (.center, .center)
    }
  }
}
