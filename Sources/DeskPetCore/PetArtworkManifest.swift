public enum PetPresentationState: Equatable, Sendable {
    case idle
    case blink
    case hover
    case pat
    case sleep
    case personality(PersonalityPose)
}

public enum PetTransitionPose: String, CaseIterable, Equatable, Sendable {
    case anticipate
    case turn
    case settle
}

public struct PetTransitionArtworkFrame: Equatable, Sendable {
    public let currentResourceName: String
    public let nextResourceName: String
    public let blend: Double
    public let fallbackResourceName: String

    public init(
        currentResourceName: String,
        nextResourceName: String,
        blend: Double,
        fallbackResourceName: String
    ) {
        self.currentResourceName = currentResourceName
        self.nextResourceName = nextResourceName
        self.blend = blend
        self.fallbackResourceName = fallbackResourceName
    }
}

public struct PetArtworkManifest: Equatable, Sendable {
    public let petKind: PetKind
    public let base: String
    public let blink: String
    public let hover: String
    public let pat: String
    public let sleep: String
    public let walk: [String]
    public let idleActions: [String]
    public let transitions: [PetTransitionPose: String]
    public let transitionClips: [PetTransitionPose: [String]]
    public let personality: [PersonalityPose: String]

    public init(petKind: PetKind) {
        let directory = "Pets/\(petKind.resourceDirectoryName)"

        self.petKind = petKind
        self.base = "\(directory)/base"
        self.blink = "\(directory)/blink"
        self.hover = "\(directory)/hover"
        self.pat = "\(directory)/pat"
        self.sleep = "\(directory)/sleep"
        self.walk = (1...6).map { "\(directory)/walk\($0)" }
        self.idleActions = (1...2).map { "\(directory)/idleAction\($0)" }
        self.transitions = Dictionary(
            uniqueKeysWithValues: PetTransitionPose.allCases.map { pose in
                (pose, "\(directory)/\(pose.rawValue)")
            }
        )
        self.transitionClips = Dictionary(
            uniqueKeysWithValues: PetTransitionPose.allCases.map { pose in
                let frames = (1...4).map {
                    "\(directory)/RootMotion/\(pose.rawValue)\($0)"
                }
                return (pose, frames)
            }
        )
        self.personality = Dictionary(
            uniqueKeysWithValues: PersonalityPose.allCases.map { pose in
                (pose, "\(directory)/\(pose.rawValue)")
            }
        )
    }

    public var fallbackResourceName: String {
        base
    }

    public var motionResourceNames: [String] {
        walk + idleActions + transitionResourceNames + [
            personality[.peek] ?? base,
            personality[.stretch] ?? base,
            personality[.perk] ?? base,
        ]
    }

    public var transitionResourceNames: [String] {
        PetTransitionPose.allCases.map { transitions[$0] ?? base }
    }

    public var transitionClipResourceNames: [String] {
        PetTransitionPose.allCases.flatMap { transitionClips[$0] ?? [] }
    }

    /// Full-body locomotion and idle-gesture frames remain in the bundle as
    /// provenance artifacts. Stretch is the only runtime motion whose topology
    /// cannot yet be reproduced from the canonical base artwork.
    public var runtimeMotionResourceNames: [String] {
        [personality[.stretch] ?? base]
    }

    public var preloadResourceNames: [String] {
        runtimeMotionResourceNames
    }

    public func hasCompleteMotionSet(
        availableResourceNames: Set<String>
    ) -> Bool {
        runtimeMotionResourceNames.allSatisfy(availableResourceNames.contains)
    }

    public func resourceName(for state: PetPresentationState) -> String {
        switch state {
        case .idle:
            base
        case .blink:
            blink
        case .hover:
            hover
        case .pat:
            pat
        case .sleep:
            sleep
        case .personality(let pose):
            personality[pose] ?? base
        }
    }

    public func resourceName(for transition: PetTransitionPose) -> String {
        transitions[transition] ?? base
    }

    public func transitionClipFrame(
        for transition: PetTransitionPose,
        progress: Double
    ) -> PetTransitionArtworkFrame {
        let fallback = resourceName(for: transition)
        guard progress.isFinite,
              let frames = transitionClips[transition],
              frames.count >= 2 else {
            return PetTransitionArtworkFrame(
                currentResourceName: fallback,
                nextResourceName: fallback,
                blend: 0,
                fallbackResourceName: fallback
            )
        }

        let clampedProgress = min(1, max(0, progress))
        let framePosition = clampedProgress * Double(frames.count - 1)
        let currentIndex = min(
            frames.count - 1,
            Int(framePosition.rounded(.down))
        )
        let nextIndex = min(frames.count - 1, currentIndex + 1)
        let blend = currentIndex == nextIndex
            ? 0
            : framePosition - Double(currentIndex)
        return PetTransitionArtworkFrame(
            currentResourceName: frames[currentIndex],
            nextResourceName: frames[nextIndex],
            blend: blend,
            fallbackResourceName: fallback
        )
    }

    public func resourceName(
        for event: PetMotionEvent,
        frameIndex: Int?
    ) -> String {
        switch event {
        case .idle:
            return base
        case .walk:
            guard let frameIndex, walk.indices.contains(frameIndex) else {
                return base
            }
            return walk[frameIndex]
        case .idleAction1:
            return idleActions[0]
        case .idleAction2:
            return idleActions[1]
        case .lookAround:
            return personality[.peek] ?? base
        case .stretch:
            return personality[.stretch] ?? base
        case .perkUp:
            return personality[.perk] ?? base
        }
    }
}

private extension PetKind {
    var resourceDirectoryName: String {
        switch self {
        case .cat:
            "Cat"
        case .pauli:
            "Pauli"
        case .dog:
            "Dog"
        }
    }
}
