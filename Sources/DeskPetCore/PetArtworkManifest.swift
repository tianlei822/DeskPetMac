public enum PetPresentationState: Equatable, Sendable {
    case idle
    case blink
    case hover
    case pat
    case sleep
    case personality(PersonalityPose)
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
        walk + idleActions + [
            personality[.peek] ?? base,
            personality[.stretch] ?? base,
            personality[.perk] ?? base,
        ]
    }

    public func hasCompleteMotionSet(
        availableResourceNames: Set<String>
    ) -> Bool {
        motionResourceNames.allSatisfy(availableResourceNames.contains)
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
