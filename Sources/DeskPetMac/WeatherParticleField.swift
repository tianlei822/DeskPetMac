import DeskPetCore
import SwiftUI

struct WeatherParticleField: View {
    let mood: PetWeatherMood
    let profile: WeatherSceneProfile
    let depth: WeatherDepth
    let seeds: [WeatherParticleSeed]
    let time: TimeInterval
    let moving: Bool
    let reduceMotion: Bool

    private var depthProfile: WeatherDepthProfile {
        profile.particleProfile(for: depth, reduceMotion: reduceMotion)
    }

    var body: some View {
        Canvas { context, size in
            for particle in seeds {
                var particleContext = context
                let state = particle.state(
                    at: time,
                    speed: depthProfile.speed,
                    wind: animatedWind(for: particle),
                    moving: moving
                )
                let point = CGPoint(
                    x: CGFloat(state.x) * size.width,
                    y: CGFloat(state.y) * size.height
                )

                switch mood {
                case .rainy, .stormy:
                    drawRain(particle, at: point, in: &particleContext)
                case .snowy:
                    drawSnow(particle, at: point, in: &particleContext)
                case .sunny, .cozy:
                    drawMote(particle, at: point, in: &particleContext)
                case .cloudy, .foggy:
                    break
                }
            }

            if depth == .foreground,
               profile.showsGroundFeedback(reduceMotion: reduceMotion) {
                drawGroundFeedback(in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func makeSeeds(
        mood: PetWeatherMood,
        profile: WeatherSceneProfile,
        depth: WeatherDepth,
        reduceMotion: Bool
    ) -> [WeatherParticleSeed] {
        WeatherParticleLayout.particles(
            count: profile.particleProfile(
                for: depth,
                reduceMotion: reduceMotion
            ).count,
            seed: UInt64(seedBase(for: mood) + depth.rawValue * 1_009),
            depth: depth
        )
    }

    private func drawRain(
        _ particle: WeatherParticleSeed,
        at point: CGPoint,
        in context: inout GraphicsContext
    ) {
        let length = CGFloat(interpolate(depthProfile.size, unit: particle.sizeUnit))
        let opacity = interpolate(depthProfile.opacity, unit: particle.opacityUnit)
        let blur = CGFloat(interpolate(depthProfile.blur, unit: particle.blurUnit))
        context.addFilter(.blur(radius: blur))

        var path = Path()
        path.move(to: point)
        path.addLine(
            to: CGPoint(
                x: point.x + CGFloat(profile.wind) * length * 0.8,
                y: point.y + length
            )
        )
        context.stroke(
            path,
            with: .color(
                Color(red: 0.55, green: 0.76, blue: 0.95).opacity(opacity)
            ),
            style: StrokeStyle(
                lineWidth: depth == .foreground ? 1.5 : 1,
                lineCap: .round
            )
        )

        if depth == .foreground {
            let highlight = context
            highlight.stroke(
                path,
                with: .color(Color.white.opacity(opacity * 0.18)),
                style: StrokeStyle(lineWidth: 0.45, lineCap: .round)
            )
        }
    }

    private func drawSnow(
        _ particle: WeatherParticleSeed,
        at point: CGPoint,
        in context: inout GraphicsContext
    ) {
        let diameter = CGFloat(interpolate(depthProfile.size, unit: particle.sizeUnit))
        let opacity = interpolate(depthProfile.opacity, unit: particle.opacityUnit)
        let blur = CGFloat(interpolate(depthProfile.blur, unit: particle.blurUnit))
        context.addFilter(.blur(radius: blur))

        let rect = CGRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .color(
                Color(red: 0.80, green: 0.90, blue: 1).opacity(opacity)
            )
        )

        if depth == .foreground, diameter >= 5 {
            let glint = CGRect(
                x: point.x - diameter * 0.15,
                y: point.y - diameter * 0.28,
                width: diameter * 0.24,
                height: diameter * 0.24
            )
            context.fill(
                Path(ellipseIn: glint),
                with: .color(Color.white.opacity(opacity * 0.55))
            )
        }
    }

    private func drawMote(
        _ particle: WeatherParticleSeed,
        at point: CGPoint,
        in context: inout GraphicsContext
    ) {
        let diameter = CGFloat(interpolate(depthProfile.size, unit: particle.sizeUnit))
        let opacity = interpolate(depthProfile.opacity, unit: particle.opacityUnit)
        let blur = CGFloat(interpolate(depthProfile.blur, unit: particle.blurUnit))
        let color = mood == .sunny ? Color.yellow : Color.orange
        context.addFilter(.blur(radius: blur))
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
            ),
            with: .color(color.opacity(opacity))
        )
    }

    private func drawGroundFeedback(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        if profile.showsSplashes {
            var wetContext = context
            drawWetSurface(in: &wetContext, size: size)
            var splashContext = context
            drawRainSplashes(in: &splashContext, size: size)
        }

        if profile.showsSnowGroundLight {
            var lightContext = context
            let rect = CGRect(
                x: size.width * 0.22,
                y: size.height * 0.82,
                width: size.width * 0.56,
                height: 18
            )
            lightContext.addFilter(.blur(radius: 9))
            lightContext.fill(
                Path(ellipseIn: rect),
                with: .color(Color.blue.opacity(0.12))
            )

            lightContext.fill(
                Path(
                    ellipseIn: CGRect(
                        x: size.width * 0.34,
                        y: size.height * 0.835,
                        width: size.width * 0.35,
                        height: 10
                    )
                ),
                with: .color(Color.white.opacity(0.08))
            )
        }
    }

    private func drawWetSurface(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let rect = CGRect(
            x: size.width * 0.16,
            y: size.height * 0.80,
            width: size.width * 0.68,
            height: 28
        )
        context.addFilter(.blur(radius: 7))
        context.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.36, green: 0.68, blue: 0.88).opacity(0.03),
                    Color(red: 0.54, green: 0.78, blue: 0.94).opacity(0.12),
                    .clear,
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.midY),
                endPoint: CGPoint(x: rect.maxX, y: rect.midY)
            )
        )
    }

    private func drawRainSplashes(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        for index in 0..<5 {
            let phase = splashPhase(offset: Double(index) * 0.19)
            let centerX = size.width * (0.20 + CGFloat(index) * 0.15)
            let rect = CGRect(
                x: centerX - 7 - phase * 6,
                y: size.height * (0.84 + CGFloat(index % 2) * 0.025),
                width: 14 + phase * 12,
                height: 4 + phase * 3
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(
                    Color.blue.opacity(0.22 * Double(1 - phase))
                ),
                lineWidth: 1
            )
        }
    }

    private func splashPhase(offset: Double) -> CGFloat {
        guard moving else { return CGFloat(0.35 + offset * 0.3) }
        let duration = 2.4
        let remainder = (time / duration + offset).truncatingRemainder(dividingBy: 1)
        return CGFloat(remainder >= 0 ? remainder : remainder + 1)
    }

    private func animatedWind(for particle: WeatherParticleSeed) -> Double {
        guard moving else { return profile.wind }
        let gust = 0.84 + sin(time * 0.72 + particle.phase * .pi * 2) * 0.16
        return profile.wind * gust
    }

    private func interpolate(_ range: ClosedRange<Double>, unit: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    private static func seedBase(for mood: PetWeatherMood) -> Int {
        switch mood {
        case .sunny: 101
        case .cloudy: 211
        case .foggy: 307
        case .rainy: 401
        case .snowy: 503
        case .stormy: 601
        case .cozy: 701
        }
    }
}
