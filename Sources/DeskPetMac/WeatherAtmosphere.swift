import DeskPetCore
import SwiftUI

struct WeatherBackdrop: View {
    let mood: PetWeatherMood
    let pointerOffset: CGSize
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(
            mood: mood,
            layer: .background,
            pointerOffset: pointerOffset,
            reduceMotion: reduceMotion
        )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherMidground: View {
    let mood: PetWeatherMood
    let pointerOffset: CGSize
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(
            mood: mood,
            layer: .midground,
            pointerOffset: pointerOffset,
            reduceMotion: reduceMotion
        )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherForeground: View {
    let mood: PetWeatherMood
    let pointerOffset: CGSize
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(
            mood: mood,
            layer: .foreground,
            pointerOffset: pointerOffset,
            reduceMotion: reduceMotion
        )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private enum WeatherLayer: Equatable {
    case background
    case midground
    case foreground

    var depth: WeatherDepth {
        switch self {
        case .background: .background
        case .midground: .midground
        case .foreground: .foreground
        }
    }
}

private struct WeatherAtmosphereLayer: View {
    let mood: PetWeatherMood
    let layer: WeatherLayer
    let pointerOffset: CGSize
    let reduceMotion: Bool
    private let profile: WeatherSceneProfile
    private let particleSeeds: [WeatherParticleSeed]

    init(
        mood: PetWeatherMood,
        layer: WeatherLayer,
        pointerOffset: CGSize,
        reduceMotion: Bool
    ) {
        self.mood = mood
        self.layer = layer
        self.pointerOffset = pointerOffset
        self.reduceMotion = reduceMotion

        let profile = WeatherSceneProfile(mood: mood)
        self.profile = profile
        self.particleSeeds = WeatherParticleField.makeSeeds(
            mood: mood,
            profile: profile,
            depth: layer.depth,
            reduceMotion: reduceMotion
        )
    }

    private var requiresTimeline: Bool {
        if !particleSeeds.isEmpty { return true }
        if mood == .foggy { return true }
        return mood == .cloudy && layer != .foreground
    }

    @ViewBuilder
    var body: some View {
        Group {
            if profile.renderingMode(reduceMotion: reduceMotion) == .staticCue || !requiresTimeline {
                atmosphere(time: 0, moving: false)
            } else {
                TimelineView(
                    .animation(minimumInterval: 1.0 / profile.maximumFramesPerSecond)
                ) { timeline in
                    atmosphere(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        moving: true
                    )
                }
            }
        }
        .offset(parallaxOffset)
    }

    private var parallaxOffset: CGSize {
        guard !reduceMotion else { return .zero }
        let strength: CGFloat = switch layer {
        case .background: -2.4
        case .midground: -0.8
        case .foreground: 1.8
        }
        return CGSize(
            width: pointerOffset.width * strength,
            height: pointerOffset.height * strength * 0.55
        )
    }

    @ViewBuilder
    private func atmosphere(time: TimeInterval, moving: Bool) -> some View {
        ZStack {
            atmosphereBase(time: time, moving: moving)

            WeatherParticleField(
                mood: mood,
                profile: profile,
                depth: layer.depth,
                seeds: particleSeeds,
                time: time,
                moving: moving,
                reduceMotion: reduceMotion
            )

            stormFlash(time: time, moving: moving)
        }
        .frame(width: 220, height: 218)
        .clipped()
    }

    @ViewBuilder
    private func atmosphereBase(time: TimeInterval, moving: Bool) -> some View {
        switch mood {
        case .sunny:
            sunnyAtmosphere(time: time, moving: moving)
        case .cloudy:
            cloudyAtmosphere(time: time, moving: moving)
        case .foggy:
            fogAtmosphere(time: time, moving: moving)
        case .rainy:
            precipitationAtmosphere(time: time, moving: moving, stormy: false)
        case .snowy:
            snowyAtmosphere(time: time, moving: moving)
        case .stormy:
            ZStack {
                precipitationAtmosphere(time: time, moving: moving, stormy: true)
                stormBase()
            }
        case .cozy:
            cozyAtmosphere(time: time, moving: moving)
        }
    }

    @ViewBuilder
    private func sunnyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .background {
            Canvas { context, size in
                let rayGradient = Gradient(
                    colors: [Color.yellow.opacity(0.16), .clear]
                )
                context.fill(
                    Path(
                        CGRect(
                            x: -20,
                            y: -20,
                            width: size.width * 0.72,
                            height: size.height * 1.1
                        )
                    ),
                    with: .linearGradient(
                        rayGradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(
                            x: size.width * 0.64,
                            y: size.height
                        )
                    )
                )

                let sourceRect = CGRect(x: -36, y: -38, width: 118, height: 118)
                context.fill(
                    Path(ellipseIn: sourceRect),
                    with: .radialGradient(
                        Gradient(
                            colors: [
                                Color.yellow.opacity(0.18),
                                Color.orange.opacity(0.045),
                                .clear,
                            ]
                        ),
                        center: CGPoint(x: 20, y: 18),
                        startRadius: 2,
                        endRadius: 59
                    )
                )
            }
                .scaleEffect(moving ? 1 + sin(time * 0.75) * 0.025 : 1)
        }
    }

    @ViewBuilder
    private func cloudyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .background {
            Canvas { context, size in
                let firstDrift = moving
                    ? sin(normalizedPhase(time, period: 19) * .pi * 2) * 9
                    : 0
                var firstContext = context
                drawCloudMass(
                    in: &firstContext,
                    size: size,
                    center: CGPoint(
                        x: size.width * 0.17 + firstDrift,
                        y: size.height * 0.20
                    ),
                    scale: 0.94,
                    opacity: 0.13
                )

                let secondDrift = moving
                    ? sin(normalizedPhase(time, period: 29) * .pi * 2) * -12
                    : 0
                var secondContext = context
                drawCloudMass(
                    in: &secondContext,
                    size: size,
                    center: CGPoint(
                        x: size.width * 0.82 + secondDrift,
                        y: size.height * 0.31
                    ),
                    scale: 0.72,
                    opacity: 0.10
                )
            }
        } else if layer == .midground {
            Canvas { context, size in
                let drift = moving
                    ? sin(normalizedPhase(time, period: 37) * .pi * 2) * 14
                    : 0
                var cloudContext = context
                drawCloudMass(
                    in: &cloudContext,
                    size: size,
                    center: CGPoint(
                        x: size.width * 0.44 + drift,
                        y: size.height * 0.42
                    ),
                    scale: 0.58,
                    opacity: 0.055
                )
            }
        }
    }

    private func fogAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        Canvas { context, size in
            let settings = fogBandSettings(size: size)
            let drift = moving
                ? sin(normalizedPhase(time, period: settings.period) * .pi * 2)
                    * settings.amplitude
                : 0
            var bandContext = context
            drawFogBand(
                in: &bandContext,
                size: size,
                y: settings.y,
                drift: drift,
                opacity: settings.opacity,
                blur: settings.blur
            )
        }
    }

    private func precipitationAtmosphere(
        time: TimeInterval,
        moving: Bool,
        stormy: Bool
    ) -> some View {
        Canvas { context, size in
            switch layer {
            case .background:
                let tintOpacity = stormy ? 0.105 : 0.06
                context.fill(
                    Path(
                        roundedRect: CGRect(
                            x: size.width * 0.08,
                            y: size.height * 0.04,
                            width: size.width * 0.84,
                            height: size.height * 0.82
                        ),
                        cornerRadius: 42
                    ),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.20, green: 0.29, blue: 0.40)
                                .opacity(tintOpacity),
                            Color(red: 0.42, green: 0.57, blue: 0.67)
                                .opacity(tintOpacity * 0.42),
                            .clear,
                        ]),
                        startPoint: CGPoint(x: size.width * 0.5, y: 0),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)
                    )
                )

                let firstDrift = moving
                    ? sin(normalizedPhase(time, period: stormy ? 11 : 23) * .pi * 2) * 10
                    : 0
                var firstCloud = context
                drawCloudMass(
                    in: &firstCloud,
                    size: size,
                    center: CGPoint(x: size.width * 0.24 + firstDrift, y: size.height * 0.13),
                    scale: stormy ? 1.08 : 0.90,
                    opacity: stormy ? 0.18 : 0.105
                )

                let secondDrift = moving
                    ? sin(normalizedPhase(time, period: stormy ? 15 : 31) * .pi * 2) * -13
                    : 0
                var secondCloud = context
                drawCloudMass(
                    in: &secondCloud,
                    size: size,
                    center: CGPoint(x: size.width * 0.78 + secondDrift, y: size.height * 0.24),
                    scale: stormy ? 0.88 : 0.70,
                    opacity: stormy ? 0.15 : 0.08
                )
            case .midground:
                var hazeContext = context
                hazeContext.addFilter(.blur(radius: 12))
                let drift = moving
                    ? sin(normalizedPhase(time, period: 17) * .pi * 2) * 8
                    : 0
                hazeContext.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: -22 + drift,
                            y: size.height * 0.49,
                            width: size.width + 44,
                            height: 42
                        )
                    ),
                    with: .color(
                        Color(red: 0.48, green: 0.64, blue: 0.73)
                            .opacity(stormy ? 0.045 : 0.032)
                    )
                )
            case .foreground:
                break
            }
        }
    }

    private func snowyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        Canvas { context, size in
            switch layer {
            case .background:
                let center = CGPoint(x: size.width * 0.52, y: size.height * 0.38)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 94, y: center.y - 86, width: 188, height: 172)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.70, green: 0.84, blue: 0.94).opacity(0.09),
                            Color(red: 0.52, green: 0.68, blue: 0.82).opacity(0.025),
                            .clear,
                        ]),
                        center: center,
                        startRadius: 4,
                        endRadius: 94
                    )
                )

                let drift = moving
                    ? sin(normalizedPhase(time, period: 34) * .pi * 2) * 8
                    : 0
                var cloudContext = context
                drawCloudMass(
                    in: &cloudContext,
                    size: size,
                    center: CGPoint(x: size.width * 0.52 + drift, y: size.height * 0.13),
                    scale: 0.92,
                    opacity: 0.065
                )
            case .midground:
                var veilContext = context
                veilContext.addFilter(.blur(radius: 13))
                veilContext.fill(
                    Path(ellipseIn: CGRect(x: -10, y: size.height * 0.58, width: size.width + 20, height: 38)),
                    with: .color(Color.white.opacity(0.025))
                )
            case .foreground:
                var driftContext = context
                driftContext.addFilter(.blur(radius: 5))
                driftContext.fill(
                    Path(ellipseIn: CGRect(x: size.width * 0.10, y: size.height * 0.84, width: size.width * 0.80, height: 20)),
                    with: .color(Color(red: 0.72, green: 0.86, blue: 1).opacity(0.075))
                )
            }
        }
    }

    @ViewBuilder
    private func stormBase() -> some View {
        if layer == .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.12),
                            Color.blue.opacity(0.035),
                            Color.black.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 162, height: 168)
                .blur(radius: 5)
        }
    }

    @ViewBuilder
    private func stormFlash(time: TimeInterval, moving: Bool) -> some View {
        if layer == .foreground,
           mood == .stormy,
           profile.supportsLightning {
            Canvas { context, size in
                let opacity = lightningOpacity(time: time, moving: moving)
                guard opacity > 0 else { return }

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(
                            colors: [
                                Color.white.opacity(opacity),
                                Color(
                                    red: 0.66,
                                    green: 0.78,
                                    blue: 1
                                ).opacity(opacity * 0.72),
                                .clear,
                            ]
                        ),
                        startPoint: CGPoint(x: size.width, y: 0),
                        endPoint: CGPoint(x: size.width * 0.18, y: size.height)
                    )
                )
                drawLightningBranch(
                    in: &context,
                    size: size,
                    opacity: opacity
                )
            }
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private func cozyAtmosphere(time: TimeInterval, moving: Bool) -> some View {
        if layer == .background {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.57)
                let rect = CGRect(
                    x: center.x - 58,
                    y: center.y - 58,
                    width: 116,
                    height: 116
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(
                            colors: [
                                Color.orange.opacity(0.13),
                                Color(red: 1, green: 0.55, blue: 0.25)
                                    .opacity(0.045),
                                .clear,
                            ]
                        ),
                        center: center,
                        startRadius: 3,
                        endRadius: 58
                    )
                )
            }
                .scaleEffect(moving ? 1 + sin(time * 0.55) * 0.025 : 1)
        }
    }

    private func drawCloudMass(
        in context: inout GraphicsContext,
        size _: CGSize,
        center: CGPoint,
        scale: CGFloat,
        opacity: Double
    ) {
        let lobes: [(CGFloat, CGFloat, CGFloat)] = [
            (-32, 4, 24),
            (-13, -8, 31),
            (12, -12, 36),
            (37, 2, 25),
            (3, 10, 44),
        ]
        context.addFilter(.blur(radius: 8 * scale))
        for lobe in lobes {
            let diameter = lobe.2 * scale
            let rect = CGRect(
                x: center.x + lobe.0 * scale - diameter / 2,
                y: center.y + lobe.1 * scale - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(
                    Color(red: 0.46, green: 0.53, blue: 0.62)
                        .opacity(opacity)
                )
            )
        }
    }

    private func drawFogBand(
        in context: inout GraphicsContext,
        size: CGSize,
        y: CGFloat,
        drift: CGFloat,
        opacity: Double,
        blur: CGFloat
    ) {
        context.addFilter(.blur(radius: blur))
        for index in 0..<6 {
            let width = size.width * (0.22 + CGFloat(index % 3) * 0.04)
            let height = 18 + CGFloat(index % 2) * 7
            let x = CGFloat(index) * size.width * 0.16 - size.width * 0.10 + drift
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: x,
                        y: y + CGFloat(index % 2) * 4,
                        width: width,
                        height: height
                    )
                ),
                with: .color(
                    Color(red: 0.64, green: 0.75, blue: 0.84)
                        .opacity(opacity)
                )
            )
        }
    }

    private func fogBandSettings(
        size: CGSize
    ) -> (
        y: CGFloat,
        period: Double,
        amplitude: CGFloat,
        opacity: Double,
        blur: CGFloat
    ) {
        switch layer {
        case .background:
            (
                y: size.height * 0.42,
                period: 17,
                amplitude: 9,
                opacity: 0.10,
                blur: 9
            )
        case .midground:
            (
                y: size.height * 0.58,
                period: 23,
                amplitude: -12,
                opacity: 0.13,
                blur: 7
            )
        case .foreground:
            (
                y: size.height * 0.72,
                period: 31,
                amplitude: 15,
                opacity: 0.17,
                blur: 5
            )
        }
    }

    private func drawLightningBranch(
        in context: inout GraphicsContext,
        size: CGSize,
        opacity: Double
    ) {
        guard opacity > 0 else { return }
        var path = Path()
        path.move(to: CGPoint(x: size.width * 0.91, y: size.height * 0.06))
        path.addLine(to: CGPoint(x: size.width * 0.84, y: size.height * 0.22))
        path.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.32))
        path.addLine(to: CGPoint(x: size.width * 0.79, y: size.height * 0.48))
        path.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.59))
        path.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.73))
        context.stroke(
            path,
            with: .color(Color.white.opacity(opacity * 0.72)),
            lineWidth: 1.2
        )
    }

    private func lightningOpacity(time: TimeInterval, moving: Bool) -> Double {
        guard moving, let period = profile.lightningPeriod else { return 0 }
        let phase = euclideanModulo(time, modulus: period)
        switch phase {
        case 0..<0.07:
            return 0.19 * (1 - phase / 0.07)
        case 0.12..<0.19:
            return 0.10 * (1 - (phase - 0.12) / 0.07)
        default:
            return 0
        }
    }

    private func normalizedPhase(_ value: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        return euclideanModulo(value, modulus: period) / period
    }

    private func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
