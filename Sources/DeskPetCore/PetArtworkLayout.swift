public struct PetArtworkLayout: Equatable, Sendable {
    public let scale: Double
    public let verticalOffset: Double
    public let shadowWidth: Double
    public let shadowHeight: Double
    public let shadowVerticalOffset: Double

    public init(
        scale: Double,
        verticalOffset: Double,
        shadowWidth: Double,
        shadowHeight: Double,
        shadowVerticalOffset: Double
    ) {
        self.scale = scale
        self.verticalOffset = verticalOffset
        self.shadowWidth = shadowWidth
        self.shadowHeight = shadowHeight
        self.shadowVerticalOffset = shadowVerticalOffset
    }

    /// Resolves stable visual registration for the current full-body raster.
    /// The source artwork shares a square canvas, but its visible bounds and
    /// ground line vary substantially between upright and resting poses.
    public static func resolve(
        petKind: PetKind,
        resourceName: String
    ) -> PetArtworkLayout {
        let manifest = PetArtworkManifest(petKind: petKind)
        let isSleep = resourceName == manifest.sleep
        let isStretch = resourceName == manifest.resourceName(
            for: .personality(.stretch)
        )

        switch petKind {
        case .cat:
            if isSleep {
                return PetArtworkLayout(
                    scale: 1.10,
                    verticalOffset: 36,
                    shadowWidth: 150,
                    shadowHeight: 18,
                    shadowVerticalOffset: 79
                )
            }
            if isStretch {
                return PetArtworkLayout(
                    scale: 1.04,
                    verticalOffset: 0,
                    shadowWidth: 124,
                    shadowHeight: 16,
                    shadowVerticalOffset: 79
                )
            }
            return PetArtworkLayout(
                scale: 1.08,
                verticalOffset: registeredGroundOffset(
                    petKind: petKind,
                    resourceName: resourceName,
                    manifest: manifest,
                    scale: 1.08
                ),
                shadowWidth: 92,
                shadowHeight: 14,
                shadowVerticalOffset: 79
            )

        case .pauli:
            return PetArtworkLayout(
                scale: 0.96,
                verticalOffset: registeredGroundOffset(
                    petKind: petKind,
                    resourceName: resourceName,
                    manifest: manifest,
                    scale: 0.96
                ),
                shadowWidth: 88,
                shadowHeight: 14,
                shadowVerticalOffset: 79
            )

        case .dog:
            if isSleep {
                return PetArtworkLayout(
                    scale: 1.08,
                    verticalOffset: 25,
                    shadowWidth: 158,
                    shadowHeight: 18,
                    shadowVerticalOffset: 79
                )
            }
            if isStretch {
                return PetArtworkLayout(
                    scale: 0.98,
                    verticalOffset: 0,
                    shadowWidth: 136,
                    shadowHeight: 16,
                    shadowVerticalOffset: 79
                )
            }
            return PetArtworkLayout(
                scale: 0.98,
                verticalOffset: registeredGroundOffset(
                    petKind: petKind,
                    resourceName: resourceName,
                    manifest: manifest,
                    scale: 0.98
                ),
                shadowWidth: 104,
                shadowHeight: 15,
                shadowVerticalOffset: 79
            )
        }
    }

    private static func registeredGroundOffset(
        petKind: PetKind,
        resourceName: String,
        manifest: PetArtworkManifest,
        scale: Double
    ) -> Double {
        let registration: (
            base: Double,
            walk: [Double],
            transitions: [PetTransitionPose: Double]
        ) = switch petKind {
        case .cat:
            (
                1_079,
                [1_115, 1_115, 1_117, 1_117, 1_119, 1_117],
                [.anticipate: 1_073, .turn: 1_101, .settle: 1_049]
            )
        case .pauli:
            (
                1_185,
                [1_171, 1_180, 1_166, 1_177, 1_183, 1_182],
                [.anticipate: 1_141, .turn: 1_182, .settle: 1_188]
            )
        case .dog:
            (
                1_192,
                [1_178, 1_208, 1_203, 1_209, 1_211, 1_185],
                [.anticipate: 1_145, .turn: 1_141, .settle: 1_097]
            )
        }

        let source: (height: Double, bottom: Double)?
        if let frameIndex = manifest.walk.firstIndex(of: resourceName),
           registration.walk.indices.contains(frameIndex) {
            source = (1_254, registration.walk[frameIndex])
        } else if let pose = PetTransitionPose.allCases.first(where: {
            manifest.resourceName(for: $0) == resourceName
        }) {
            source = registration.transitions[pose].map { (1_254, $0) }
        } else {
            source = transitionClipSource(
                petKind: petKind,
                resourceName: resourceName,
                manifest: manifest
            )
        }

        guard let source else { return 0 }
        let baseGround = registration.base / 1_254
        let sourceGround = source.bottom / source.height
        return (baseGround - sourceGround) * 190 * scale
    }

    private static func transitionClipSource(
        petKind: PetKind,
        resourceName: String,
        manifest: PetArtworkManifest
    ) -> (height: Double, bottom: Double)? {
        let sources: [PetTransitionPose: [(Double, Double)]] = switch petKind {
        case .cat:
            [
                .anticipate: [(627, 603), (627, 592), (627, 577), (627, 586)],
                .turn: [(623, 553), (623, 587), (623, 567), (623, 562)],
                .settle: [(623, 576), (623, 543), (623, 533), (623, 558)],
            ]
        case .pauli:
            [
                .anticipate: [(623, 574), (623, 569), (623, 545), (623, 553)],
                .turn: [(623, 568), (623, 577), (623, 572), (623, 577)],
                .settle: [(623, 605), (623, 609), (623, 606), (623, 606)],
            ]
        case .dog:
            [
                .anticipate: [(623, 564), (623, 567), (623, 550), (623, 553)],
                .turn: [(623, 595), (623, 592), (623, 569), (623, 567)],
                .settle: [(623, 565), (623, 567), (623, 518), (623, 519)],
            ]
        }

        for pose in PetTransitionPose.allCases {
            guard let frames = manifest.transitionClips[pose],
                  let index = frames.firstIndex(of: resourceName),
                  let poseSources = sources[pose],
                  poseSources.indices.contains(index) else { continue }
            return poseSources[index]
        }
        return nil
    }
}
