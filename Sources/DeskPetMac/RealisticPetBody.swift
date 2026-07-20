import AppKit
import DeskPetCore
import ImageIO
import SwiftUI

@MainActor
enum PetArtworkLoader {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 32
        cache.totalCostLimit = 64 * 1024 * 1024
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
        let cost = thumbnail.bytesPerRow * thumbnail.height
        cache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    static func hasBaseArtwork(for kind: PetKind) -> Bool {
        image(named: PetArtworkManifest(petKind: kind).base) != nil
    }

    static func preloadMotionArtwork(for kind: PetKind) async -> Bool {
        let manifest = PetArtworkManifest(petKind: kind)
        var available = Set<String>()

        for resourceName in manifest.motionResourceNames {
            guard !Task.isCancelled else { return false }
            if image(named: resourceName) != nil {
                available.insert(resourceName)
            }
            await Task.yield()
            guard !Task.isCancelled else { return false }
        }

        guard !Task.isCancelled else { return false }
        return manifest.hasCompleteMotionSet(availableResourceNames: available)
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
    let motionPreview: PetMotionEvent?

    @State private var isShowingPat = false
    @State private var patTask: Task<Void, Never>?
    @State private var patGeneration = 0
    @State private var patStartedAt: TimeInterval?
    @State private var danceStartedAt: TimeInterval?
    @State private var personalityStartedAt: TimeInterval?
    @State private var motionArtworkReadyKind: PetKind?
    @State private var motionScheduleClock = PetMotionScheduleClock()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let strongWeatherReactionActive = PetMotionDirector
                .isStrongWeatherReactionActive(weatherReaction, time: time)
            let manifest = PetArtworkManifest(petKind: kind)
            let candidateMotion = scheduledMotion(
                at: time,
                isEligible: allowsScheduledMotionBase
            )
            let motion = strongWeatherReactionActive
                ? PetMotionFrame.idle
                : candidateMotion
            let requested = requestedResourceName(
                manifest: manifest,
                time: time,
                motion: motion
            )
            let artwork = PetArtworkLoader.image(named: requested)
                ?? PetArtworkLoader.image(named: manifest.base)

            Group {
                if let artwork {
                    ZStack {
                        contactShadow(at: time, motion: motion)

                        ZStack {
                            ZStack {
                                animatedArtwork(
                                    artwork,
                                    time: time,
                                    motion: motion
                                )

                                PetWeatherLighting(
                                    kind: kind,
                                    mood: mood,
                                    time: time,
                                    reduceMotion: reduceMotion
                                )
                                .mask(artworkImage(artwork))
                            }
                            .frame(width: 190, height: 198)
                            .clipped()

                            PetWeatherAccent(
                                kind: kind,
                                mood: mood,
                                time: time,
                                isVisible: allowsWeatherAccent && motion.event == .idle,
                                allowsAnimation: allowsWeatherReaction
                            )
                        }
                        .frame(width: 190, height: 198)
                        .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
                        .scaleEffect(
                            x: composedHorizontalScale(at: time, motion: motion),
                            y: composedVerticalScale(at: time, motion: motion),
                            anchor: .bottom
                        )
                        .rotationEffect(
                            .degrees(
                                animatedTilt(at: time)
                                    + weatherTilt(at: time)
                                    + motion.tiltDegrees
                            )
                        )
                        .offset(composedOffset(at: time, motion: motion))
                    }
                }
            }
            .onChange(of: strongWeatherReactionActive) {
                if !allowsScheduledMotionBase {
                    motionScheduleClock.updateEligibility(false, at: time)
                } else if strongWeatherReactionActive {
                    motionScheduleClock.suspendForWeather(
                        at: time,
                        preservingElapsed: candidateMotion == .idle
                    )
                } else {
                    motionScheduleClock.resumeAfterWeather(at: time)
                }
            }
        }
        .frame(width: 220, height: 218)
        .task(id: kind) {
            let requestedKind = kind
            motionArtworkReadyKind = nil
            motionScheduleClock.updateEligibility(false, at: 0)
            let isComplete = await PetArtworkLoader.preloadMotionArtwork(
                for: requestedKind
            )
            guard !Task.isCancelled else { return }
            motionArtworkReadyKind = isComplete ? requestedKind : nil
        }
        .onChange(of: allowsScheduledMotionBase) {
            let time = Date().timeIntervalSinceReferenceDate
            let strongWeatherReactionActive = PetMotionDirector
                .isStrongWeatherReactionActive(weatherReaction, time: time)
            motionScheduleClock.updateEligibility(
                allowsScheduledMotionBase && !strongWeatherReactionActive,
                at: time
            )
        }
        .onChange(of: pulse) {
            patTask?.cancel()
            patGeneration += 1
            let generation = patGeneration
            patStartedAt = Date().timeIntervalSinceReferenceDate
            isShowingPat = true
            patTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(560))
                guard !Task.isCancelled, generation == patGeneration else { return }
                isShowingPat = false
                patTask = nil
            }
        }
        .onChange(of: isDancing) {
            danceStartedAt = isDancing ? Date().timeIntervalSinceReferenceDate : nil
        }
        .onChange(of: personalityPose) {
            personalityStartedAt = personalityPose == nil
                ? nil
                : Date().timeIntervalSinceReferenceDate
        }
        .onDisappear {
            patTask?.cancel()
            patTask = nil
            patGeneration += 1
            isShowingPat = false
            patStartedAt = nil
            danceStartedAt = nil
            personalityStartedAt = nil
        }
    }

    private var motionSeed: Int {
        switch kind {
        case .cat: 1_031
        case .pauli: 2_047
        case .dog: 4_093
        }
    }

    private var allowsScheduledMotionBase: Bool {
        motionArtworkReadyKind == kind
            && !isSleeping
            && !isDancing
            && personalityPose == nil
            && !isShowingPat
            && !isHovering
            && !reduceMotion
    }

    private func scheduledMotion(
        at time: TimeInterval,
        isEligible: Bool
    ) -> PetMotionFrame {
        guard isEligible else { return .idle }
        let relativeTime = motionScheduleClock.elapsed(at: time)
        if let motionPreview {
            return PetMotionDirector.previewFrame(
                pet: kind,
                event: motionPreview,
                time: relativeTime,
                reduceMotion: reduceMotion
            )
        }
        return PetMotionDirector.frame(
            pet: kind,
            time: relativeTime,
            seed: motionSeed,
            isEligible: true,
            reduceMotion: reduceMotion
        )
    }

    private func requestedResourceName(
        manifest: PetArtworkManifest,
        time: TimeInterval,
        motion: PetMotionFrame
    ) -> String {
        if isSleeping { return manifest.resourceName(for: .sleep) }
        if isShowingPat { return manifest.resourceName(for: .pat) }
        if isDancing { return manifest.base }
        if let personalityPose {
            return manifest.resourceName(for: .personality(personalityPose))
        }
        if isHovering { return manifest.resourceName(for: .hover) }
        if motion.event == .lookAround { return manifest.base }
        if motion.event != .idle {
            guard motion.usesEventArtwork else { return manifest.base }
            return manifest.resourceName(
                for: motion.event,
                frameIndex: motion.presentedArtworkFrameIndex
            )
        }
        if PetAnimationDynamics.isBlinking(for: kind, time: time) {
            return manifest.resourceName(for: .blink)
        }
        return manifest.base
    }

    private func animatedScale(at time: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }

        if isSleeping { return 1 + sin(time * 0.92) * 0.003 }
        if isShowingPat {
            return CGFloat(patPose(at: time).scale)
        }
        if isDancing {
            return CGFloat(dancePose(at: time).scale)
        }
        if personalityPose != nil { return 1 }
        if isHovering { return 1.02 }
        let idle = PetAnimationDynamics.idlePose(for: kind, time: time)
        return 1 + CGFloat(idle.scale - 1) * idleAmplitudeMultiplier
    }

    private func composedHorizontalScale(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGFloat {
        animatedScale(at: time)
            * weatherScale(at: time)
            * CGFloat(motion.horizontalScale)
    }

    private func composedVerticalScale(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGFloat {
        animatedScale(at: time)
            * weatherScale(at: time)
            * CGFloat(motion.verticalScale)
    }

    private func animatedTilt(at time: TimeInterval) -> Double {
        guard !reduceMotion else { return 0 }

        if isSleeping { return 0 }
        if isShowingPat {
            return patPose(at: time).tiltDegrees
        }
        if isDancing {
            return dancePose(at: time).tiltDegrees
        }
        if personalityPose != nil {
            return personalityTilt(at: time)
        }
        if isHovering {
            return clampedPointerOffset.width * 1.5
        }

        return PetAnimationDynamics.idlePose(for: kind, time: time).tiltDegrees
    }

    private func animatedOffset(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGSize {
        guard !reduceMotion else { return .zero }

        if isSleeping { return .zero }
        if isShowingPat {
            let pose = patPose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if isDancing {
            let pose = dancePose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if personalityPose != nil {
            return personalityOffset(at: time)
        }
        if isHovering {
            return CGSize(
                width: clampedPointerOffset.width * 3,
                height: clampedPointerOffset.height * 2
            )
        }

        guard motion.event == .idle else { return .zero }
        let idle = PetAnimationDynamics.idlePose(for: kind, time: time)
        return CGSize(
            width: idle.x,
            height: idle.y * Double(idleAmplitudeMultiplier)
        )
    }

    private var weatherReaction: PetWeatherReaction {
        WeatherSceneProfile.reaction(for: kind, mood: mood)
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
            .frame(width: 190, height: 198)
    }

    @ViewBuilder
    private func animatedArtwork(
        _ artwork: NSImage,
        time: TimeInterval,
        motion: PetMotionFrame
    ) -> some View {
        if kind == .pauli || reduceMotion || isSleeping {
            artworkImage(artwork)
        } else {
            let sway = PetAnimationDynamics.tailSwayDegrees(
                for: kind,
                time: time,
                isWalking: motion.event == .walk
            )

            ZStack {
                artworkImage(artwork)
                    .mask {
                        ZStack {
                            Rectangle().fill(.white)
                            TailTipMask(kind: kind)
                                .fill(.white)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }

                artworkImage(artwork)
                    .mask {
                        TailTipMask(kind: kind).fill(.white)
                    }
                    .rotationEffect(
                        .degrees(sway),
                        anchor: tailRotationAnchor
                    )
            }
        }
    }

    private var tailRotationAnchor: UnitPoint {
        switch kind {
        case .cat: UnitPoint(x: 0.69, y: 0.38)
        case .dog: UnitPoint(x: 0.58, y: 0.32)
        case .pauli: .center
        }
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

    private func composedOffset(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGSize {
        let existing = animatedOffset(at: time, motion: motion)
        let weather = weatherOffset(at: time)
        return CGSize(
            width: existing.width + weather.width + CGFloat(motion.horizontalOffset),
            height: existing.height + weather.height + CGFloat(motion.verticalOffset)
        )
    }

    private func contactShadow(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> some View {
        let existing = animatedOffset(at: time, motion: motion)
        let weather = weatherOffset(at: time)
        let horizontalOffset = existing.width
            + weather.width
            + CGFloat(motion.horizontalOffset)
            + CGFloat(motion.shadowOffset)

        return Ellipse()
            .fill(Color.black.opacity(0.12))
            .frame(width: 105, height: 17)
            .blur(radius: 8)
            .scaleEffect(x: CGFloat(motion.shadowScale), y: 1)
            .offset(x: horizontalOffset, y: 79)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
        let elapsed = elapsed(since: personalityStartedAt, at: time)
        return switch personalityPose {
        case .some(.peek):
            CGSize(width: sin(elapsed * 2.4) * 3, height: 0)
        case .some(.perk):
            CGSize(width: 0, height: abs(sin(elapsed * 5.8)) * -3)
        case .some(.stretch):
            CGSize(width: 0, height: sin(elapsed * 2.0) * 3)
        case .some(.proud):
            CGSize(width: sin(elapsed * 2.2) * 1.5, height: 0)
        case .none:
            .zero
        }
    }

    private func personalityTilt(at time: TimeInterval) -> Double {
        let elapsed = elapsed(since: personalityStartedAt, at: time)
        return switch personalityPose {
        case .some(.peek): sin(elapsed * 1.25) * -0.45
        case .some(.perk): sin(elapsed * 1.6) * 0.7
        case .some(.stretch): sin(elapsed * 2.0) * -1.5
        case .some(.proud): sin(elapsed * 1.6) * 1.2
        case .none: 0
        }
    }

    private func patPose(at time: TimeInterval) -> PetAnimationPose {
        PetAnimationDynamics.patPose(
            for: kind,
            elapsed: elapsed(since: patStartedAt, at: time)
        )
    }

    private func dancePose(at time: TimeInterval) -> PetAnimationPose {
        PetAnimationDynamics.dancePose(
            for: kind,
            elapsed: elapsed(since: danceStartedAt, at: time)
        )
    }

    private func elapsed(
        since start: TimeInterval?,
        at time: TimeInterval
    ) -> TimeInterval {
        guard let start, time.isFinite else { return 0 }
        return max(0, time - start)
    }
}

private struct TailTipMask: Shape {
    let kind: PetKind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .cat:
            path.move(to: CGPoint(x: rect.width * 0.50, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.44))
            path.addLine(to: CGPoint(x: rect.width * 0.67, y: rect.height * 0.44))
            path.addLine(to: CGPoint(x: rect.width * 0.67, y: rect.height * 0.18))
            path.addLine(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.18))
            path.closeSubpath()
        case .dog:
            path.addRoundedRect(
                in: CGRect(
                    x: rect.width * 0.38,
                    y: 0,
                    width: rect.width * 0.40,
                    height: rect.height * 0.27
                ),
                cornerSize: CGSize(width: 12, height: 12)
            )
        case .pauli:
            break
        }
        return path
    }
}
