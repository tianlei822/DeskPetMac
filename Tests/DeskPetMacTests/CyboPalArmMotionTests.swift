import AppKit
import DeskPetCore
import SwiftUI
import Testing
import simd
@testable import DeskPetMac

@Suite("CyboPal arm motion")
struct CyboPalArmMotionTests {
    @Test("client posture concepts change reach height and display roll")
    func postureSemantics() {
        let sitting = CyboPalArmPosture.sitting
        #expect(CyboPalArmPosture.standing.height > sitting.height)
        #expect(CyboPalArmPosture.reclined.reach < sitting.reach)
        #expect(CyboPalArmPosture.portrait.roll == .pi / 2)
        #expect(CyboPalArmPosture.resting.height < sitting.height)
    }

    @Test("activities select distinct arm intentions")
    func intentions() {
        #expect(CyboPalArmAction.resolve(activity: .sleeping, personality: nil, event: .idle) == .rest)
        #expect(CyboPalArmAction.resolve(activity: .feeding, personality: .peek, event: .idle) == .reach)
        #expect(CyboPalArmAction.resolve(activity: .dancing, personality: nil, event: .idle) == .celebrate)
        #expect(CyboPalArmAction.resolve(activity: .reminder, personality: .stretch, event: .idle) == .lift)
        #expect(CyboPalArmAction.resolve(activity: .personality, personality: .peek, event: .idle) == .observe)
    }

    @Test("every motion starts and ends in the sitting pose without a jump")
    func boundaries() {
        for action in CyboPalArmAction.allCases where action != .rest {
            let start = CyboPalArmMotion.posture(action: action, progress: 0)
            let end = CyboPalArmMotion.posture(action: action, progress: 1)
            #expect(start == .sitting)
            #expect(end == .sitting)
        }
    }

    @Test("all six joints stay finite and inside presentation limits")
    func boundedMotion() {
        for action in CyboPalArmAction.allCases {
            for index in 0...120 {
                let posture = CyboPalArmMotion.posture(action: action, progress: Double(index) / 120)
                let pose = CyboPalRobotPose.target(posture: posture,
                    attention: .init(width: index % 2 == 0 ? -1 : 1, height: 1),
                    gesture: .init(x: 8, y: -10, scale: 1, tiltDegrees: 12))
                for (joint, limit) in zip(pose.joints, CyboPalRobotPose.jointLimits) {
                    #expect(joint.isFinite && limit.contains(joint))
                }
                let display = pose.frames[5]
                for x in [-57.0, 57] {
                    for y in [-35.0, 35] {
                        let point = CyboPalRobotPose.project(display * SIMD4(x, y + 21, 5, 1))
                        #expect((0...190).contains(point.x))
                        #expect((0...198).contains(point.y))
                    }
                }
            }
        }
    }

    @Test("motion clock freezes through suspension and restarts on a new intention")
    @MainActor
    func timeline() {
        let clock = CyboPalArmTimeline()
        #expect(clock.progress(for: .observe, at: 10) == 0)
        let before = clock.progress(for: .observe, at: 10.1)
        #expect(before > 0)
        #expect(abs(clock.progress(for: .observe, at: 20) - before) < 0.000001)
        #expect(clock.progress(for: .reach, at: 20.1) == 0)
    }

    @Test("interrupted arm transitions keep the base grounded and screen visible")
    @MainActor
    func interruptions() {
        let controller = CyboPalArmPresentation()
        let postures: [CyboPalArmPosture] = [.sitting, .portrait, .standing, .resting, .reclined]
        for frame in 0..<300 {
            let presented = controller.sample(posture: postures[(frame / 23) % postures.count],
                attention: .init(width: sin(Double(frame) / 30), height: -0.7), gesture: .neutral,
                eyeClosure: 0, at: Double(frame) / 60, immediate: false).pose
            #expect(simd_length(presented.frames[0].columns.3 - SIMD4(0, 14, 0, 1)) < 0.000001)
            for point in presented.screenCorners {
                #expect((0...190).contains(point.x))
                #expect((0...198).contains(point.y))
            }
        }
    }

    @Test("export arm actions and animation frames on demand")
    @MainActor
    func export() throws {
        guard let path = ProcessInfo.processInfo.environment["DESKPET_ARM_OUTPUT"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let actions: [CyboPalArmAction] = [.observe, .reach, .lift, .portrait, .celebrate, .rest]
        let sheet = VStack(spacing: 10) {
            ForEach(actions.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<5) { column in
                        VStack {
                            robot(action: actions[row], progress: Double(column) / 4)
                            Text("\(String(describing: actions[row])) · \(column * 25)%")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }.padding(16).background(Color(white: 0.92))
        try PetVisualSnapshotRenderer.pngData(for: sheet, size: CGSize(width: 1014, height: 1390),
            artifactName: "arm-actions.png")
            .write(to: directory.appendingPathComponent("arm-actions.png"), options: .withoutOverwriting)

        // Sample the same spring controller used by the live character.
        let controllers = actions.map { _ in CyboPalArmPresentation() }
        for frame in 0..<120 {
            let t = Double(frame) / 30
            let progress = min(1, t / 3.5)
            let poses = zip(actions, controllers).map { action, controller in
                controller.sample(
                    posture: CyboPalArmMotion.posture(action: action, progress: progress),
                    attention: .zero, gesture: .neutral, eyeClosure: 0,
                    at: t, immediate: false).pose
            }
            let view = VStack(spacing: 0) {
                ForEach(0..<2) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { column in
                            let index = row * 3 + column
                            VStack(spacing: 2) {
                                CyboPalRobot(pose: poses[index], eyeDirection: .zero,
                                    eyeClosure: actions[index] == .rest ? 1 : 0)
                                Text(String(describing: actions[index])).font(.system(size: 12))
                            }
                        }
                    }
                }
            }.padding(10).background(Color(white: 0.92))
            let name = String(format: "frame-%03d.png", frame)
            try PetVisualSnapshotRenderer.pngData(for: view, size: CGSize(width: 590, height: 464),
                artifactName: name).write(to: directory.appendingPathComponent(name), options: .withoutOverwriting)
        }
    }

    @MainActor
    private func robot(action: CyboPalArmAction, progress: Double) -> some View {
        CyboPalRobot(pose: .target(posture: CyboPalArmMotion.posture(action: action, progress: progress),
            attention: .zero, gesture: .neutral), eyeDirection: .zero, eyeClosure: action == .rest ? 1 : 0)
    }
}
