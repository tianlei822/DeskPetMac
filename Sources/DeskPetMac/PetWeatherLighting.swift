import DeskPetCore
import SwiftUI

struct PetWeatherLighting: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        artworkLightingBody
            .frame(width: 190, height: 198)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkLightingBody: some View {
        ZStack {
            switch mood {
            case .sunny:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.11),
                                Color.yellow.opacity(0.045),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: warmLightOffset)
                    .blendMode(.screen)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.08),
                                Color.orange.opacity(0.025),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 78
                        )
                    )
                    .frame(width: 156, height: 176)
                    .offset(x: -34 + warmLightOffset, y: -22)
                    .blendMode(.screen)
            case .cloudy:
                Ellipse()
                    .fill(
                        Color(red: 0.26, green: 0.31, blue: 0.38)
                            .opacity(0.055)
                    )
                    .frame(width: 142, height: 106)
                    .blur(radius: 17)
                    .offset(x: cloudShadowOffset, y: -18)
                    .blendMode(.multiply)
            case .rainy, .stormy:
                if mood == .stormy {
                    Rectangle()
                        .fill(
                            Color(red: 0.16, green: 0.20, blue: 0.30)
                                .opacity(0.07)
                        )
                        .blendMode(.multiply)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                coolReflectionColor.opacity(
                                    mood == .stormy ? 0.055 : 0.045
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.055),
                                coolReflectionColor.opacity(
                                    kind == .pauli ? 0.105 : 0.075
                                ),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 122, height: 9)
                    .blur(radius: 2.2)
                    .offset(x: 6, y: 69)
                    .blendMode(.screen)
            case .snowy:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.86, blue: 1)
                                    .opacity(0.075),
                                Color.blue.opacity(0.025),
                                .clear,
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.72, green: 0.86, blue: 1)
                                    .opacity(0.085),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 3,
                            endRadius: 76
                        )
                    )
                    .frame(width: 152, height: 42)
                    .blur(radius: 8)
                    .offset(y: 76)
                    .blendMode(.screen)
            case .foggy:
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.48),
                                .init(
                                    color: Color(
                                        red: 0.46,
                                        green: 0.50,
                                        blue: 0.54
                                    ).opacity(0.055),
                                    location: 0.66
                                ),
                                .init(
                                    color: Color(
                                        red: 0.46,
                                        green: 0.50,
                                        blue: 0.54
                                    ).opacity(0.12),
                                    location: 1
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            case .cozy:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.095),
                                Color(red: 1, green: 0.50, blue: 0.20)
                                    .opacity(0.025),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 84
                        )
                    )
                    .frame(width: 168, height: 168)
                    .offset(x: -20 + warmLightOffset * 0.35, y: 22)
                    .blendMode(.screen)
            }
        }
    }

    private var coolReflectionColor: Color {
        Color(red: 0.38, green: 0.70, blue: 0.92)
    }

    private var warmLightOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return sin(normalizedPhase(time, period: 20) * .pi * 2) * 5
    }

    private var cloudShadowOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return sin(normalizedPhase(time, period: 18) * .pi * 2) * 13
    }

    private func normalizedPhase(_ value: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: period)
        let normalized = remainder >= 0 ? remainder : remainder + period
        return normalized / period
    }
}

struct PetWeatherAccent: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let isVisible: Bool
    let allowsAnimation: Bool

    private var reaction: PetWeatherReaction {
        WeatherSceneProfile.reaction(for: kind, mood: mood)
    }

    @ViewBuilder
    var body: some View {
        if kind != .pauli || !isVisible {
            EmptyView()
        } else {
            switch reaction {
            case .antennaGlow:
                antennaGlow
            case .visorGlow:
                visorGlow
            case .none, .settle, .headLift, .observe, .shelter, .shake, .sniff, .startle:
                EmptyView()
            }
        }
    }

    private var antennaGlow: some View {
        Circle()
            .fill(Color.mint.opacity(antennaOpacity))
            .frame(width: 17, height: 17)
            .blur(radius: 4.5)
            .offset(y: -86)
            .frame(width: 190, height: 198)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var visorGlow: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(Color.cyan.opacity(visorOpacity))
            .frame(width: 87, height: 55)
            .blur(radius: 5.5)
            .offset(y: -30)
            .frame(width: 190, height: 198)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var antennaOpacity: Double {
        guard allowsAnimation else { return 0.09 }
        if mood == .stormy {
            let period = WeatherSceneProfile(mood: mood).lightningPeriod ?? 24
            let flashTime = normalizedPhase(time, period: period) * period
            switch flashTime {
            case 0..<0.07:
                return 0.065 + (1 - flashTime / 0.07) * 0.15
            case 0.12..<0.19:
                return 0.065 + (1 - (flashTime - 0.12) / 0.07) * 0.08
            default:
                return 0.065
            }
        }
        return 0.09 + (sin(normalizedPhase(time, period: 3.6) * .pi * 2) + 1) * 0.025
    }

    private var visorOpacity: Double {
        guard allowsAnimation else { return 0.07 }
        return 0.07 + (sin(normalizedPhase(time, period: 4.2) * .pi * 2) + 1) * 0.02
    }

    private func normalizedPhase(_ value: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: period)
        let normalized = remainder >= 0 ? remainder : remainder + period
        return normalized / period
    }
}
