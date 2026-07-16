import AppKit
import DeskPetCore
import ImageIO
import SwiftUI

@MainActor
enum PetArtworkLoader {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 6
        return cache
    }()
    private static var unavailableResources = Set<String>()

    private static var resourceBundle: Bundle? {
        if let resources = Bundle.main.resourceURL,
           let bundle = Bundle(
               url: resources.appendingPathComponent("DeskPetMac_DeskPetMac.bundle")
           ) {
            return bundle
        }

        #if DEBUG
        return Bundle.module
        #else
        return nil
        #endif
    }

    static func image(named resourceName: String) -> NSImage? {
        let cacheKey = resourceName as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard !unavailableResources.contains(resourceName) else { return nil }

        let components = resourceName.split(separator: "/")
        guard let filename = components.last else {
            unavailableResources.insert(resourceName)
            return nil
        }

        let subdirectory = components.dropLast().joined(separator: "/")
        guard let url = resourceBundle?.url(
            forResource: String(filename),
            withExtension: "png",
            subdirectory: subdirectory
        ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            unavailableResources.insert(resourceName)
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            unavailableResources.insert(resourceName)
            return nil
        }

        let image = NSImage(
            cgImage: thumbnail,
            size: NSSize(width: thumbnail.width, height: thumbnail.height)
        )
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    static func hasBaseArtwork(for kind: PetKind) -> Bool {
        image(named: PetArtworkManifest(petKind: kind).base) != nil
    }
}

struct RealisticPetBody: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let isHovering: Bool
    let pulse: Int
    let isSleeping: Bool
    let isDancing: Bool
    let personalityPose: PersonalityPose?
    let pointerOffset: CGSize
    let reduceMotion: Bool

    @State private var isShowingPat = false
    @State private var patTask: Task<Void, Never>?
    @State private var patGeneration = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let manifest = PetArtworkManifest(petKind: kind)
            let requested = manifest.resourceName(for: presentationState(at: time))
            let artwork = PetArtworkLoader.image(named: requested)
                ?? PetArtworkLoader.image(named: manifest.base)

            if let artwork {
                ZStack {
                    artworkImage(artwork)

                    PetWeatherArtworkLight(
                        kind: kind,
                        mood: mood,
                        time: time,
                        reduceMotion: reduceMotion
                    )
                    .mask(artworkImage(artwork))

                    PetWeatherAccent(
                        kind: kind,
                        mood: mood,
                        time: time,
                        isVisible: allowsWeatherAccent,
                        allowsAnimation: allowsWeatherReaction
                    )
                }
                .frame(width: 166, height: 170)
                .clipped()
                .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
                .scaleEffect(animatedScale(at: time) * weatherScale(at: time))
                .rotationEffect(.degrees(animatedTilt(at: time) + weatherTilt(at: time)))
                .offset(composedOffset(at: time))
            }
        }
        .frame(width: 172, height: 178)
        .onChange(of: pulse) {
            patTask?.cancel()
            patGeneration += 1
            let generation = patGeneration
            isShowingPat = true
            patTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, generation == patGeneration else { return }
                isShowingPat = false
                patTask = nil
            }
        }
        .onDisappear {
            patTask?.cancel()
            patTask = nil
            patGeneration += 1
            isShowingPat = false
        }
    }

    private func presentationState(at time: TimeInterval) -> PetPresentationState {
        if isSleeping { return .sleep }
        if let personalityPose { return .personality(personalityPose) }
        if isShowingPat { return .pat }
        if isHovering { return .hover }
        if Int(time * 1.2).isMultiple(of: 7) { return .blink }
        return .idle
    }

    private func animatedScale(at time: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }

        let breathing = sin(time * idleFrequency) * 0.005 * idleAmplitudeMultiplier
        let hoverEmphasis = isHovering ? 0.02 : 0
        let pulseEmphasis = pulse.isMultiple(of: 2) ? 0 : 0.01
        return 1 + breathing + hoverEmphasis + pulseEmphasis
    }

    private func animatedTilt(at time: TimeInterval) -> Double {
        guard !reduceMotion else { return 0 }

        if isDancing {
            return sin(time * 9.0) * 7.0
        }

        let idleTilt: Double = switch kind {
        case .cat: sin(time * 0.9) * 0.7
        case .pauli: sin(time * 1.6) * 0.5
        case .dog: sin(time * 3.4) * 0.9
        }
        let hoverTilt = isHovering ? clampedPointerOffset.width * 1.5 : 0
        return idleTilt + personalityTilt(at: time) + hoverTilt
    }

    private func animatedOffset(at time: TimeInterval) -> CGSize {
        guard !reduceMotion else { return .zero }

        if isDancing {
            return CGSize(width: 0, height: abs(sin(time * 9.0)) * -7.0)
        }

        let idleHeight: CGFloat = switch kind {
        case .cat: sin(time * 2.0) * 1.5 * idleAmplitudeMultiplier
        case .pauli: sin(time * 2.8) * 2.0 * idleAmplitudeMultiplier
        case .dog: sin(time * 2.3) * 1.8 * idleAmplitudeMultiplier
        }
        let personality = personalityOffset(at: time)
        let hover = isHovering
            ? CGSize(
                width: clampedPointerOffset.width * 3,
                height: clampedPointerOffset.height * 2
            )
            : .zero
        return CGSize(
            width: personality.width + hover.width,
            height: idleHeight + personality.height + hover.height
        )
    }

    private var idleFrequency: Double {
        switch kind {
        case .cat: 2.0
        case .pauli: 2.8
        case .dog: 2.3
        }
    }

    private var weatherReaction: PetWeatherReaction {
        WeatherAnimationProfile.reaction(for: kind, mood: mood)
    }

    private var allowsWeatherAccent: Bool {
        !isSleeping
            && !isDancing
            && personalityPose == nil
            && !isShowingPat
            && !isHovering
    }

    private var allowsWeatherReaction: Bool {
        allowsWeatherAccent && !reduceMotion
    }

    private var idleAmplitudeMultiplier: CGFloat {
        guard allowsWeatherReaction else { return 1 }
        switch mood {
        case .cloudy: return 0.68
        case .snowy: return 0.76
        case .sunny, .foggy, .rainy, .stormy, .cozy: return 1
        }
    }

    private func artworkImage(_ artwork: NSImage) -> some View {
        Image(nsImage: artwork)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 166, height: 170)
    }

    private func weatherScale(at time: TimeInterval) -> CGFloat {
        guard allowsWeatherReaction else { return 1 }
        switch weatherReaction {
        case .settle:
            return 0.998 + sin(normalizedPhase(time, period: 7) * .pi * 2) * 0.001
        case .shelter:
            return 0.994
        case .headLift, .sniff:
            return 1.002
        case .none, .observe, .antennaGlow, .visorGlow, .shake, .startle:
            return 1
        }
    }

    private func weatherTilt(at time: TimeInterval) -> Double {
        guard allowsWeatherReaction else { return 0 }
        switch weatherReaction {
        case .observe:
            return sin(normalizedPhase(time, period: 9) * .pi * 2) * 1.2
        case .shake:
            let phase = normalizedPhase(time, period: 16)
            guard phase < 0.08 else { return 0 }
            let progress = phase / 0.08
            let envelope = sin(progress * .pi)
            return sin(progress * .pi * 6) * envelope * 2.4
        case .startle:
            let phase = normalizedPhase(time, period: 22)
            guard phase < 0.05 else { return 0 }
            let envelope = cos((phase / 0.05) * .pi / 2)
            return (kind == .cat ? -1 : 1) * envelope * 1.8
        case .none, .settle, .headLift, .shelter, .antennaGlow, .visorGlow, .sniff:
            return 0
        }
    }

    private func composedOffset(at time: TimeInterval) -> CGSize {
        let existing = animatedOffset(at: time)
        let weather = weatherOffset(at: time)
        return CGSize(
            width: existing.width + weather.width,
            height: existing.height + weather.height
        )
    }

    private func weatherOffset(at time: TimeInterval) -> CGSize {
        guard allowsWeatherReaction else { return .zero }
        switch weatherReaction {
        case .observe:
            return CGSize(
                width: sin(normalizedPhase(time, period: 9) * .pi * 2) * 1.1,
                height: 0
            )
        case .headLift, .sniff:
            return CGSize(width: 0, height: -1)
        case .shelter:
            return CGSize(width: 0, height: 1.2)
        case .shake:
            let phase = normalizedPhase(time, period: 16)
            guard phase < 0.08 else { return .zero }
            let progress = phase / 0.08
            let envelope = sin(progress * .pi)
            return CGSize(
                width: sin(progress * .pi * 6) * envelope * 1.8,
                height: 0
            )
        case .startle:
            let phase = normalizedPhase(time, period: 22)
            guard phase < 0.05 else { return .zero }
            let envelope = cos((phase / 0.05) * .pi / 2)
            return CGSize(width: 0, height: -2 * envelope)
        case .none, .settle, .antennaGlow, .visorGlow:
            return .zero
        }
    }

    private func normalizedPhase(_ time: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let remainder = time.truncatingRemainder(dividingBy: period)
        let normalized = remainder >= 0 ? remainder : remainder + period
        return normalized / period
    }

    private var clampedPointerOffset: CGSize {
        CGSize(
            width: min(1, max(-1, pointerOffset.width)),
            height: min(1, max(-1, pointerOffset.height))
        )
    }

    private func personalityOffset(at time: TimeInterval) -> CGSize {
        switch personalityPose {
        case .some(.peek):
            CGSize(width: sin(time * 2.4) * 3, height: 0)
        case .some(.perk):
            CGSize(width: 0, height: abs(sin(time * 5.8)) * -3)
        case .some(.stretch):
            CGSize(width: 0, height: sin(time * 2.0) * 3)
        case .some(.proud):
            CGSize(width: sin(time * 2.2) * 1.5, height: 0)
        case .none:
            .zero
        }
    }

    private func personalityTilt(at time: TimeInterval) -> Double {
        switch personalityPose {
        case .some(.peek): sin(time * 2.4) * -3
        case .some(.perk): sin(time * 2.8) * 2
        case .some(.stretch): sin(time * 2.0) * -1.5
        case .some(.proud): sin(time * 2.2) * 3
        case .none: 0
        }
    }
}
