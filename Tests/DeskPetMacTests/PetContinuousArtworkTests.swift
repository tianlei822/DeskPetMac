import AppKit
import DeskPetCore
import SwiftUI
import Testing
import simd
@testable import DeskPetMac

@Suite("Continuous character rendering")
struct PetContinuousArtworkTests {
    @Test("six-axis chain preserves rigid link lengths in every pose")
    func rigidLinks() {
        for index in 0..<120 {
            let pose = CyboPalRobotPose.target(posture: index > 60 ? .resting : .standing,
                attention: CGSize(width: sin(Double(index)), height: cos(Double(index))),
                gesture: PetAnimationPose(x: 8, y: -10, scale: 1.04, tiltDegrees: 12))
            let frames = pose.frames
            #expect(frames.count == 6)
            let lengths = [14.0, 60, 47, 9, 8, 0]
            var previous = SIMD4<Double>(0, 0, 0, 1)
            for (frame, length) in zip(frames, lengths) {
                #expect(abs(simd_length(frame.columns.3 - previous) - length) < 0.000001)
                previous = frame.columns.3
            }
        }
    }

    @Test("presentation does not snap on interruption or duplicate frame samples")
    @MainActor
    func presentationContinuity() {
        let presentation = PetContinuousPresentation()
        #expect(presentation.sample([0, 0, 0, 0], at: 0, immediate: false) == [0, 0, 0, 0])
        let mid = presentation.sample([10, 10, 10, 10], at: 0.1, immediate: false)
        #expect(mid[0] > 0 && mid[0] < 10)
        #expect(presentation.sample([-10, -10, -10, -10], at: 0.1, immediate: false) == mid)
        let next = presentation.sample([-10, -10, -10, -10], at: 0.1167, immediate: false)
        #expect(abs(next[0] - mid[0]) < 1)
        #expect(presentation.sample([0, 0, 0, 0], at: 1, immediate: true) == [0, 0, 0, 0])
    }

    @Test("connected deformation renders real alpha and changes the animal")
    @MainActor
    func deformation() throws {
        let renderer = PetContinuousArtworkRenderer.shared
        #expect(renderer.isAvailable)
        for kind in [PetKind.cat, .dog] {
            let neutral = Array(repeating: 0.0, count: 19)
            var target = neutral
            target[4] = 0.014
            target[8] = 0.015
            target[12] = 0.02
            let first = try #require(renderer.image(kind: kind, values: neutral))
            let second = try #require(renderer.image(kind: kind, values: target))
            #expect(first.width == 384 && second.height == 384)
            #expect(first.dataProvider?.data != second.dataProvider?.data)
            // The whole transparent input is required as the warp ROI. A
            // partial/expanded ROI can clamp the fur into vertical streaks.
            let bitmap = NSBitmapImageRep(cgImage: first)
            for x in stride(from: 0, to: 384, by: 8) {
                #expect((bitmap.colorAt(x: x, y: 0)?.alphaComponent ?? 1) < 0.01)
                #expect((bitmap.colorAt(x: x, y: 383)?.alphaComponent ?? 1) < 0.01)
            }
        }
    }

    @Test("export reviewed character and motion samples on demand")
    @MainActor
    func export() throws {
        guard let path = ProcessInfo.processInfo.environment["DESKPET_CONTINUOUS_OUTPUT"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let raw = try #require(PetContinuousArtworkRenderer.shared.image(kind: .cat,
            values: Array(repeating: 0, count: 19)))
        let bitmap = NSBitmapImageRep(cgImage: raw)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("cat-raw.png"), options: .withoutOverwriting)
        let sheet = VStack(spacing: 16) {
            ForEach(PetKind.allCases, id: \.self) { kind in
                HStack(spacing: 12) {
                    ForEach(0..<4) { index in
                        VStack {
                            sample(kind: kind, index: index)
                            Text(["Rest", "Attention", "Touch", "Sleep"][index])
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }.padding(24).background(Color(red: 0.90, green: 0.91, blue: 0.92))
        let data = try PetVisualSnapshotRenderer.pngData(for: sheet,
            size: CGSize(width: 844, height: 765), artifactName: "characters.png")
        try data.write(to: directory.appendingPathComponent("characters.png"), options: .withoutOverwriting)
        // Window samples exercise the live renderer rather than legacy PNG overrides.
        for kind in PetKind.allCases {
            let snapshot = PetVisualSnapshotCase(petKind: kind, state: .idle,
                weather: .cozy, appearance: .light, motionSetting: .full)
            let png = try PetVisualSnapshotRenderer.pngData(for: snapshot)
            try png.write(to: directory.appendingPathComponent("\(kind.rawValue)-window.png"), options: .withoutOverwriting)
        }
    }

    @MainActor
    private func sample(kind: PetKind, index: Int) -> some View {
        PetContinuousArtwork(kind: kind, time: 1.0,
            bodyPose: index == 2
                ? PetAnimationPose(x: 4, y: -6, scale: 1.025, tiltDegrees: 5) : .neutral,
            rigPose: .neutral,
            tailPose: PetTailPose(midDegrees: 4, tipDegrees: 6),
            attention: index == 1 ? CGSize(width: 1, height: -0.7) : .zero,
            eyeClosure: index == 3 ? 1 : 0, sleeping: index == 3,
            reduceMotion: false, immediate: true)
    }
}
