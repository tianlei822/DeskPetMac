import SwiftUI

struct PetInteractionFeedback: View {
    let burst: Int
    let combo: Int
    let reduceMotion: Bool

    @State private var pulses: [InteractionPulse] = []
    @State private var nextID = 0

    var body: some View {
        ZStack {
            ForEach(pulses) { pulse in
                InteractionPulseView(
                    pulse: pulse,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(width: 168, height: 168)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: burst) {
            spawnPulse()
        }
    }

    private func spawnPulse() {
        let pulse = InteractionPulse(
            id: nextID,
            strength: min(1, 0.55 + Double(combo) * 0.08),
            phase: Double(nextID % 7) * 0.73,
            isCelebration: combo >= 5
        )
        nextID += 1
        pulses.append(pulse)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            pulses.removeAll { $0.id == pulse.id }
        }
    }
}

private struct InteractionPulse: Identifiable {
    let id: Int
    let strength: Double
    let phase: Double
    let isCelebration: Bool
}

private struct InteractionPulseView: View {
    let pulse: InteractionPulse
    let reduceMotion: Bool

    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            Color.pink.opacity(0.72 * pulse.strength),
                            Color.orange.opacity(0.52 * pulse.strength),
                            .clear,
                        ],
                        center: .center
                    ),
                    lineWidth: 1.4
                )
                .frame(width: 72, height: 72)
                .scaleEffect(reduceMotion ? 1 : (expanded ? 1.55 : 0.62))
                .opacity(expanded ? 0 : 0.72)

            if pulse.isCelebration {
                Circle()
                    .stroke(
                        Color.yellow.opacity(0.72),
                        style: StrokeStyle(
                            lineWidth: 1.6,
                            lineCap: .round,
                            dash: [2, 7]
                        )
                    )
                    .frame(width: 92, height: 92)
                    .scaleEffect(reduceMotion ? 1 : (expanded ? 1.45 : 0.55))
                    .rotationEffect(.degrees(expanded && !reduceMotion ? 34 : 0))
                    .opacity(expanded ? 0 : 0.9)
            }

            ForEach(0..<sparkleCount, id: \.self) { index in
                sparkle(index: index)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.78)) {
                expanded = true
            }
        }
    }

    private var sparkleCount: Int {
        pulse.isCelebration ? 9 : 5
    }

    private func sparkle(index: Int) -> some View {
        let angle = pulse.phase + Double(index) * (.pi * 2 / Double(sparkleCount))
        let finalDistance = pulse.isCelebration ? 76.0 : 66.0
        let distance = reduceMotion ? 28.0 : (expanded ? finalDistance : 22.0)
        let x = cos(angle) * distance
        let y = sin(angle) * distance * 0.72

        return Image(
            systemName: pulse.isCelebration && index.isMultiple(of: 3)
                ? "star.fill"
                : index.isMultiple(of: 2) ? "sparkle" : "circle.fill"
        )
            .font(
                .system(
                    size: pulse.isCelebration && index.isMultiple(of: 3)
                        ? 10
                        : index.isMultiple(of: 2) ? 9 : 4,
                    weight: .bold
                )
            )
            .foregroundStyle(index.isMultiple(of: 2) ? Color.yellow : Color.pink)
            .shadow(color: .orange.opacity(0.36), radius: 3)
            .offset(x: x, y: y)
            .scaleEffect(expanded ? 0.72 : 0.35)
            .opacity(expanded ? 0 : 0.82 * pulse.strength)
    }
}
