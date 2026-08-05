import AppKit
import DeskPetCore
import ImageIO
import SwiftUI

struct PetArtworkBlend {
    static let minimumBridgeOpacity = 0.82

    let baseOpacity: Double
    let currentOpacity: Double
    let nextOpacity: Double

    init(motion: PetMotionFrame) {
        let eventOpacity = min(1, max(0, motion.artworkOpacity))
        let distanceFromSwitch = min(1, abs(eventOpacity - 0.5) * 2)
        let easedDistance = distanceFromSwitch * distanceFromSwitch
            * (3 - 2 * distanceFromSwitch)
        let selectedOpacity = Self.minimumBridgeOpacity
            + (1 - Self.minimumBridgeOpacity) * easedDistance

        if motion.usesEventArtwork {
            baseOpacity = 0
            currentOpacity = selectedOpacity
        } else {
            baseOpacity = selectedOpacity
            currentOpacity = 0
        }
        // Full-body raster frames have slightly different head registration.
        // Presenting both at once creates a visible doubled or detached head.
        nextOpacity = 0
    }
}

enum PetTailArtworkPolicy {
    static func supportsIndependentTail(
        kind: PetKind,
        resourceName: String
    ) -> Bool {
        guard kind == .cat || kind == .dog else { return false }
        let manifest = PetArtworkManifest(petKind: kind)
        return resourceName == manifest.base || resourceName == manifest.blink
    }
}

struct PetTailPose: Equatable {
    let midDegrees: Double
    let tipDegrees: Double

    static let neutral = PetTailPose(midDegrees: 0, tipDegrees: 0)
}

enum PetTailMotion {
    static func pose(
        for kind: PetKind,
        time: TimeInterval,
        energy: Double,
        curiosity: Double,
        socialNeed: Double
    ) -> PetTailPose {
        guard time.isFinite,
              energy.isFinite,
              curiosity.isFinite,
              socialNeed.isFinite else { return .neutral }

        let safeEnergy = clampUnit(energy)
        let safeCuriosity = clampUnit(curiosity)
        let safeSocialNeed = clampUnit(socialNeed)
        switch kind {
        case .cat:
            let speed = 0.72 + safeEnergy * 0.30
            let midAmplitude = 2.2 + safeCuriosity * 1.8
            let tipAmplitude = 3.4 + safeCuriosity * 2.5
            let flickPhase = time.truncatingRemainder(dividingBy: 7.6)
            let flick: Double
            if flickPhase >= 0, flickPhase < 0.9 {
                let progress = flickPhase / 0.9
                flick = sin(progress * .pi)
                    * sin(progress * .pi * 2)
                    * (1 + safeCuriosity * 1.5)
            } else {
                flick = 0
            }
            return PetTailPose(
                midDegrees: sin(time * speed) * midAmplitude,
                tipDegrees: sin(time * speed - 0.65) * tipAmplitude + flick
            )
        case .dog:
            let speed = 3.0 + safeEnergy * 1.2 + safeSocialNeed * 0.25
            let midAmplitude = 4.5 + safeSocialNeed * 3.2
            let tipAmplitude = 6.0 + safeSocialNeed * 4.5
            return PetTailPose(
                midDegrees: sin(time * speed) * midAmplitude
                    + sin(time * speed * 2) * 0.6,
                tipDegrees: sin(time * speed - 0.55) * tipAmplitude
                    + sin(time * speed * 2 - 0.2) * 1.3
            )
        case .pauli:
            return .neutral
        }
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

enum PetTailSegment {
    case movingRegion
    case middle
    case tip
}

struct PetTailMask: Shape {
    let kind: PetKind
    let segment: PetTailSegment

    func path(in rect: CGRect) -> Path {
        switch (kind, segment) {
        case (.cat, .movingRegion):
            var path = Path()
            path.move(to: point(x: 0.50, y: 0, in: rect))
            path.addLine(to: point(x: 0.78, y: 0, in: rect))
            path.addLine(to: point(x: 0.78, y: 0.30, in: rect))
            path.addLine(to: point(x: 0.62, y: 0.30, in: rect))
            path.addLine(to: point(x: 0.62, y: 0.17, in: rect))
            path.addLine(to: point(x: 0.50, y: 0.17, in: rect))
            path.closeSubpath()
            return path
        case (.cat, .middle):
            return Path(CGRect(
                x: rect.width * 0.61,
                y: rect.height * 0.105,
                width: rect.width * 0.17,
                height: rect.height * 0.205
            ))
        case (.cat, .tip):
            return Path(CGRect(
                x: rect.width * 0.50,
                y: 0,
                width: rect.width * 0.28,
                height: rect.height * 0.145
            ))
        case (.dog, .movingRegion):
            return Path(CGRect(
                x: rect.width * 0.40,
                y: 0,
                width: rect.width * 0.36,
                height: rect.height * 0.255
            ))
        case (.dog, .middle):
            return Path(CGRect(
                x: rect.width * 0.44,
                y: rect.height * 0.105,
                width: rect.width * 0.32,
                height: rect.height * 0.16
            ))
        case (.dog, .tip):
            return Path(CGRect(
                x: rect.width * 0.40,
                y: 0,
                width: rect.width * 0.36,
                height: rect.height * 0.145
            ))
        case (.pauli, _):
            return Path()
        }
    }

    private func point(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width * x, y: rect.height * y)
    }
}

struct PetMotionContextLatch: Equatable {
    private(set) var activeState: PetAutonomyState
    private var pendingState: PetAutonomyState?

    init(activeState: PetAutonomyState = .neutral) {
        self.activeState = activeState
    }

    mutating func reset(to state: PetAutonomyState) {
        activeState = state
        pendingState = nil
    }

    @discardableResult
    mutating func observe(
        _ state: PetAutonomyState,
        while event: PetMotionEvent
    ) -> Bool {
        guard event != .idle else {
            pendingState = nil
            guard state != activeState else { return false }
            activeState = state
            return true
        }

        pendingState = state == activeState ? nil : state
        return false
    }

    @discardableResult
    mutating func reachedIdleBoundary() -> Bool {
        guard let pendingState else { return false }
        self.pendingState = nil
        guard pendingState != activeState else { return false }
        activeState = pendingState
        return true
    }
}

struct PetArtworkCrossfade {
    let currentOpacity: Double
    let outgoingOpacity: Double

    init(progress: Double) {
        let clamped = progress.isFinite ? min(1, max(0, progress)) : 1
        let eased = clamped * clamped * (3 - 2 * clamped)
        currentOpacity = eased
        outgoingOpacity = 1 - eased
    }
}

/// Tracks presentation-state artwork. Aligned base/blink frames crossfade;
/// larger pose changes use a one-layer opacity bridge to avoid double images.
@MainActor
final class PetArtworkTransitionStore {
    static let standardDuration = 0.24
    static let blinkDuration = 0.07

    private(set) var presentedName: String?
    private var outgoingName: String?
    private var startedAt = 0.0
    private var duration = 0.0
    private var usesCrossfade = false

    func reset() {
        presentedName = nil
        outgoingName = nil
        usesCrossfade = false
    }

    func synchronize(to resourceName: String) {
        presentedName = resourceName
        outgoingName = nil
        usesCrossfade = false
    }

    func layers(
        for requested: String,
        at time: Double,
        animated: Bool
    ) -> (
        current: String,
        currentOpacity: Double,
        outgoing: String?,
        outgoingOpacity: Double
    ) {
        guard animated, time.isFinite else {
            presentedName = requested
            outgoingName = nil
            return (requested, 1, nil, 0)
        }

        if presentedName == nil {
            presentedName = requested
        } else if requested != presentedName {
            outgoingName = presentedName
            usesCrossfade = Self.isAlignedBlinkPair(
                from: presentedName,
                to: requested
            )
            duration = usesCrossfade ? Self.blinkDuration : Self.standardDuration
            startedAt = time
            presentedName = requested
        }

        guard let outgoing = outgoingName else {
            return (requested, 1, nil, 0)
        }
        let progress = (time - startedAt) / duration
        guard progress < 1 else {
            outgoingName = nil
            return (requested, 1, nil, 0)
        }
        if usesCrossfade {
            let fade = PetArtworkCrossfade(progress: progress)
            return (requested, fade.currentOpacity, outgoing, fade.outgoingOpacity)
        }

        let normalizedDistance: Double
        if progress < 0.5 {
            normalizedDistance = 1 - progress * 2
        } else {
            normalizedDistance = progress * 2 - 1
        }
        let easedDistance = normalizedDistance * normalizedDistance
            * (3 - 2 * normalizedDistance)
        let opacity = PetArtworkBlend.minimumBridgeOpacity
            + (1 - PetArtworkBlend.minimumBridgeOpacity) * easedDistance
        if progress < 0.5 {
            return (requested, 0, outgoing, opacity)
        }
        return (requested, opacity, outgoing, 0)
    }

    private static func isAlignedBlinkPair(
        from outgoing: String?,
        to incoming: String
    ) -> Bool {
        guard let outgoing else { return false }
        let outgoingComponents = outgoing.split(separator: "/")
        let incomingComponents = incoming.split(separator: "/")
        guard outgoingComponents.dropLast().elementsEqual(
            incomingComponents.dropLast()
        ), let outgoingName = outgoingComponents.last,
           let incomingName = incomingComponents.last else { return false }
        return Set([String(outgoingName), String(incomingName)])
            == Set(["base", "blink"])
    }
}

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

        for resourceName in manifest.preloadResourceNames {
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
    let weatherProfile: WeatherSceneProfile
    let isHovering: Bool
    let pulse: Int
    let comboCount: Int
    let activity: PetActivity
    let pointerOffset: CGSize
    let autonomyState: PetAutonomyState
    let reduceMotion: Bool
    let motionPreview: PetMotionEvent?
    let rootMotionFrame: PetRootMotionFrame?
    let dragLeanAt: (TimeInterval) -> PetDragLean
    let cursorAttention: (TimeInterval) -> PetAttentionSample?
    let onDelight: () -> Void
    let artworkOverride: String?
    @Environment(\.petWindowIsVisible) private var petWindowIsVisible
    @Environment(\.petRenderTimeOverride) private var renderTimeOverride
    @Environment(\.petAttentionElapsedOverride) private var attentionElapsedOverride
    @Environment(\.petRelationshipGestureElapsedOverride)
    private var relationshipGestureElapsedOverride

    @State private var isShowingPat = false
    @State private var patTask: Task<Void, Never>?
    @State private var patGeneration = 0
    @State private var patStartedAt: TimeInterval?
    @State private var patCombo = 1
    @State private var patSettleStartedAt: TimeInterval?
    @State private var danceStartedAt: TimeInterval?
    @State private var personalityStartedAt: TimeInterval?
    @State private var relationshipGestureStartedAt: TimeInterval?
    @State private var nuzzleStartedAt: TimeInterval?
    @State private var nuzzleReleasedAt: TimeInterval?
    @State private var nuzzleElapsedAtRelease: TimeInterval = 0
    @State private var sleepStartedAt: TimeInterval?
    @State private var hoverStartedAt: TimeInterval?
    @State private var isShowingDelight = false
    @State private var delightStartedAt: TimeInterval?
    @State private var dwellTask: Task<Void, Never>?
    @State private var motionArtworkReadyKind: PetKind?
    @State private var motionScheduleClock = PetMotionScheduleClock()
    @State private var motionContext = PetMotionContextLatch()
    @State private var artworkTransitions = PetArtworkTransitionStore()

    private var mood: PetWeatherMood { weatherProfile.mood }

    private var isSleeping: Bool {
        activity.kind == .sleeping
    }

    private var isDancing: Bool {
        activity.kind == .dancing
    }

    private var isNuzzling: Bool {
        activity.kind == .nuzzling
    }

    private var personalityPose: PersonalityPose? {
        activity.personalityPose
    }

    private var relationshipGesture: PetRelationshipGesture? {
        activity.relationshipGesture
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: renderCadence.minimumInterval,
            paused: renderCadence.isPaused
        )) { timeline in
            let time = renderTimeOverride
                ?? timeline.date.timeIntervalSinceReferenceDate
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
            let requestedArtwork = PetArtworkLoader.image(named: requested)
            let maskArtwork = requestedArtwork
                ?? PetArtworkLoader.image(named: manifest.base)
            let artworkLayout = PetArtworkLayout.resolve(
                petKind: kind,
                resourceName: requestedArtwork == nil ? manifest.base : requested
            )
            let gaze = gazePose(at: time, motion: motion)
            let lean = dragLean(at: time)

            Group {
                if let maskArtwork {
                    ZStack {
                        contactShadow(
                            at: time,
                            motion: motion,
                            layout: artworkLayout
                        )

                        ZStack {
                            ZStack {
                                displayedArtwork(
                                    manifest: manifest,
                                    time: time,
                                    motion: motion
                                )

                                PetWeatherLighting(
                                    kind: kind,
                                    profile: weatherProfile,
                                    time: time,
                                    reduceMotion: reduceMotion
                                )
                                .mask(artworkImage(maskArtwork))
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
                        .scaleEffect(artworkLayout.scale)
                        .offset(y: artworkLayout.verticalOffset)
                        .scaleEffect(
                            x: composedHorizontalScale(at: time, motion: motion)
                                * CGFloat(rootWeightShift.horizontalScale)
                                * CGFloat(gaze.scale),
                            y: composedVerticalScale(at: time, motion: motion)
                                * CGFloat(rootWeightShift.verticalScale)
                                * CGFloat(gaze.scale),
                            anchor: .bottom
                        )
                        .rotation3DEffect(
                            .degrees(rootFacingAngle),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .bottom,
                            perspective: 0.24
                        )
                        .rotationEffect(
                            .degrees(
                                animatedTilt(at: time)
                                    + weatherTilt(at: time)
                                    + motion.tiltDegrees
                                    + rootWeightShift.tiltDegrees
                                    + gaze.tiltDegrees
                                    + lean.tiltDegrees
                            )
                        )
                        .offset(
                            x: composedOffset(at: time, motion: motion).width
                                + gaze.x + lean.offsetX,
                            y: composedOffset(at: time, motion: motion).height
                                + gaze.y + lean.offsetY
                        )
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
            .onChange(of: autonomyState) {
                guard motionPreview == nil, rootMotionFrame == nil else { return }
                if motionContext.observe(
                    autonomyState,
                    while: candidateMotion.event
                ) {
                    restartMotionSchedule(at: time)
                }
            }
            .onChange(of: candidateMotion.event) {
                guard motionPreview == nil,
                      rootMotionFrame == nil,
                      candidateMotion.event == .idle,
                      motionContext.reachedIdleBoundary() else { return }
                restartMotionSchedule(at: time)
            }
        }
        .frame(width: 220, height: 218)
        .task(id: kind) {
            let requestedKind = kind
            motionArtworkReadyKind = nil
            motionScheduleClock.updateEligibility(false, at: 0)
            motionContext.reset(to: autonomyState)
            artworkTransitions.reset()
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
            patSettleStartedAt = nil
            patCombo = max(1, comboCount)
            isShowingPat = true
            patTask = Task { @MainActor in
                try? await Task.sleep(
                    for: .seconds(
                        PetAnimationDynamics.patDuration(comboCount: patCombo)
                    )
                )
                guard !Task.isCancelled, generation == patGeneration else { return }
                isShowingPat = false
                patStartedAt = nil
                patSettleStartedAt = Date().timeIntervalSinceReferenceDate
                patTask = nil
            }
        }
        .onChange(of: isDancing) {
            danceStartedAt = isDancing ? Date().timeIntervalSinceReferenceDate : nil
        }
        .onChange(of: isSleeping) {
            sleepStartedAt = isSleeping ? Date().timeIntervalSinceReferenceDate : nil
        }
        .onChange(of: isHovering) {
            hoverStartedAt = isHovering
                ? Date().timeIntervalSinceReferenceDate
                : nil
            dwellTask?.cancel()
            dwellTask = nil
            isShowingDelight = false
            delightStartedAt = nil
            guard isHovering, !reduceMotion else { return }
            dwellTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                guard isHovering,
                      !isSleeping,
                      !isDancing,
                      !isShowingPat,
                      !isNuzzling,
                      personalityPose == nil else { return }
                isShowingDelight = true
                delightStartedAt = Date().timeIntervalSinceReferenceDate
                onDelight()
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                isShowingDelight = false
                delightStartedAt = nil
            }
        }
        .onChange(of: personalityPose) {
            personalityStartedAt = personalityPose == nil
                ? nil
                : Date().timeIntervalSinceReferenceDate
        }
        .onChange(of: relationshipGesture) {
            relationshipGestureStartedAt = relationshipGesture == nil
                ? nil
                : Date().timeIntervalSinceReferenceDate
        }
        .onChange(of: isNuzzling) {
            let now = Date().timeIntervalSinceReferenceDate
            if isNuzzling {
                nuzzleStartedAt = now
                nuzzleReleasedAt = nil
                nuzzleElapsedAtRelease = 0
            } else {
                nuzzleElapsedAtRelease = nuzzleStartedAt.map { max(0, now - $0) } ?? 0
                nuzzleStartedAt = nil
                nuzzleReleasedAt = now
            }
        }
        .onDisappear {
            patTask?.cancel()
            patTask = nil
            patGeneration += 1
            isShowingPat = false
            patStartedAt = nil
            patSettleStartedAt = nil
            patCombo = 1
            danceStartedAt = nil
            personalityStartedAt = nil
            relationshipGestureStartedAt = nil
            nuzzleStartedAt = nil
            nuzzleReleasedAt = nil
            nuzzleElapsedAtRelease = 0
            sleepStartedAt = nil
            hoverStartedAt = nil
            dwellTask?.cancel()
            dwellTask = nil
            isShowingDelight = false
            delightStartedAt = nil
        }
    }

    private var renderCadence: PetRenderCadence {
        PetRenderCadence.resolve(
            reduceMotion: reduceMotion,
            isVisible: petWindowIsVisible,
            isDirectInteraction: isShowingPat
                || isDancing
                || isNuzzling
                || isShowingDelight,
            isActiveMotion: personalityPose != nil || motionPreview != nil
                || rootMotionFrame != nil
        )
    }

    private var motionSeed: Int {
        switch kind {
        case .cat: 1_031
        case .pauli: 2_047
        case .dog: 4_093
        }
    }

    private var rootFacingAngle: Double {
        guard !reduceMotion, let rootMotionFrame else { return 0 }
        let direction = Double(rootMotionFrame.direction.rawValue)
        return switch rootMotionFrame.phase {
        case .notice, .completed:
            0
        case .anticipate:
            -direction * 3 * rootMotionFrame.phaseProgress
        case .turning:
            -direction * (3 + 4 * rootMotionFrame.phaseProgress)
        case .walking, .slowing:
            -direction * 7
        case .settling:
            -direction * 7 * (1 - rootMotionFrame.phaseProgress)
        }
    }

    private var rootWeightShift: PetRootTransitionPose {
        guard let rootMotionFrame else { return .neutral }
        return PetRootTransitionMotion.pose(
            for: rootMotionFrame,
            reduceMotion: reduceMotion
        )
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
        if let rootMotionFrame {
            return PetMotionDirector.rootMotionFrame(
                pet: kind,
                rootMotion: rootMotionFrame,
                reduceMotion: reduceMotion
            )
        }
        return PetMotionDirector.frame(
            pet: kind,
            time: relativeTime,
            seed: motionSeed,
            isEligible: true,
            reduceMotion: reduceMotion,
            autonomyState: motionContext.activeState
        )
    }

    private func restartMotionSchedule(at time: TimeInterval) {
        motionScheduleClock.updateEligibility(false, at: time)
        let strongWeatherReactionActive = PetMotionDirector
            .isStrongWeatherReactionActive(weatherReaction, time: time)
        motionScheduleClock.updateEligibility(
            allowsScheduledMotionBase && !strongWeatherReactionActive,
            at: time
        )
    }

    private func requestedResourceName(
        manifest: PetArtworkManifest,
        time: TimeInterval,
        motion: PetMotionFrame
    ) -> String {
        if let artworkOverride { return artworkOverride }
        if isSleeping { return manifest.resourceName(for: .sleep) }
        if isShowingPat {
            return PetUnifiedRigPolicy.usesCanonicalDirectTouchArtwork(
                isActive: true,
                reduceMotion: reduceMotion
            ) ? manifest.base : manifest.resourceName(for: .pat)
        }
        if isDancing { return manifest.base }
        if isNuzzleActive(at: time) { return manifest.blink }
        if let personalityPose {
            if PetUnifiedRigPolicy.usesCanonicalRelationshipArtwork(
                personalityPose: personalityPose,
                relationshipGesture: relationshipGesture,
                reduceMotion: reduceMotion
            ) {
                return manifest.base
            }
            return manifest.resourceName(for: .personality(personalityPose))
        }
        if isShowingDelight { return manifest.resourceName(for: .personality(.perk)) }
        if isHovering,
           hoverAttentionPhase(at: time).usesCuriousArtwork {
            return manifest.resourceName(for: .hover)
        }
        if !isHovering,
           !reduceMotion,
           rootMotionFrame == nil,
           motionPreview == nil,
           motion.event == .idle,
           let nearby = cursorAttention(time),
           PetAttentionTimeline.phase(
               for: kind,
               elapsed: nearby.elapsed,
               reduceMotion: false
           ).usesCuriousArtwork {
            return manifest.resourceName(for: .hover)
        }
        if usesUnifiedRig(at: time, motion: motion) {
            return manifest.base
        }
        if let rootTransition = rootTransitionResourceName(
            manifest: manifest,
            time: time
        ) {
            return rootTransition
        }
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

    private func usesUnifiedRig(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> Bool {
        let usesRelationshipRig = PetUnifiedRigPolicy
            .usesCanonicalRelationshipArtwork(
                personalityPose: personalityPose,
                relationshipGesture: relationshipGesture,
                reduceMotion: reduceMotion
            )
        return artworkOverride == nil
            && !isSleeping
            && !isDancing
            && !isNuzzleActive(at: time)
            && (personalityPose == nil || usesRelationshipRig)
            && !isShowingDelight
            && !isHovering
            && (
                PetUnifiedRigPolicy.usesCanonicalDirectTouchArtwork(
                    isActive: isShowingPat,
                    reduceMotion: reduceMotion
                )
                || usesRelationshipRig
                || PetUnifiedRigPolicy.usesCanonicalArtwork(
                    motion: motion,
                    rootMotion: rootMotionFrame,
                    reduceMotion: reduceMotion
                )
            )
    }

    private func rootTransitionResourceName(
        manifest: PetArtworkManifest,
        time: TimeInterval
    ) -> String? {
        rootTransitionArtworkLayers(
            manifest: manifest,
            time: time
        )?.dominantResourceName
    }

    private func rootTransitionArtworkLayers(
        manifest: PetArtworkManifest,
        time: TimeInterval
    ) -> PetTransitionArtworkLayers? {
        guard !reduceMotion,
              !isSleeping,
              !isShowingPat,
              !isDancing,
              !isNuzzleActive(at: time),
              personalityPose == nil,
              !isShowingDelight,
              !isHovering,
              let rootMotionFrame,
              let pose = rootMotionFrame.phase.transitionPose else {
            return nil
        }
        return resolvedTransitionArtworkLayers(
            frame: manifest.transitionClipFrame(
                for: pose,
                progress: rootMotionFrame.phaseProgress
            ),
            manifest: manifest
        )
    }

    private func resolvedTransitionArtworkLayers(
        frame: PetTransitionArtworkFrame,
        manifest: PetArtworkManifest
    ) -> PetTransitionArtworkLayers {
        let candidates = [
            frame.currentResourceName,
            frame.nextResourceName,
            frame.fallbackResourceName,
            manifest.base,
        ]
        let available = Set(candidates.filter {
            PetArtworkLoader.image(named: $0) != nil
        })
        return PetTransitionArtworkResolver.resolve(
            frame: frame,
            availableResourceNames: available,
            baseFallbackResourceName: manifest.base
        )
    }

    private func rootMotionBridgeResourceName(
        manifest: PetArtworkManifest
    ) -> String {
        switch rootMotionFrame?.phase {
        case .walking:
            resolvedTransitionArtworkLayers(
                frame: manifest.transitionClipFrame(for: .turn, progress: 1),
                manifest: manifest
            ).dominantResourceName
        case .slowing:
            resolvedTransitionArtworkLayers(
                frame: manifest.transitionClipFrame(for: .settle, progress: 0),
                manifest: manifest
            ).dominantResourceName
        case .notice, .anticipate, .turning, .settling, .completed, .none:
            manifest.base
        }
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
        if personalityPose != nil {
            return CGFloat(relationshipGesturePose(at: time).scale)
        }
        if isNuzzleActive(at: time) {
            return CGFloat(nuzzlePose(at: time).scale)
        }
        if isShowingDelight {
            return CGFloat(delightPose(at: time).scale)
        }
        if isHovering {
            return CGFloat(attentionPose(at: time).scale)
        }
        let idle = PetAnimationDynamics.idlePose(for: kind, time: time)
        // Couple the body to the eyelid so blinks feel organic, then layer
        // any post-pat settle wobble on top of the idle breath.
        let blink = PetAnimationDynamics.blinkEnvelope(for: kind, time: time)
        let settle = patSettlePose(at: time)
        return 1
            + CGFloat(idle.scale - 1) * idleAmplitudeMultiplier
            + CGFloat(settle.scale - 1)
            - CGFloat(blink) * 0.004
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
                + relationshipGesturePose(at: time).tiltDegrees
        }
        if isNuzzleActive(at: time) {
            return nuzzlePose(at: time).tiltDegrees
        }
        if isShowingDelight {
            return delightPose(at: time).tiltDegrees
        }
        if isHovering {
            return attentionPose(at: time).tiltDegrees
        }

        return PetAnimationDynamics.idlePose(for: kind, time: time).tiltDegrees
            + patSettlePose(at: time).tiltDegrees
    }

    private func animatedOffset(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGSize {
        guard !reduceMotion else { return .zero }

        if isSleeping {
            // Ease down into the nap instead of teleporting to the sleep pose.
            let elapsed = elapsed(since: sleepStartedAt, at: time)
            let dip = elapsed < 0.9
                ? sin(min(1, elapsed / 0.9) * .pi) * 2.2
                : 0
            return CGSize(width: 0, height: dip)
        }
        if isShowingPat {
            let pose = patPose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if isDancing {
            let pose = dancePose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if personalityPose != nil {
            let base = personalityOffset(at: time)
            let gesture = relationshipGesturePose(at: time)
            return CGSize(
                width: base.width + gesture.x,
                height: base.height + gesture.y
            )
        }
        if isNuzzleActive(at: time) {
            let pose = nuzzlePose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if isShowingDelight {
            let pose = delightPose(at: time)
            return CGSize(width: pose.x, height: pose.y)
        }
        if isHovering {
            let attention = attentionPose(at: time)
            return CGSize(
                width: attention.x,
                height: attention.y
            )
        }

        let idle = PetAnimationDynamics.idlePose(for: kind, time: time)
        let settle = patSettlePose(at: time)
        return CGSize(
            width: idle.x + settle.x,
            height: idle.y * Double(idleAmplitudeMultiplier) + settle.y
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
    private func displayedArtwork(
        manifest: PetArtworkManifest,
        time: TimeInterval,
        motion: PetMotionFrame
    ) -> some View {
        let eyeDirection = eyeGazeDirection(at: time, motion: motion)
        if let artworkOverride {
            transitionedArtwork(
                named: artworkOverride,
                opacity: 1,
                time: time,
                eyeDirection: eyeDirection
            )
        } else if usesUnifiedRig(at: time, motion: motion),
                  let artwork = PetArtworkLoader.image(named: manifest.base) {
            let _ = artworkTransitions.synchronize(to: manifest.base)
            let rigPose = isShowingPat
                ? PetUnifiedRigDirectTouchMotion.pose(
                    pet: kind,
                    elapsed: elapsed(since: patStartedAt, at: time),
                    comboCount: patCombo,
                    reduceMotion: reduceMotion
                )
                : relationshipGesture.map {
                    PetUnifiedRigRelationshipMotion.pose(
                        pet: kind,
                        gesture: $0,
                        elapsed: relationshipGestureElapsed(at: time),
                        reduceMotion: reduceMotion
                    )
                }
                ?? PetUnifiedRigMotion.pose(
                    pet: kind,
                    motion: motion,
                    rootMotion: rootMotionFrame,
                    reduceMotion: reduceMotion
                )
            let tailPose = PetTailMotion.pose(
                for: kind,
                time: time,
                energy: autonomyState.energy,
                curiosity: autonomyState.curiosity,
                socialNeed: autonomyState.socialNeed
            )
            ZStack {
                PetUnifiedRigArtwork(
                    kind: kind,
                    artwork: artwork,
                    pose: rigPose,
                    tailPose: tailPose
                )

                if let eyeDirection,
                   let artworkPose = PetEyeArtworkPolicy.pose(
                       kind: kind,
                       resourceName: manifest.base
                   ) {
                    PetEyeGazeOverlay(
                        kind: kind,
                        artworkPose: artworkPose,
                        direction: eyeDirection
                    )
                }
            }
        } else if let layers = rootTransitionArtworkLayers(
            manifest: manifest,
            time: time
        ) {
            let _ = artworkTransitions.synchronize(
                to: layers.dominantResourceName
            )
            ZStack {
                transitionedArtwork(
                    named: layers.currentResourceName,
                    opacity: 1 - layers.blend,
                    time: time,
                    eyeDirection: eyeDirection
                )
                transitionedArtwork(
                    named: layers.nextResourceName,
                    opacity: layers.blend,
                    time: time,
                    eyeDirection: eyeDirection
                )
            }
        } else if motion.event != .idle, motion.event != .lookAround {
            let blend = PetArtworkBlend(motion: motion)
            let bridgeResource = rootMotionBridgeResourceName(
                manifest: manifest
            )
            let _ = artworkTransitions.synchronize(to: bridgeResource)
            ZStack {
                motionArtwork(
                    named: bridgeResource,
                    opacity: blend.baseOpacity,
                    time: time
                )
                motionArtwork(
                    named: manifest.resourceName(
                        for: motion.event,
                        frameIndex: motion.presentedArtworkFrameIndex
                            ?? motion.artworkFrameIndex
                    ),
                    opacity: blend.currentOpacity,
                    time: time
                )
            }
            .compositingGroup()
        } else {
            let requested = requestedResourceName(
                manifest: manifest,
                time: time,
                motion: motion
            )
            let layers = artworkTransitions.layers(
                for: requested,
                at: time,
                animated: !reduceMotion
            )
            ZStack {
                if let outgoing = layers.outgoing, layers.outgoingOpacity > 0 {
                    transitionedArtwork(
                        named: outgoing,
                        opacity: layers.outgoingOpacity,
                        time: time,
                        eyeDirection: eyeDirection
                    )
                }
                transitionedArtwork(
                    named: layers.current,
                    opacity: layers.currentOpacity,
                    time: time,
                    eyeDirection: eyeDirection
                )
            }
        }
    }

    @ViewBuilder
    private func transitionedArtwork(
        named resourceName: String,
        opacity: Double,
        time: TimeInterval,
        eyeDirection: CGSize?
    ) -> some View {
        if opacity > 0,
           let artwork = PetArtworkLoader.image(named: resourceName)
               ?? PetArtworkLoader.image(named: PetArtworkManifest(petKind: kind).base) {
            presentedArtwork(
                artwork,
                named: resourceName,
                time: time,
                eyeDirection: eyeDirection
            )
                .opacity(opacity)
        }
    }

    @ViewBuilder
    private func motionArtwork(
        named resourceName: String,
        opacity: Double,
        time: TimeInterval
    ) -> some View {
        if opacity > 0,
           let artwork = PetArtworkLoader.image(named: resourceName)
            ?? PetArtworkLoader.image(named: PetArtworkManifest(petKind: kind).base) {
            presentedArtwork(
                artwork,
                named: resourceName,
                time: time,
                eyeDirection: nil
            )
                .opacity(opacity)
        }
    }

    @ViewBuilder
    private func presentedArtwork(
        _ artwork: NSImage,
        named resourceName: String,
        time: TimeInterval,
        eyeDirection: CGSize?
    ) -> some View {
        ZStack {
            if !reduceMotion,
               PetTailArtworkPolicy.supportsIndependentTail(
                   kind: kind,
                   resourceName: resourceName
               ) {
                flexibleTailArtwork(artwork, time: time)
            } else {
                artworkImage(artwork)
            }

            if let eyeDirection,
               let artworkPose = PetEyeArtworkPolicy.pose(
                   kind: kind,
                   resourceName: resourceName
               ) {
                PetEyeGazeOverlay(
                    kind: kind,
                    artworkPose: artworkPose,
                    direction: eyeDirection
                )
                .animation(
                    .interactiveSpring(response: 0.18, dampingFraction: 0.86),
                    value: eyeDirection
                )
            }
        }
    }

    private func flexibleTailArtwork(
        _ artwork: NSImage,
        time: TimeInterval
    ) -> some View {
        let pose = PetTailMotion.pose(
            for: kind,
            time: time,
            energy: autonomyState.energy,
            curiosity: autonomyState.curiosity,
            socialNeed: autonomyState.socialNeed
        )
        let anchors = tailAnchors

        return ZStack {
            artworkImage(artwork)
                .mask {
                    ZStack {
                        Rectangle().fill(.white)
                        PetTailMask(kind: kind, segment: .movingRegion)
                            .fill(.white)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }

            artworkImage(artwork)
                .mask {
                    PetTailMask(kind: kind, segment: .middle).fill(.white)
                }
                .rotationEffect(
                    .degrees(pose.midDegrees),
                    anchor: anchors.middle
                )

            artworkImage(artwork)
                .mask {
                    PetTailMask(kind: kind, segment: .tip).fill(.white)
                }
                .rotationEffect(
                    .degrees(pose.tipDegrees),
                    anchor: anchors.tip
                )
                .rotationEffect(
                    .degrees(pose.midDegrees),
                    anchor: anchors.middle
                )
        }
        .compositingGroup()
    }

    private var tailAnchors: (middle: UnitPoint, tip: UnitPoint) {
        switch kind {
        case .cat:
            (UnitPoint(x: 0.66, y: 0.30), UnitPoint(x: 0.67, y: 0.125))
        case .dog:
            (UnitPoint(x: 0.55, y: 0.255), UnitPoint(x: 0.54, y: 0.125))
        case .pauli:
            (.center, .center)
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
            width: existing.width + weather.width
                + CGFloat(motion.horizontalOffset)
                + CGFloat(rootWeightShift.horizontalOffset),
            height: existing.height + weather.height
                + CGFloat(motion.verticalOffset)
                + CGFloat(rootWeightShift.verticalOffset)
        )
    }

    private func contactShadow(
        at time: TimeInterval,
        motion: PetMotionFrame,
        layout: PetArtworkLayout
    ) -> some View {
        let existing = animatedOffset(at: time, motion: motion)
        let weather = weatherOffset(at: time)
        let relationshipLift = max(
            0,
            -relationshipGesturePose(at: time).y
        )
        let relationshipShadowScale = 1 - min(
            0.10,
            relationshipLift * 0.02
        )
        let horizontalOffset = existing.width
            + weather.width
            + CGFloat(motion.horizontalOffset)
            + CGFloat(rootWeightShift.horizontalOffset)
            + CGFloat(motion.shadowOffset)
            + CGFloat(rootWeightShift.shadowOffset)

        return Ellipse()
            .fill(Color.black.opacity(shadowOpacity))
            .frame(
                width: layout.shadowWidth,
                height: layout.shadowHeight
            )
            .blur(radius: 8)
            .scaleEffect(
                x: CGFloat(
                    motion.shadowScale
                        * rootWeightShift.shadowScale
                        * relationshipShadowScale
                ),
                y: 1
            )
            .offset(
                x: horizontalOffset,
                y: layout.shadowVerticalOffset
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Overcast and storm light softens the contact shadow; direct sun
    /// hardens it. Keeps the pet grounded to the same sky as the scene.
    private var shadowOpacity: Double {
        switch mood {
        case .sunny: 0.14
        case .cloudy: 0.10
        case .foggy: 0.09
        case .rainy: 0.11
        case .snowy: 0.10
        case .stormy: 0.13
        case .cozy: 0.12
        }
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

    private func attentionPose(at time: TimeInterval) -> PetAnimationPose {
        let phase = hoverAttentionPhase(at: time)
        return PetAnimationDynamics.attentionPose(
            for: kind,
            pointerX: pointerOffset.width,
            pointerY: pointerOffset.height,
            time: time
        ).scaled(by: phase.bodyProgress)
    }

    private func hoverAttentionPhase(
        at time: TimeInterval
    ) -> PetAttentionPhase {
        guard isHovering else { return .neutral }
        let elapsed: TimeInterval
        if let attentionElapsedOverride {
            elapsed = attentionElapsedOverride
        } else if let nearby = cursorAttention(time) {
            // Preserve the approach phase when the pointer crosses from the
            // surrounding desktop into the pet window.
            elapsed = nearby.elapsed
        } else if let hoverStartedAt {
            elapsed = max(0, time - hoverStartedAt)
        } else {
            // Deterministic previews can be created already hovered. Treat
            // those as settled unless a stage override is supplied.
            elapsed = 10
        }
        return PetAttentionTimeline.phase(
            for: kind,
            elapsed: elapsed,
            reduceMotion: reduceMotion
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

    private func relationshipGesturePose(
        at time: TimeInterval
    ) -> PetAnimationPose {
        guard let relationshipGesture else { return .neutral }
        return PetRelationshipGestureMotion.pose(
            for: kind,
            gesture: relationshipGesture,
            elapsed: relationshipGestureElapsed(at: time),
            reduceMotion: reduceMotion
        )
    }

    private func relationshipGestureElapsed(
        at time: TimeInterval
    ) -> TimeInterval {
        if let relationshipGestureElapsedOverride {
            return relationshipGestureElapsedOverride
        }
        return elapsed(
            since: relationshipGestureStartedAt,
            at: time
        )
    }

    private func patPose(at time: TimeInterval) -> PetAnimationPose {
        PetAnimationDynamics.patPose(
            for: kind,
            elapsed: elapsed(since: patStartedAt, at: time),
            comboCount: patCombo
        )
    }

    private func patSettlePose(at time: TimeInterval) -> PetAnimationPose {
        guard !reduceMotion, patSettleStartedAt != nil else { return .neutral }
        return PetAnimationDynamics.patSettlePose(
            for: kind,
            elapsed: elapsed(since: patSettleStartedAt, at: time),
            comboCount: patCombo
        )
    }

    private func delightPose(at time: TimeInterval) -> PetAnimationPose {
        PetAnimationDynamics.patPose(
            for: kind,
            elapsed: elapsed(since: delightStartedAt, at: time),
            comboCount: 1
        ).scaled(by: 0.55)
    }

    private func dancePose(at time: TimeInterval) -> PetAnimationPose {
        PetAnimationDynamics.dancePose(
            for: kind,
            elapsed: elapsed(since: danceStartedAt, at: time)
        )
    }

    private func nuzzlePose(at time: TimeInterval) -> PetAnimationPose {
        if let nuzzleStartedAt {
            return PetAnimationDynamics.nuzzlePose(
                for: kind,
                elapsed: max(0, time - nuzzleStartedAt)
            )
        }
        if let nuzzleReleasedAt {
            let fade = exp(-max(0, time - nuzzleReleasedAt) * 6)
            guard fade > 0.01 else { return .neutral }
            return PetAnimationDynamics
                .nuzzlePose(for: kind, elapsed: nuzzleElapsedAtRelease)
                .scaled(by: fade)
        }
        return .neutral
    }

    private func isNuzzleActive(at time: TimeInterval) -> Bool {
        guard !reduceMotion else { return false }
        if nuzzleStartedAt != nil { return true }
        guard let nuzzleReleasedAt else { return false }
        return time - nuzzleReleasedAt < 0.6
    }

    private func eyeGazeDirection(
        at time: TimeInterval,
        motion: PetMotionFrame
    ) -> CGSize? {
        guard !reduceMotion,
              !isSleeping,
              !isDancing,
              !isShowingPat,
              !isShowingDelight,
              !isNuzzleActive(at: time),
              personalityPose == nil,
              motion.event == .idle else { return nil }

        if isHovering {
            return scaledDirection(
                PetEyeGazeMotion.direction(for: pointerOffset),
                by: hoverAttentionPhase(at: time).eyeProgress
            )
        }
        guard let nearby = cursorAttention(time) else { return nil }
        let phase = PetAttentionTimeline.phase(
            for: kind,
            elapsed: nearby.elapsed,
            reduceMotion: false
        )
        return scaledDirection(
            PetEyeGazeMotion.direction(for: nearby.offset),
            by: phase.eyeProgress
        )
    }

    private func gazePose(at time: TimeInterval, motion: PetMotionFrame) -> PetAnimationPose {
        guard !reduceMotion,
              !isSleeping,
              !isDancing,
              !isShowingPat,
              !isHovering,
              !isNuzzleActive(at: time),
              personalityPose == nil,
              motion.event == .idle,
              let nearby = cursorAttention(time) else { return .neutral }
        let phase = PetAttentionTimeline.phase(
            for: kind,
            elapsed: nearby.elapsed,
            reduceMotion: false
        )
        return PetAnimationDynamics.attentionPose(
            for: kind,
            pointerX: nearby.offset.width,
            pointerY: nearby.offset.height,
            time: time
        ).scaled(by: 0.55 * phase.bodyProgress)
    }

    private func scaledDirection(
        _ direction: CGSize,
        by progress: Double
    ) -> CGSize {
        CGSize(
            width: direction.width * CGFloat(progress),
            height: direction.height * CGFloat(progress)
        )
    }

    private func dragLean(at time: TimeInterval) -> PetDragLean {
        guard !reduceMotion, !isSleeping else { return .neutral }
        return dragLeanAt(time)
    }

    private func elapsed(
        since start: TimeInterval?,
        at time: TimeInterval
    ) -> TimeInterval {
        guard let start, time.isFinite else { return 0 }
        return max(0, time - start)
    }
}
