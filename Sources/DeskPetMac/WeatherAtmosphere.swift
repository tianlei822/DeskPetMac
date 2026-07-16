import DeskPetCore
import SwiftUI

struct WeatherBackdrop: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .back, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherForeground: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .front, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PetWeatherArtworkLight: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            switch mood {
            case .sunny:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.10),
                                Color.yellow.opacity(0.035),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            case .cloudy:
                Ellipse()
                    .fill(Color.black.opacity(0.045))
                    .frame(width: 118, height: 92)
                    .blur(radius: 14)
                    .offset(x: cloudShadowOffset, y: -18)
                    .blendMode(.multiply)
            case .rainy, .stormy:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.cyan.opacity(kind == .pauli ? 0.065 : 0.04),
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .blendMode(.screen)
            case .snowy:
                Ellipse()
                    .fill(Color.blue.opacity(0.055))
                    .frame(width: 140, height: 112)
                    .blur(radius: 18)
                    .offset(x: -28, y: -35)
                    .blendMode(.screen)
            case .foggy:
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 142, height: 54)
                    .blur(radius: 18)
                    .offset(y: 52)
                    .blendMode(.screen)
            case .cozy:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .offset(x: -18, y: 22)
                    .blendMode(.screen)
            }
        }
        .frame(width: 166, height: 170)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var cloudShadowOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return sin(normalizedPhase(time, period: 18) * .pi * 2) * 12
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
        WeatherAnimationProfile.reaction(for: kind, mood: mood)
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
            .frame(width: 15, height: 15)
            .blur(radius: 4)
            .offset(y: -76)
            .frame(width: 166, height: 170)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var visorGlow: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.cyan.opacity(visorOpacity))
            .frame(width: 76, height: 48)
            .blur(radius: 5)
            .offset(y: -18)
            .frame(width: 166, height: 170)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var antennaOpacity: Double {
        guard allowsAnimation else { return 0.09 }
        if mood == .stormy {
            let flashTime = normalizedPhase(time, period: 22) * 22
            guard flashTime < 0.08 else { return 0.065 }
            return 0.065 + (1 - flashTime / 0.08) * 0.15
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

private enum WeatherLayer: Equatable {
    case back
    case front
}

private struct WeatherAtmosphereLayer: View {
    let mood: PetWeatherMood
    let layer: WeatherLayer
    let reduceMotion: Bool

    private var profile: WeatherAnimationProfile {
        WeatherAnimationProfile(mood: mood)
    }

    private var requiresTimeline: Bool {
        switch (mood, layer) {
        case (.sunny, .front), (.cloudy, .front), (.cozy, .front):
            false
        case (.sunny, .back), (.cloudy, .back), (.foggy, _), (.rainy, _),
             (.snowy, _), (.stormy, _), (.cozy, .back):
            true
        }
    }

    @ViewBuilder
    var body: some View {
        if reduceMotion || !requiresTimeline {
            atmosphere(time: 0, moving: false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                atmosphere(
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    moving: true
                )
            }
        }
    }

    @ViewBuilder
    private func atmosphere(time: TimeInterval, moving: Bool) -> some View {
        ZStack {
            switch mood {
            case .sunny:
                sunnyAtmosphere(time: time, moving: moving)
            case .cloudy:
                cloudyAtmosphere(time: time, moving: moving)
            case .foggy:
                fogAtmosphere(time: time, moving: moving)
            case .rainy:
                rainAtmosphere(time: time)
            case .snowy:
                snowAtmosphere(time: time, moving: moving)
            case .stormy:
                stormAtmosphere(time: time, moving: moving)
            case .cozy:
                cozyAtmosphere(time: time, moving: moving)
            }
        }
        .frame(width: 172, height: 178)
        .clipped()
    }

    @ViewBuilder
    private func sunnyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .back {
            Circle()
                .fill(Color.yellow.opacity(0.10))
                .frame(width: 132, height: 132)
                .blur(radius: 28)
                .scaleEffect(moving ? 1 + sin(time * 0.75) * 0.025 : 1)
                .offset(y: 10)
        }
    }

    @ViewBuilder
    private func cloudyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .back {
            Image(systemName: "cloud.fill")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(
                    Color(red: 0.56, green: 0.63, blue: 0.70).opacity(0.24)
                )
                .offset(
                    x: -52 + (moving ? sin(time * 0.18) * 10 : 0),
                    y: -38
                )
        }
    }

    private func fogAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        let isBack = layer == .back
        let drift = moving
            ? sin(time * (isBack ? 0.14 : 0.20) + (isBack ? 0 : 1.4)) * (isBack ? 10 : 14)
            : 0

        return Capsule()
            .fill(
                Color(red: 0.60, green: 0.72, blue: 0.82)
                    .opacity(isBack ? 0.18 : 0.24)
            )
            .frame(width: isBack ? 146 : 118, height: isBack ? 14 : 10)
            .blur(radius: isBack ? 7 : 5)
            .offset(x: drift, y: isBack ? 57 : 64)
    }

    @ViewBuilder
    private func rainAtmosphere(time: TimeInterval) -> some View {
        rainParticles(time: time)

        if layer == .front, profile.showsGroundRipple {
            let phase = groundRipplePhase(time: time)
            let scale = min(1.12, max(0.88, 0.88 + phase * 0.24))
            let opacity = min(1, max(0.45, 1 - phase * 0.55))

            Ellipse()
                .stroke(Color.blue.opacity(0.16), lineWidth: 1)
                .frame(width: 72, height: 10)
                .scaleEffect(scale)
                .opacity(opacity)
                .offset(y: 69)
        }
    }

    @ViewBuilder
    private func snowAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .back {
            Ellipse()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 120, height: 18)
                .blur(radius: 12)
                .offset(y: 65)
        }

        snowParticles(time: time, moving: moving)
    }

    @ViewBuilder
    private func stormAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .back {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.indigo.opacity(0.10))
                .frame(width: 162, height: 168)
                .blur(radius: 5)
        }

        rainParticles(time: time)

        if layer == .front,
           moving,
           profile.supportsLightning,
           let period = profile.lightningPeriod {
            let flashOpacity = lightningOpacity(time: time, period: period)

            if flashOpacity > 0 {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(flashOpacity))
                    .frame(width: 162, height: 168)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Color.white.opacity(flashOpacity))
                    .offset(x: 48, y: -45)
            }
        }
    }

    @ViewBuilder
    private func cozyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .back {
            Circle()
                .fill(Color.orange.opacity(0.10))
                .frame(width: 116, height: 116)
                .blur(radius: 26)
                .scaleEffect(moving ? 1 + sin(time * 0.55) * 0.025 : 1)
                .offset(y: 18)
        }
    }

    private func rainParticles(time: TimeInterval) -> some View {
        let isBack = layer == .back
        let count = isBack ? profile.backgroundParticleCount : profile.foregroundParticleCount

        return ForEach(0..<count, id: \.self) { index in
            let salt = isBack ? 3 : 17

            Capsule()
                .fill(Color.blue.opacity(isBack ? 0.26 : 0.42))
                .frame(width: isBack ? 1.1 : 1.4, height: isBack ? 10 : 13)
                .rotationEffect(.degrees(-8))
                .offset(
                    x: normalizedPosition(index: index, salt: salt) * 158 - 79,
                    y: wrappedVerticalPosition(
                        index: index,
                        salt: salt + 7,
                        time: time,
                        speed: isBack ? 0.24 : 0.34
                    ) * 206 - 103
                )
        }
    }

    private func snowParticles(time: TimeInterval, moving: Bool) -> some View {
        let isBack = layer == .back
        let count = isBack ? profile.backgroundParticleCount : profile.foregroundParticleCount

        return ForEach(0..<count, id: \.self) { index in
            let salt = isBack ? 29 : 43
            let phase = normalizedPosition(index: index, salt: salt + 5) * .pi * 2
            let drift = moving ? sin(time * 0.65 + phase) * (isBack ? 3 : 5) : 0

            Circle()
                .fill(
                    Color(red: 0.72, green: 0.84, blue: 0.94)
                        .opacity(isBack ? 0.55 : 0.78)
                )
                .frame(width: isBack ? 3 : 4, height: isBack ? 3 : 4)
                .offset(
                    x: normalizedPosition(index: index, salt: salt) * 156 - 78 + drift,
                    y: wrappedVerticalPosition(
                        index: index,
                        salt: salt + 11,
                        time: time,
                        speed: isBack ? 0.075 : 0.105
                    ) * 202 - 101
                )
        }
    }

    private func lightningOpacity(time: TimeInterval, period: Double) -> Double {
        let flashDuration = 0.08
        let phase = euclideanModulo(time, modulus: period)
        guard phase < flashDuration else { return 0 }
        return min(0.16, max(0, 0.16 * (1 - phase / flashDuration)))
    }

    private func groundRipplePhase(time: TimeInterval) -> Double {
        euclideanModulo(time, modulus: 2.8) / 2.8
    }

    private func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private func normalizedPosition(index: Int, salt: Int) -> CGFloat {
        CGFloat((index * 37 + salt * 53 + 17) % 101) / 100
    }

    private func wrappedVerticalPosition(
        index: Int,
        salt: Int,
        time: TimeInterval,
        speed: Double
    ) -> CGFloat {
        let start = Double(normalizedPosition(index: index, salt: salt))
        return CGFloat(euclideanModulo(start + time * speed, modulus: 1))
    }
}
