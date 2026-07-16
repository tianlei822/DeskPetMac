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
    public let personality: [PersonalityPose: String]

    public init(petKind: PetKind) {
        let directory = "Pets/\(petKind.resourceDirectoryName)"

        self.petKind = petKind
        self.base = "\(directory)/base"
        self.blink = "\(directory)/blink"
        self.hover = "\(directory)/hover"
        self.pat = "\(directory)/pat"
        self.sleep = "\(directory)/sleep"
        self.personality = Dictionary(
            uniqueKeysWithValues: PersonalityPose.allCases.map { pose in
                (pose, "\(directory)/\(pose.rawValue)")
            }
        )
    }

    public var fallbackResourceName: String {
        base
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
