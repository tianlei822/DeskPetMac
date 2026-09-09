import DeskPetCore
import SwiftUI
import simd

/// Six serial revolute axes: base yaw, shoulder, elbow, forearm roll,
/// wrist pitch, display roll. Every child inherits the upstream transform.
struct CyboPalRobotPose {
    let joints: [Double]

    static let jointLimits: [ClosedRange<Double>] = [
        -0.78...0.48, -0.25...1.40, -2.25 ... -0.15,
        -0.16...0.16, -0.40...0.45, -0.20...3.40,
    ]

    static func target(posture: CyboPalArmPosture, attention: CGSize,
                       gesture: PetAnimationPose) -> Self {
        func bounded(_ value: Double, _ limits: ClosedRange<Double>) -> Double {
            value.isFinite ? min(limits.upperBound, max(limits.lowerBound, value)) : 0
        }
        let x = bounded(attention.width, -1...1)
        let y = bounded(attention.height, -1...1)
        let lean = bounded(gesture.x / 8, -1...1)
        let nod = bounded(gesture.y / 10, -1...1)
        var reach = bounded(posture.reach + lean * 3 + x * 2, -5...40)
        var height = bounded(posture.height - nod * 2, 70...115)
        func solve(reach: Double, height: Double) -> Self {
            // The two wrist offsets contribute to the effective forearm length.
            let upper = 60.0
            let lower = 64.0
            let distance = min(121, max(65, hypot(reach, height)))
            let shoulder = -atan2(reach, height)
                + acos(bounded((distance * distance + upper * upper - lower * lower)
                              / (2 * distance * upper), -1...1))
            let elbow = -acos(bounded((distance * distance - upper * upper - lower * lower)
                                    / (2 * upper * lower), -1...1))
            let roll = bounded(posture.roll, -0.3...(.pi / 2))
                + bounded(gesture.tiltDegrees, -15...15) * .pi / 180 * 0.35
            let values = [
                bounded(posture.yaw, -0.62...0.30) + x * 0.14,
                shoulder, elbow, x * 0.10,
                bounded(posture.tilt, -0.3...0.3) + y * 0.10 + nod * 0.04,
                // Counter-rotate the display as shoulder/elbow change its height.
                -shoulder - elbow + roll,
            ]
            return Self(joints: zip(values, jointLimits).map { bounded($0.0, $0.1) })
        }
        var result = solve(reach: reach, height: height)
        // Like the client's workspace check, test screen corners rather than
        // only its center. Correct the wrist target, keeping the base fixed.
        for _ in 0..<4 {
            let corners = result.screenCorners
            let minX = corners.map(\.x).min() ?? 4
            let maxX = corners.map(\.x).max() ?? 186
            let minY = corners.map(\.y).min() ?? 4
            let maxY = corners.map(\.y).max() ?? 168
            let horizontal = max(0, 4 - minX) - max(0, maxX - 186)
            let vertical = max(0, maxY - 168) - max(0, 4 - minY)
            if abs(horizontal) < 0.01 && abs(vertical) < 0.01 { break }
            reach = bounded(reach + horizontal * 1.2, -5...40)
            height = bounded(height + vertical, 66...115)
            result = solve(reach: reach, height: height)
        }
        return result
    }

    var screenCorners: [CGPoint] {
        let display = frames[5]
        return [-57.0, 57].flatMap { x in
            [-35.0, 35].map { y in Self.project(display * SIMD4(x, y + 21, 5, 1)) }
        }
    }

    var frames: [simd_double4x4] {
        var transform = matrix_identity_double4x4
        var result: [simd_double4x4] = []
        let axes: [SIMD3<Double>] = [
            SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, 1),
            SIMD3(0, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1),
        ]
        let lengths = [14.0, 60, 47, 9, 8, 0]
        for index in 0..<6 {
            transform *= simd_double4x4(simd_quatd(angle: joints[index], axis: axes[index]))
            var translation = matrix_identity_double4x4
            translation.columns.3 = SIMD4(0, lengths[index], 0, 1)
            transform *= translation
            result.append(transform)
        }
        return result
    }

    static func project(_ point: SIMD4<Double>) -> CGPoint {
        CGPoint(x: 89 + point.x + point.z * 0.32,
                y: 186 - point.y + point.z * 0.15)
    }
}

struct CyboPalRobot: View {
    let pose: CyboPalRobotPose
    let eyeDirection: CGSize
    let eyeClosure: Double

    var body: some View {
        Canvas { context, _ in
            let frames = pose.frames
            let points = frames.map { CyboPalRobotPose.project($0.columns.3) }
            let ground = CGPoint(x: 89, y: 186)
            context.addFilter(.shadow(color: .black.opacity(0.17), radius: 4, y: 3))

            // The base never inherits expression or arm transforms.
            let base = Path(roundedRect: CGRect(x: 55, y: 172, width: 70, height: 19), cornerRadius: 5)
            context.fill(base, with: .linearGradient(
                Gradient(colors: [Color(white: 0.98), Color(white: 0.57)]),
                startPoint: CGPoint(x: 62, y: 172), endPoint: CGPoint(x: 110, y: 193)))
            context.stroke(base, with: .color(.black.opacity(0.28)), lineWidth: 0.7)
            link(&context, from: ground, to: points[0], width: 19)
            link(&context, from: points[0], to: points[1], width: 15)
            link(&context, from: points[1], to: points[2], width: 12)
            link(&context, from: points[2], to: points[3], width: 10)
            link(&context, from: points[3], to: points[4], width: 9)
            for index in 0..<5 {
                joint(&context, center: points[index], radius: index < 2 ? 9 : 6)
            }

            let display = frames[5]
            func onScreen(_ x: Double, _ y: Double, _ z: Double = 5) -> CGPoint {
                CyboPalRobotPose.project(display * SIMD4(x, y + 21, z, 1))
            }
            let casing = polygon([
                onScreen(-57, -35, -1), onScreen(57, -35, -1),
                onScreen(57, 35, -1), onScreen(-57, 35, -1),
            ])
            context.fill(casing, with: .color(Color(white: 0.65)))
            let bezel = polygon([
                onScreen(-57, -35), onScreen(57, -35),
                onScreen(57, 35), onScreen(-57, 35),
            ])
            context.fill(bezel, with: .color(Color(white: 0.075)))
            context.stroke(bezel, with: .color(Color(white: 0.82)), lineWidth: 0.8)
            let glass = polygon([
                onScreen(-54, -32), onScreen(54, -32),
                onScreen(54, 32), onScreen(-54, 32),
            ])
            context.fill(glass, with: .linearGradient(
                Gradient(colors: [Color(red: 0.31, green: 0.49, blue: 0.77),
                                  Color(red: 0.66, green: 0.57, blue: 0.72),
                                  Color(red: 0.32, green: 0.64, blue: 0.75)]),
                startPoint: onScreen(-45, 34), endPoint: onScreen(50, -34)))
            let closure = min(1, max(0, eyeClosure))
            for x in [-17.0, 17.0] {
                let height = 7.5 * (1 - closure) + 0.8
                let center = onScreen(x + Double(eyeDirection.width) * 4,
                                      1 - Double(eyeDirection.height) * 3)
                var eyeContext = context
                let horizontal = onScreen(x + 1, 0)
                let origin = onScreen(x, 0)
                eyeContext.translateBy(x: center.x, y: center.y)
                eyeContext.rotate(by: .radians(atan2(horizontal.y - origin.y, horizontal.x - origin.x)))
                let eye = Path(roundedRect: CGRect(x: -4, y: -height, width: 8, height: height * 2), cornerRadius: 4)
                eyeContext.fill(eye, with: .color(.white.opacity(0.96)))
            }
            let camera = onScreen(0, 34)
            context.fill(Path(ellipseIn: CGRect(x: camera.x - 1.2, y: camera.y - 1.2, width: 2.4, height: 2.4)),
                         with: .color(Color(white: 0.13)))
            let companion = Path(roundedRect: CGRect(x: 81, y: 176, width: 19, height: 10), cornerRadius: 2)
            context.fill(companion, with: .color(Color(white: 0.10)))
            for x in [87.0, 93.0] {
                context.fill(Path(ellipseIn: CGRect(x: x, y: 179, width: 2, height: 3)), with: .color(.white.opacity(0.9)))
            }
        }
        .frame(width: 190, height: 198)
        .accessibilityLabel("Pauli, CyboPal six-axis screen robot")
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }

    private func link(_ context: inout GraphicsContext, from start: CGPoint, to end: CGPoint, width: Double) {
        let path = Path { path in path.move(to: start); path.addLine(to: end) }
        context.stroke(path, with: .color(Color(white: 0.42)), style: StrokeStyle(lineWidth: width + 1, lineCap: .round))
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [Color(white: 0.97), Color(white: 0.70), Color(white: 0.88)]),
            startPoint: CGPoint(x: start.x - width / 2, y: start.y),
            endPoint: CGPoint(x: start.x + width / 2, y: start.y)),
            style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func joint(_ context: inout GraphicsContext, center: CGPoint, radius: Double) {
        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(ring, with: .linearGradient(
            Gradient(colors: [Color(white: 0.99), Color(white: 0.65)]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
        context.stroke(ring, with: .color(Color(white: 0.49)), lineWidth: 0.7)
        let inset = ring.boundingRect.insetBy(dx: 1.8, dy: 1.8)
        context.stroke(Path(ellipseIn: inset), with: .color(.white.opacity(0.5)), lineWidth: 0.6)
    }
}
