import AppKit
import CoreImage
import DeskPetCore
import SwiftUI

/// Presentation state belongs to the character, not to individual activities.
/// All channels survive interrupted gestures, sleep, and attention changes.
@MainActor
final class PetContinuousPresentation {
    private var channels: [PetDampedValue] = []
    private var previousTime: Double?

    func sample(_ targets: [Double], at time: Double, immediate: Bool) -> [Double] {
        guard time.isFinite else { return targets.map { $0.isFinite ? $0 : 0 } }
        guard channels.count == targets.count, let previousTime, time >= previousTime,
              !immediate else {
            channels = targets.map { PetDampedValue(value: $0) }
            self.previousTime = time
            return channels.map(\.value)
        }
        for index in channels.indices {
            // Eye motion leads the heavier body and joints.
            let response = index >= targets.count - 3 ? 0.12 : 0.30
            channels[index].advance(toward: targets[index], deltaTime: time - previousTime,
                                    response: response)
        }
        self.previousTime = time
        return channels.map(\.value)
    }
}

/// A single inverse deformation field keeps fur, shoulders, paws, and tail
/// connected. No masking/cutting body parts and no full-body pose replacement.
@MainActor
final class PetContinuousArtworkRenderer {
    static let shared = PetContinuousArtworkRenderer()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var images: [PetKind: CIImage] = [:]
    private var lastFrames: [PetKind: (values: [Double], image: CGImage)] = [:]

    // Core Image's source kernel remains available on our macOS 14 floor.
    // Keeping it here lets SwiftPM build without a separate Metal build phase.
    private let kernel = CIWarpKernel(source: """
        kernel vec2 petWarp(float side, vec4 body, vec4 head,
                            vec4 paws, vec4 tail, vec4 eyes, float dog) {
            vec2 p = vec2(destCoord().x / side, 1.0 - destCoord().y / side);
            vec2 q = p;
            float grounded = 1.0 - smoothstep(0.64, 0.87, p.y);
            q.x -= (body.x + body.z * (0.7 - p.y)) * grounded;
            q.y -= body.y * grounded;
            q -= (p - vec2(0.50, 0.86)) * body.w * grounded;
            vec2 hc = mix(vec2(0.40, 0.32), vec2(0.43, 0.40), dog);
            vec2 hd = (p - hc) / vec2(0.16, 0.22);
            float hw = exp(-dot(hd, hd) * 1.6);
            q -= vec2(head.x - head.z * (p.y - hc.y),
                      head.y + head.z * (p.x - hc.x)) * hw;
            float legs = smoothstep(0.54, 0.81, p.y);
            float lx = (p.x - mix(0.38, 0.36, dog)) / 0.043;
            float rx = (p.x - mix(0.48, 0.53, dog)) / 0.044;
            float left = exp(-lx * lx);
            float right = exp(-rx * rx);
            q -= vec2(paws.x, paws.y) * left * legs;
            q -= vec2(paws.z, paws.w) * right * legs;
            vec2 td = (p - mix(vec2(0.66, 0.18), vec2(0.58, 0.13), dog)) / vec2(0.16, 0.24);
            float tw = exp(-dot(td, td)) * (1.0 - smoothstep(0.30, 0.45, p.y));
            q.x -= tail.x * tw;
            q.y -= tail.y * tw;
            vec2 ec = mix(vec2(0.355, 0.275), vec2(0.384, 0.348), dog);
            vec2 ec2 = mix(vec2(0.438, 0.267), vec2(0.487, 0.352), dog);
            vec2 e1 = (q - ec) / vec2(0.024, 0.019);
            vec2 e2 = (q - ec2) / vec2(0.025, 0.019);
            float w1 = exp(-dot(e1, e1) * 1.5);
            float w2 = exp(-dot(e2, e2) * 1.5);
            q.y += ((q.y - ec.y) * w1 + (q.y - ec2.y) * w2) * eyes.z * 7.0;
            q -= eyes.xy * (w1 + w2) * (1.0 - eyes.z);
            return vec2(q.x * side, (1.0 - q.y) * side);
        }
        """)

    var isAvailable: Bool { kernel != nil }

    func image(kind: PetKind, values: [Double]) -> CGImage? {
        guard values.count == 19, let kernel else { return nil }
        if let previous = lastFrames[kind], previous.values == values { return previous.image }
        let side = 384.0
        if images[kind] == nil,
           let artwork = PetArtworkLoader.image(named: PetArtworkManifest(petKind: kind).base),
           let source = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let input = CIImage(cgImage: source)
            let scaled = input.transformed(by: CGAffineTransform(
                scaleX: side / input.extent.width, y: side / input.extent.height))
            // Bake the resize before the warp: otherwise Core Image may fuse
            // the affine transform and interpret warp coordinates in source pixels.
            if let raster = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: side, height: side)) {
                images[kind] = CIImage(cgImage: raster)
            }
        }
        guard let input = images[kind] else { return nil }
        func vector(_ start: Int) -> CIVector {
            CIVector(x: values[start], y: values[start + 1],
                     z: values[start + 2], w: values[start + 3])
        }
        let extent = CGRect(x: 0, y: 0, width: side, height: side)
        guard let result = kernel.apply(extent: extent,
            roiCallback: { _, _ in extent },
            image: input,
            arguments: [side, vector(0), vector(4), vector(8), vector(12),
                        CIVector(x: values[16], y: values[17], z: values[18], w: 0),
                        kind == .dog ? 1.0 : 0.0]),
              let rendered = context.createCGImage(result, from: extent) else { return nil }
        lastFrames[kind] = (values, rendered)
        return rendered
    }
}

struct PetContinuousArtwork: View {
    let kind: PetKind
    let time: Double
    let bodyPose: PetAnimationPose
    let rigPose: PetUnifiedRigPose
    let tailPose: PetTailPose
    let attention: CGSize
    let eyeClosure: Double
    let sleeping: Bool
    let reduceMotion: Bool
    let immediate: Bool
    var personalityPose: PersonalityPose? = nil
    var weatherProfile: WeatherSceneProfile? = nil
    var activityKind: PetActivityKind = .autonomous
    var motionFrame: PetMotionFrame = .idle
    @State private var presentation = PetContinuousPresentation()
    @State private var armTimeline = CyboPalArmTimeline()
    @State private var armPresentation = CyboPalArmPresentation()

    var body: some View {
        if kind == .pauli {
            let action = CyboPalArmAction.resolve(
                activity: sleeping ? .sleeping : activityKind,
                personality: personalityPose, event: motionFrame.event)
            let elapsedProgress = armTimeline.progress(for: action, at: time)
            let progress = immediate ? 0.54
                : (motionFrame.event == .idle ? elapsedProgress : motionFrame.eventProgress)
            let posture = reduceMotion
                ? (sleeping ? CyboPalArmPosture.resting : .sitting)
                : CyboPalArmMotion.posture(action: action, progress: progress)
            let sample = armPresentation.sample(posture: posture,
                attention: reduceMotion ? .zero : attention,
                gesture: reduceMotion ? self.posture : expressionPose,
                eyeClosure: eyeClosure, at: time, immediate: immediate || reduceMotion)
            CyboPalRobot(pose: sample.pose, eyeDirection: sample.eyeDirection,
                         eyeClosure: sample.eyeClosure)
        } else {
            let targets = animalTargets
            let values = presentation.sample(targets, at: time, immediate: immediate || reduceMotion)
            let layout = PetArtworkLayout.resolve(petKind: kind,
                resourceName: PetArtworkManifest(petKind: kind).base)
            ZStack {
                Ellipse().fill(.black.opacity(0.17))
                    .frame(width: layout.shadowWidth, height: layout.shadowHeight)
                    .blur(radius: 4).offset(y: layout.shadowVerticalOffset)
                Group {
                    if let image = PetContinuousArtworkRenderer.shared.image(kind: kind, values: values) {
                        Image(decorative: image, scale: 2).resizable().interpolation(.high)
                            .overlay {
                                if let weatherProfile {
                                    PetWeatherLighting(kind: kind, profile: weatherProfile,
                                        time: time, reduceMotion: reduceMotion)
                                        .mask(Image(decorative: image, scale: 2).resizable())
                                }
                            }
                    } else if let artwork = PetArtworkLoader.image(named: PetArtworkManifest(petKind: kind).base) {
                        Image(nsImage: artwork).resizable().interpolation(.high)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 190, height: 190)
                .scaleEffect(layout.scale)
                .offset(y: layout.verticalOffset + (kind == .cat ? 5 : 0))
            }
            .frame(width: 190, height: 198)
        }
    }

    private var animalTargets: [Double] {
        let moving = !reduceMotion
        let sleepAmount = sleeping ? 1.0 : 0.0
        return [
            moving ? bodyPose.x / 190 * 0.65 : 0,
            moving ? bodyPose.y / 190 * 0.45 + sleepAmount * 0.016 : 0,
            moving ? bodyPose.tiltDegrees * .pi / 180 * 0.45 : 0,
            moving ? (bodyPose.scale - 1) * 0.45 : 0,
            (moving ? attention.width * 0.012 + rigPose.head.x / 190 : 0) + posture.x / 380,
            (moving ? attention.height * 0.008 + sleepAmount * 0.024 + rigPose.head.y / 190 : 0) + posture.y / 380,
            moving ? attention.width * 0.026 + rigPose.head.rotationDegrees * .pi / 180 : 0,
            0,
            moving ? rigPose.frontLeading.x / 190 : 0,
            moving ? rigPose.frontLeading.y / 190 : 0,
            moving ? rigPose.frontTrailing.x / 190 : 0,
            moving ? rigPose.frontTrailing.y / 190 : 0,
            moving ? tailPose.midDegrees * 0.002 * (sleeping ? 0.08 : 1) : 0,
            moving ? tailPose.tipDegrees * 0.0006 * (sleeping ? 0.08 : 1) : 0,
            0, 0,
            moving ? attention.width * 0.003 : 0,
            moving ? attention.height * 0.002 : 0,
            eyeClosure,
        ]
    }

    private var posture: PetAnimationPose {
        switch personalityPose {
        case .stretch: PetAnimationPose(x: 2, y: -7, scale: 1, tiltDegrees: -3)
        case .peek: PetAnimationPose(x: 5, y: 3, scale: 1, tiltDegrees: 4)
        case .perk: PetAnimationPose(x: 0, y: -3, scale: 1, tiltDegrees: -1)
        case .proud: PetAnimationPose(x: -2, y: -4, scale: 1, tiltDegrees: 2)
        case nil: .neutral
        }
    }

    private var expressionPose: PetAnimationPose {
        PetAnimationPose(x: bodyPose.x + posture.x, y: bodyPose.y + posture.y,
            scale: 1, tiltDegrees: bodyPose.tiltDegrees + posture.tiltDegrees)
    }
}
