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
            phase: Double(nextID % 7) * 0.73
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

            ForEach(0..<5, id: \.self) { index in
                sparkle(index: index)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.78)) {
                expanded = true
            }
        }
    }

    private func sparkle(index: Int) -> some View {
        let angle = pulse.phase + Double(index) * (.pi * 2 / 5)
        let distance = reduceMotion ? 28.0 : (expanded ? 66.0 : 22.0)
        let x = cos(angle) * distance
        let y = sin(angle) * distance * 0.72

        return Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
            .font(.system(size: index.isMultiple(of: 2) ? 9 : 4, weight: .bold))
            .foregroundStyle(index.isMultiple(of: 2) ? Color.yellow : Color.pink)
            .shadow(color: .orange.opacity(0.36), radius: 3)
            .offset(x: x, y: y)
            .scaleEffect(expanded ? 0.72 : 0.35)
            .opacity(expanded ? 0 : 0.82 * pulse.strength)
    }
}
