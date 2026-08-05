import Testing

@testable import DeskPetCore

@Suite("Pet transition artwork clips")
struct PetTransitionArtworkClipTests {
  @Test("every pet exposes four ordered frames for each transition")
  func everyPetExposesOrderedTransitionFrames() {
    for petKind in PetKind.allCases {
      let manifest = PetArtworkManifest(petKind: petKind)

      #expect(manifest.transitionClipResourceNames.count == 12)
      #expect(manifest.preloadResourceNames.count == 1)
      for pose in PetTransitionPose.allCases {
        let frames = manifest.transitionClips[pose]
        #expect(frames?.count == 4)
        #expect(frames?.first?.hasSuffix("/RootMotion/\(pose.rawValue)1") == true)
        #expect(frames?.last?.hasSuffix("/RootMotion/\(pose.rawValue)4") == true)
      }
    }
  }

  @Test("all clip frames register to the idle foot baseline")
  func clipFramesRegisterToIdleFootBaseline() {
    typealias SourceFrame = (height: Double, bottom: Double)
    let baseSources: [PetKind: SourceFrame] = [
      .cat: (1_254, 1_079),
      .pauli: (1_254, 1_185),
      .dog: (1_254, 1_192),
    ]
    let clipSources: [PetKind: [PetTransitionPose: [SourceFrame]]] = [
      .cat: [
        .anticipate: [(627, 603), (627, 592), (627, 577), (627, 586)],
        .turn: [(623, 553), (623, 587), (623, 567), (623, 562)],
        .settle: [(623, 576), (623, 543), (623, 533), (623, 558)],
      ],
      .pauli: [
        .anticipate: [(623, 574), (623, 569), (623, 545), (623, 553)],
        .turn: [(623, 568), (623, 577), (623, 572), (623, 577)],
        .settle: [(623, 605), (623, 609), (623, 606), (623, 606)],
      ],
      .dog: [
        .anticipate: [(623, 564), (623, 567), (623, 550), (623, 553)],
        .turn: [(623, 595), (623, 592), (623, 569), (623, 567)],
        .settle: [(623, 565), (623, 567), (623, 518), (623, 519)],
      ],
    ]

    for petKind in PetKind.allCases {
      let manifest = PetArtworkManifest(petKind: petKind)
      let base = baseSources[petKind]!
      let baseLayout = PetArtworkLayout.resolve(
        petKind: petKind,
        resourceName: manifest.base
      )
      let baseLine = base.bottom / base.height * 190 * baseLayout.scale

      for pose in PetTransitionPose.allCases {
        let resources = manifest.transitionClips[pose]!
        let sources = clipSources[petKind]![pose]!
        for (resourceName, source) in zip(resources, sources) {
          let layout = PetArtworkLayout.resolve(
            petKind: petKind,
            resourceName: resourceName
          )
          let renderedLine = source.bottom / source.height * 190
            * layout.scale + layout.verticalOffset
          #expect(abs(renderedLine - baseLine) < 0.25)
        }
      }
    }
  }

  @Test("phase progress blends adjacent clip frames and clamps endpoints")
  func phaseProgressBlendsAdjacentFrames() {
    let manifest = PetArtworkManifest(petKind: .cat)

    let start = manifest.transitionClipFrame(for: .anticipate, progress: -1)
    #expect(start.currentResourceName == "Pets/Cat/RootMotion/anticipate1")
    #expect(start.nextResourceName == "Pets/Cat/RootMotion/anticipate2")
    #expect(start.blend == 0)

    let midpoint = manifest.transitionClipFrame(
      for: .anticipate,
      progress: 0.5
    )
    #expect(midpoint.currentResourceName == "Pets/Cat/RootMotion/anticipate2")
    #expect(midpoint.nextResourceName == "Pets/Cat/RootMotion/anticipate3")
    #expect(midpoint.blend == 0.5)

    let end = manifest.transitionClipFrame(for: .anticipate, progress: 2)
    #expect(end.currentResourceName == "Pets/Cat/RootMotion/anticipate4")
    #expect(end.nextResourceName == "Pets/Cat/RootMotion/anticipate4")
    #expect(end.blend == 0)
  }

  @Test("invalid progress uses the legacy transition pose as a safe fallback")
  func invalidProgressUsesLegacyPose() {
    let manifest = PetArtworkManifest(petKind: .pauli)
    let frame = manifest.transitionClipFrame(
      for: .settle,
      progress: .nan
    )

    #expect(frame.currentResourceName == "Pets/Pauli/settle")
    #expect(frame.nextResourceName == "Pets/Pauli/settle")
    #expect(frame.fallbackResourceName == "Pets/Pauli/settle")
    #expect(frame.blend == 0)
  }

  @Test("available clip frames preserve interpolation")
  func availableFramesPreserveInterpolation() {
    let manifest = PetArtworkManifest(petKind: .dog)
    let frame = manifest.transitionClipFrame(for: .turn, progress: 0.5)
    let layers = PetTransitionArtworkResolver.resolve(
      frame: frame,
      availableResourceNames: Set(
        manifest.transitionClipResourceNames
          + manifest.transitionResourceNames
      ),
      baseFallbackResourceName: manifest.base
    )

    #expect(layers.currentResourceName == "Pets/Dog/RootMotion/turn2")
    #expect(layers.nextResourceName == "Pets/Dog/RootMotion/turn3")
    #expect(layers.blend == 0.5)
    #expect(layers.dominantResourceName == "Pets/Dog/RootMotion/turn3")
  }

  @Test("missing clip frames fall back to the legacy transition pose")
  func missingFramesUseLegacyTransitionPose() {
    let manifest = PetArtworkManifest(petKind: .cat)
    let frame = manifest.transitionClipFrame(for: .settle, progress: 0.5)
    let layers = PetTransitionArtworkResolver.resolve(
      frame: frame,
      availableResourceNames: [frame.fallbackResourceName, manifest.base],
      baseFallbackResourceName: manifest.base
    )

    #expect(layers.currentResourceName == "Pets/Cat/settle")
    #expect(layers.nextResourceName == "Pets/Cat/settle")
    #expect(layers.blend == 0)
    #expect(layers.dominantResourceName == "Pets/Cat/settle")
  }

  @Test("missing legacy pose falls back to the pet base artwork")
  func missingLegacyPoseUsesBaseArtwork() {
    let manifest = PetArtworkManifest(petKind: .pauli)
    let frame = manifest.transitionClipFrame(for: .anticipate, progress: 0.5)
    let layers = PetTransitionArtworkResolver.resolve(
      frame: frame,
      availableResourceNames: [manifest.base],
      baseFallbackResourceName: manifest.base
    )

    #expect(layers.currentResourceName == manifest.base)
    #expect(layers.nextResourceName == manifest.base)
    #expect(layers.blend == 0)
  }
}
