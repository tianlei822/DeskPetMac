# Rich Pet Motion and Realistic Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add convincing occasional gait cycles and pet-specific idle actions, then replace flat weather overlays with depth-aware procedural atmosphere, local lighting, and ground feedback.

**Architecture:** A pure `DeskPetCore` motion director selects deterministic low-priority actions and gait frames, while the existing artwork manifest expands to an all-or-nothing motion set. Weather moves to a pure scene profile and deterministic particle layout, rendered by focused SwiftUI Canvas, atmosphere, and artwork-lighting views inside a `260 x 290` transparent window.

**Tech Stack:** Swift 6, SwiftUI, Canvas, AppKit, ImageIO, Swift Testing, SwiftPM resources, existing app packaging and ad-hoc signing scripts.

**Approved spec:** `docs/superpowers/specs/2026-07-16-rich-pet-motion-realistic-weather-design.md`

**Repository constraint:** Do not commit or push unless the user explicitly asks. Replace per-task commit steps with staged-scope review and `git diff --check` checkpoints.

---

## File Structure

- Create `Sources/DeskPetCore/PetMotionDirector.swift`: deterministic motion scheduling, frame phase, transforms, and priority eligibility.
- Modify `Sources/DeskPetCore/PetArtworkManifest.swift`: six gait frames, two idle-action frames, and complete-motion-set validation.
- Create `Sources/DeskPetCore/PetWeatherReaction.swift`: shared weather-reaction enum retained while the old profile is removed.
- Create `Sources/DeskPetCore/WeatherSceneProfile.swift`: depth budgets, wind, transitions, weather reactions, and environment capabilities.
- Create `Sources/DeskPetCore/WeatherParticleLayout.swift`: deterministic particle seeds and time-based particle state.
- Remove `Sources/DeskPetCore/WeatherAnimationProfile.swift` after all callers migrate to `WeatherSceneProfile`.
- Modify `Sources/DeskPetMac/RealisticPetBody.swift`: preloading, gait frame selection, synchronized transforms, and contact shadow.
- Create `Sources/DeskPetMac/WeatherParticleField.swift`: Canvas rain, snow, dust, splashes, ripples, and accumulation light.
- Modify `Sources/DeskPetMac/WeatherAtmosphere.swift`: orchestration, cloud masses, fog volumes, sun rays, and storm illumination.
- Create `Sources/DeskPetMac/PetWeatherLighting.swift`: artwork-local lighting and Pauli accents moved out of the atmosphere file.
- Modify `Sources/DeskPetMac/PetWindowView.swift`: expanded scene composition, new profile, motion preview hook, and interaction-safe weather layers.
- Modify `Sources/DeskPetMac/DeskPetMacApp.swift`: fixed `260 x 290` content size.
- Add 24 PNG files under `Sources/DeskPetMac/Resources/Pets/{Cat,Pauli,Dog}`: `walk1...walk6`, `idleAction1`, and `idleAction2`.
- Modify `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`: motion, manifest, weather profile, particle determinism, budgets, and Reduce Motion tests.
- Modify `README.md`: richer motion/weather description, expanded window note, and debug motion preview instructions.

### Task 1: Add a Pure Pet Motion Director

**Files:**
- Create: `Sources/DeskPetCore/PetMotionDirector.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Write failing motion schedule tests**

Append the following suite after `PetArtworkManifestTests`:

```swift
@Suite("Pet motion director")
struct PetMotionDirectorTests {
    @Test("idle intervals stay between twelve and thirty seconds")
    func idleIntervalsStayBounded() {
        for pet in PetKind.allCases {
            for seed in [0, 1, 17, Int.max, Int.min] {
                let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
                #expect(cadence.idleDuration >= 12)
                #expect(cadence.idleDuration <= 30)
            }
        }
    }

    @Test("walks contain two through four steps and valid frames")
    func walksStayBounded() {
        for pet in PetKind.allCases {
            for second in stride(from: 0.0, through: 240.0, by: 0.05) {
                let frame = PetMotionDirector.frame(
                    pet: pet,
                    time: second,
                    seed: 31,
                    isEligible: true,
                    reduceMotion: false
                )
                if frame.event == .walk {
                    #expect((2...4).contains(frame.stepCount))
                    #expect(frame.artworkFrameIndex != nil)
                    #expect((0...5).contains(frame.artworkFrameIndex ?? -1))
                }
            }
        }
    }

    @Test("each pet uses distinct cadence")
    func cadenceIsCharacterSpecific() {
        let cat = PetMotionDirector.cadence(for: .cat, seed: 9)
        let pauli = PetMotionDirector.cadence(for: .pauli, seed: 9)
        let dog = PetMotionDirector.cadence(for: .dog, seed: 9)

        #expect(cat.stepsPerSecond != pauli.stepsPerSecond)
        #expect(pauli.stepsPerSecond != dog.stepsPerSecond)
        #expect(cat.verticalAmplitude != dog.verticalAmplitude)
    }

    @Test("priority and Reduce Motion force stable idle")
    func blockedMotionIsStable() {
        for pet in PetKind.allCases {
            let blocked = PetMotionDirector.frame(
                pet: pet,
                time: 29,
                seed: 0,
                isEligible: false,
                reduceMotion: false
            )
            let reduced = PetMotionDirector.frame(
                pet: pet,
                time: 29,
                seed: 0,
                isEligible: true,
                reduceMotion: true
            )

            #expect(blocked == .idle)
            #expect(reduced == .idle)
        }
    }

    @Test("the same inputs always produce the same frame")
    func motionIsDeterministic() {
        let first = PetMotionDirector.frame(
            pet: .dog,
            time: 123.45,
            seed: 73,
            isEligible: true,
            reduceMotion: false
        )
        let second = PetMotionDirector.frame(
            pet: .dog,
            time: 123.45,
            seed: 73,
            isEligible: true,
            reduceMotion: false
        )

        #expect(first == second)
    }
}
```

- [ ] **Step 2: Run the focused suite and confirm RED**

Run:

```bash
swift test --filter PetMotionDirectorTests
```

Expected: compilation fails because `PetMotionDirector`, `PetMotionEvent`, and `PetMotionFrame` do not exist.

- [ ] **Step 3: Implement the deterministic director**

Create `Sources/DeskPetCore/PetMotionDirector.swift` with these public contracts and calculations:

```swift
public enum PetMotionEvent: String, CaseIterable, Equatable, Sendable {
    case idle
    case walk
    case idleAction1
    case idleAction2
}

public struct PetMotionCadence: Equatable, Sendable {
    public let idleDuration: Double
    public let stepsPerSecond: Double
    public let verticalAmplitude: Double
    public let horizontalAmplitude: Double

    public init(
        idleDuration: Double,
        stepsPerSecond: Double,
        verticalAmplitude: Double,
        horizontalAmplitude: Double
    ) {
        self.idleDuration = idleDuration
        self.stepsPerSecond = stepsPerSecond
        self.verticalAmplitude = verticalAmplitude
        self.horizontalAmplitude = horizontalAmplitude
    }
}

public struct PetMotionFrame: Equatable, Sendable {
    public let event: PetMotionEvent
    public let artworkFrameIndex: Int?
    public let stepCount: Int
    public let eventProgress: Double
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let tiltDegrees: Double
    public let shadowScale: Double
    public let shadowOffset: Double

    public init(
        event: PetMotionEvent,
        artworkFrameIndex: Int?,
        stepCount: Int,
        eventProgress: Double,
        horizontalOffset: Double,
        verticalOffset: Double,
        tiltDegrees: Double,
        shadowScale: Double,
        shadowOffset: Double
    ) {
        self.event = event
        self.artworkFrameIndex = artworkFrameIndex
        self.stepCount = stepCount
        self.eventProgress = eventProgress
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.tiltDegrees = tiltDegrees
        self.shadowScale = shadowScale
        self.shadowOffset = shadowOffset
    }

    public static let idle = PetMotionFrame(
        event: .idle,
        artworkFrameIndex: nil,
        stepCount: 0,
        eventProgress: 0,
        horizontalOffset: 0,
        verticalOffset: 0,
        tiltDegrees: 0,
        shadowScale: 1,
        shadowOffset: 0
    )
}

public enum PetMotionDirector {
    public static func cadence(for pet: PetKind, seed: Int) -> PetMotionCadence {
        let idleDuration = 12 + Double(positiveHash(seed, salt: pet.hashSalt) % 19)
        switch pet {
        case .cat:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.55,
                verticalAmplitude: 1.4,
                horizontalAmplitude: 2.2
            )
        case .pauli:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.35,
                verticalAmplitude: 1.0,
                horizontalAmplitude: 1.6
            )
        case .dog:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.8,
                verticalAmplitude: 2.0,
                horizontalAmplitude: 2.6
            )
        }
    }

    public static func frame(
        pet: PetKind,
        time: Double,
        seed: Int,
        isEligible: Bool,
        reduceMotion: Bool
    ) -> PetMotionFrame {
        guard isEligible, !reduceMotion else { return .idle }

        let cadence = cadence(for: pet, seed: seed)
        let eventWindow = 3.2
        let cycleDuration = cadence.idleDuration + eventWindow
        let normalizedTime = euclideanModulo(time, modulus: cycleDuration)
        guard normalizedTime >= cadence.idleDuration else { return .idle }

        let cycleIndex = Int(floor(time / cycleDuration))
        let eventHash = positiveHash(seed ^ cycleIndex, salt: pet.hashSalt + 101)
        let eventSelector = eventHash % 5
        let event: PetMotionEvent = switch eventSelector {
        case 0: .idleAction1
        case 1: .idleAction2
        case 2, 3, 4: .walk
        default: .idle
        }
        let elapsed = normalizedTime - cadence.idleDuration

        if event != .walk {
            let duration = 1.6
            guard elapsed < duration else { return .idle }
            let progress = elapsed / duration
            return microActionFrame(event: event, pet: pet, progress: progress)
        }

        let stepCount = 2 + eventHash % 3
        let duration = Double(stepCount) / cadence.stepsPerSecond
        guard elapsed < duration else { return .idle }
        let progress = elapsed / duration
        let frameIndex = min(5, Int(progress * Double(stepCount * 3)) % 6)
        let phase = progress * Double(stepCount) * .pi
        let contact = abs(sin(phase))

        return PetMotionFrame(
            event: .walk,
            artworkFrameIndex: frameIndex,
            stepCount: stepCount,
            eventProgress: progress,
            horizontalOffset: sin(phase * 0.5) * cadence.horizontalAmplitude,
            verticalOffset: -contact * cadence.verticalAmplitude,
            tiltDegrees: sin(phase) * pet.walkTiltAmplitude,
            shadowScale: 1 - contact * 0.08,
            shadowOffset: sin(phase) * cadence.horizontalAmplitude * 0.35
        )
    }

    private static func microActionFrame(
        event: PetMotionEvent,
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        let envelope = sin(progress * .pi)
        let direction = event == .idleAction1 ? -1.0 : 1.0
        return PetMotionFrame(
            event: event,
            artworkFrameIndex: nil,
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: direction * envelope * pet.microActionOffset,
            verticalOffset: -envelope * pet.microActionLift,
            tiltDegrees: direction * envelope * pet.microActionTilt,
            shadowScale: 1 - envelope * 0.035,
            shadowOffset: direction * envelope * 0.8
        )
    }

    private static func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func positiveHash(_ value: Int, salt: Int) -> Int {
        var mixed = UInt(bitPattern: value) &+ UInt(bitPattern: salt) &* 0x9E3779B185EBCA87
        mixed ^= mixed >> 30
        mixed &*= 0xBF58476D1CE4E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D049BB133111EB
        mixed ^= mixed >> 31
        return Int(mixed & UInt(Int.max))
    }
}

private extension PetKind {
    var hashSalt: Int {
        switch self {
        case .cat: 11
        case .pauli: 23
        case .dog: 37
        }
    }

    var walkTiltAmplitude: Double {
        switch self {
        case .cat: 0.8
        case .pauli: 0.45
        case .dog: 1.15
        }
    }

    var microActionOffset: Double {
        switch self {
        case .cat: 1.2
        case .pauli: 0.8
        case .dog: 1.5
        }
    }

    var microActionLift: Double {
        switch self {
        case .cat: 0.7
        case .pauli: 0.4
        case .dog: 1.1
        }
    }

    var microActionTilt: Double {
        switch self {
        case .cat: 1.4
        case .pauli: 0.8
        case .dog: 2.0
        }
    }
}
```

- [ ] **Step 4: Run focused and full tests**

Run:

```bash
swift test --filter PetMotionDirectorTests
swift test
```

Expected: the new suite and all existing suites pass.

- [ ] **Step 5: Review the scoped diff**

Run:

```bash
git diff --check
git diff -- Sources/DeskPetCore/PetMotionDirector.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift
```

Expected: only the motion director and its tests are in scope.

### Task 2: Extend the Artwork Manifest with Complete Motion Sets

**Files:**
- Modify: `Sources/DeskPetCore/PetArtworkManifest.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Write failing manifest tests**

Add these tests to `PetArtworkManifestTests`:

```swift
@Test("each pet exposes six gait frames and two idle actions")
func motionArtworkNamesAreComplete() {
    for pet in PetKind.allCases {
        let manifest = PetArtworkManifest(petKind: pet)
        #expect(manifest.walk.count == 6)
        #expect(manifest.idleActions.count == 2)
        #expect(manifest.walk[0].hasSuffix("/walk1"))
        #expect(manifest.walk[5].hasSuffix("/walk6"))
        #expect(manifest.idleActions[0].hasSuffix("/idleAction1"))
        #expect(manifest.idleActions[1].hasSuffix("/idleAction2"))
        #expect(manifest.motionResourceNames.count == 8)
    }
}

@Test("partial gait availability disables the complete motion set")
func partialMotionSetsAreRejected() {
    let manifest = PetArtworkManifest(petKind: .cat)
    let complete = Set(manifest.motionResourceNames)
    let partial = Set(manifest.motionResourceNames.dropLast())

    #expect(manifest.hasCompleteMotionSet(availableResourceNames: complete))
    #expect(!manifest.hasCompleteMotionSet(availableResourceNames: partial))
}

@Test("motion frames map to stable resource names")
func motionFramesMapToResources() {
    let manifest = PetArtworkManifest(petKind: .dog)
    #expect(manifest.resourceName(for: .walk, frameIndex: 0) == "Pets/Dog/walk1")
    #expect(manifest.resourceName(for: .walk, frameIndex: 5) == "Pets/Dog/walk6")
    #expect(manifest.resourceName(for: .idleAction1, frameIndex: nil) == "Pets/Dog/idleAction1")
    #expect(manifest.resourceName(for: .idleAction2, frameIndex: nil) == "Pets/Dog/idleAction2")
    #expect(manifest.resourceName(for: .idle, frameIndex: nil) == "Pets/Dog/base")
}
```

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter PetArtworkManifestTests
```

Expected: compilation fails because `walk`, `idleActions`, `motionResourceNames`, and the new mapping API do not exist.

- [ ] **Step 3: Add the manifest APIs**

Add the stored properties in `PetArtworkManifest`:

```swift
public let walk: [String]
public let idleActions: [String]
```

Initialize them immediately after `sleep`:

```swift
self.walk = (1...6).map { "\(directory)/walk\($0)" }
self.idleActions = (1...2).map { "\(directory)/idleAction\($0)" }
```

Add these APIs:

```swift
public var motionResourceNames: [String] {
    walk + idleActions
}

public func hasCompleteMotionSet(
    availableResourceNames: Set<String>
) -> Bool {
    motionResourceNames.allSatisfy(availableResourceNames.contains)
}

public func resourceName(
    for event: PetMotionEvent,
    frameIndex: Int?
) -> String {
    switch event {
    case .idle:
        base
    case .walk:
        guard let frameIndex, walk.indices.contains(frameIndex) else { return base }
        return walk[frameIndex]
    case .idleAction1:
        idleActions[0]
    case .idleAction2:
        idleActions[1]
    }
}
```

- [ ] **Step 4: Run manifest and full tests**

Run:

```bash
swift test --filter PetArtworkManifestTests
swift test
git diff --check
```

Expected: all tests pass and the diff check is clean.

### Task 3: Generate and Validate the 24 Motion Assets

**Files:**
- Add: `Sources/DeskPetMac/Resources/Pets/Cat/walk1.png` through `walk6.png`
- Add: `Sources/DeskPetMac/Resources/Pets/Cat/idleAction1.png`
- Add: `Sources/DeskPetMac/Resources/Pets/Cat/idleAction2.png`
- Add: equivalent eight files for `Pauli`
- Add: equivalent eight files for `Dog`

- [ ] **Step 1: Record the pre-generation resource contract**

Run:

```bash
find Sources/DeskPetMac/Resources/Pets -type f -name '*.png' | sort
```

Expected: exactly 27 existing files, nine per pet, and none of the new motion names.

- [ ] **Step 2: Generate Cat motion frames with the imagegen skill**

Use `Sources/DeskPetMac/Resources/Pets/Cat/base.png` as the primary reference for every frame. Use this shared prompt prefix for all Cat frames:

```text
Edit the referenced transparent-background realistic 3D orange tabby Cat asset. Preserve the exact identity, fur pattern, face, camera, scale, warm studio lighting, transparent background, and contact point. Create one frame of a seamless in-place gait or idle action. Keep the full body inside frame with no text, props, border, duplicated limbs, or background. Output a square transparent PNG.
```

Append the following frame-specific instruction and save to the matching path:

```text
walk1: left front paw starts forward, right rear begins push-off, weight low and centered.
walk2: left front paw reaches contact, shoulders shift subtly forward, tail counter-swings right.
walk3: body passes over planted left front paw, right front paw begins lift.
walk4: right front paw moves forward, left rear begins push-off, tail counter-swings left.
walk5: right front paw reaches contact, shoulders shift subtly forward.
walk6: body returns toward the neutral base pose, ready to loop into walk1.
idleAction1: Cat pauses to groom one raised front paw, relaxed eyes, balanced posture.
idleAction2: Cat stands alert with ears and head turned toward a faint sound, body still neutral.
```

- [ ] **Step 3: Generate Pauli motion frames with the imagegen skill**

Use `Sources/DeskPetMac/Resources/Pets/Pauli/base.png` as the primary reference. Shared prefix:

```text
Edit the referenced transparent-background realistic PBR desk robot Pauli asset. Preserve the exact ivory and teal identity, face display, proportions, metal/plastic materials, camera, scale, studio lighting, transparent background, and foot contact point. Create one frame of a seamless mechanical in-place gait or idle calibration action. Keep the full body inside frame with no text, props, border, extra limbs, or background. Output a square transparent PNG.
```

Frame instructions:

```text
walk1: left foot begins precise forward lift, torso counters slightly right.
walk2: left foot reaches forward contact, knee and ankle mechanisms visibly articulated.
walk3: torso stabilizes over the left foot while the right foot unloads.
walk4: right foot begins precise forward lift, torso counters slightly left.
walk5: right foot reaches forward contact with visible mechanical articulation.
walk6: posture corrects back toward the neutral base pose, ready to loop.
idleAction1: Pauli performs an environmental scan with head/display turned slightly and antenna attentive.
idleAction2: Pauli performs a precise antenna and torso calibration with a small balanced adjustment.
```

- [ ] **Step 4: Generate Dog motion frames with the imagegen skill**

Use `Sources/DeskPetMac/Resources/Pets/Dog/base.png` as the primary reference. Shared prefix:

```text
Edit the referenced transparent-background realistic 3D golden-brown floppy-eared Dog asset. Preserve the exact identity, fur, face, camera, scale, warm studio lighting, transparent background, and paw contact point. Create one frame of a seamless energetic in-place gait or friendly idle action. Keep the full body inside frame with no text, props, border, duplicated limbs, or background. Output a square transparent PNG.
```

Frame instructions:

```text
walk1: left front paw lifts forward, right rear pushes, head and ears follow naturally.
walk2: left front paw reaches contact, shoulders move forward, tail swings right.
walk3: body passes over the planted left paw, right front paw begins lift.
walk4: right front paw moves forward, left rear pushes, tail swings left.
walk5: right front paw reaches contact, shoulders settle forward.
walk6: body returns toward the neutral eager base pose, ready to loop.
idleAction1: Dog performs a friendly head tilt with relaxed ears and stable feet.
idleAction2: Dog raises one front paw in anticipation while keeping a balanced stance.
```

- [ ] **Step 5: Validate dimensions, alpha, count, and naming**

Run:

```bash
find Sources/DeskPetMac/Resources/Pets -type f -name '*.png' | wc -l
find Sources/DeskPetMac/Resources/Pets -type f -name 'walk*.png' | wc -l
find Sources/DeskPetMac/Resources/Pets -type f -name 'idleAction*.png' | wc -l
sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/DeskPetMac/Resources/Pets/Cat/walk1.png Sources/DeskPetMac/Resources/Pets/Pauli/walk1.png Sources/DeskPetMac/Resources/Pets/Dog/walk1.png
```

Expected:

- Total PNG count: `51`.
- Walk PNG count: `18`.
- Idle-action PNG count: `6`.
- Representative files are square and report `hasAlpha: yes`.

- [ ] **Step 6: Inspect contact-sheet consistency**

Create temporary contact sheets outside the source tree using the existing image inspection workflow, then verify:

- No identity drift between frames.
- No duplicated/missing legs or paws.
- Camera, scale, lighting, and transparent background remain stable.
- Frame-to-frame contact point movement is small enough for in-place animation.

If a frame fails, regenerate only that frame using the base image and its nearest accepted gait neighbor as references.

- [ ] **Step 7: Review asset-only scope**

Run:

```bash
git status --short Sources/DeskPetMac/Resources/Pets
git diff --check
```

Expected: exactly 24 new PNGs and no modified existing artwork.

### Task 4: Add Motion Preloading, Memory Budgeting, and Complete-Set Fallback

**Files:**
- Modify: `Sources/DeskPetMac/RealisticPetBody.swift`

- [ ] **Step 1: Establish a failing source contract**

Run:

```bash
rg -n "totalCostLimit|preloadMotionArtwork|hasCompleteMotionArtwork" Sources/DeskPetMac/RealisticPetBody.swift
```

Expected: no matches.

- [ ] **Step 2: Replace the six-image cache limit with a memory budget**

Update the cache initialization:

```swift
private static let cache: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 32
    cache.totalCostLimit = 64 * 1024 * 1024
    return cache
}()
```

When caching the thumbnail, pass its decoded cost:

```swift
let cost = thumbnail.bytesPerRow * thumbnail.height
cache.setObject(image, forKey: cacheKey, cost: cost)
```

- [ ] **Step 3: Add cooperative preloading and complete-set detection**

Add these `@MainActor` APIs to `PetArtworkLoader`:

```swift
static func preloadMotionArtwork(for kind: PetKind) async -> Bool {
    let manifest = PetArtworkManifest(petKind: kind)
    var available = Set<String>()

    for resourceName in manifest.motionResourceNames {
        if image(named: resourceName) != nil {
            available.insert(resourceName)
        }
        await Task.yield()
    }

    return manifest.hasCompleteMotionSet(availableResourceNames: available)
}

static func hasCompleteMotionArtwork(for kind: PetKind) -> Bool {
    let manifest = PetArtworkManifest(petKind: kind)
    let available = Set(
        manifest.motionResourceNames.filter { image(named: $0) != nil }
    )
    return manifest.hasCompleteMotionSet(availableResourceNames: available)
}
```

- [ ] **Step 4: Build and inspect the loader**

Run:

```bash
swift build
rg -n "countLimit = 32|totalCostLimit|preloadMotionArtwork|hasCompleteMotionArtwork" Sources/DeskPetMac/RealisticPetBody.swift
git diff --check
```

Expected: build passes; loader uses the bounded cache and all-or-nothing motion check.

### Task 5: Render Gait Frames, Micro-Actions, and Contact Shadow

**Files:**
- Modify: `Sources/DeskPetMac/RealisticPetBody.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Add motion readiness and a stable pet seed**

Add state:

```swift
@State private var hasCompleteMotionArtwork = false
```

Add a stable seed helper:

```swift
private var motionSeed: Int {
    switch kind {
    case .cat: 1_031
    case .pauli: 2_047
    case .dog: 4_093
    }
}
```

Add preloading to the outer view:

```swift
.task(id: kind) {
    hasCompleteMotionArtwork = await PetArtworkLoader.preloadMotionArtwork(for: kind)
}
```

- [ ] **Step 2: Derive low-priority motion only when eligible**

Add:

```swift
private var allowsScheduledMotion: Bool {
    hasCompleteMotionArtwork
        && !isSleeping
        && !isDancing
        && personalityPose == nil
        && !isShowingPat
        && !isHovering
}

private func scheduledMotion(at time: TimeInterval) -> PetMotionFrame {
    PetMotionDirector.frame(
        pet: kind,
        time: time,
        seed: motionSeed,
        isEligible: allowsScheduledMotion,
        reduceMotion: reduceMotion
    )
}
```

- [ ] **Step 3: Select high-priority artwork before scheduled motion**

Replace `presentationState(at:)` with a resource-name function:

```swift
private func requestedResourceName(
    manifest: PetArtworkManifest,
    time: TimeInterval,
    motion: PetMotionFrame
) -> String {
    if isSleeping { return manifest.resourceName(for: .sleep) }
    if let personalityPose {
        return manifest.resourceName(for: .personality(personalityPose))
    }
    if isShowingPat { return manifest.resourceName(for: .pat) }
    if isHovering { return manifest.resourceName(for: .hover) }
    if motion.event != .idle {
        return manifest.resourceName(
            for: motion.event,
            frameIndex: motion.artworkFrameIndex
        )
    }
    if Int(time * 1.2).isMultiple(of: 7) {
        return manifest.resourceName(for: .blink)
    }
    return manifest.base
}
```

Inside the timeline, derive and use it:

```swift
let motion = scheduledMotion(at: time)
let requested = requestedResourceName(
    manifest: manifest,
    time: time,
    motion: motion
)
```

- [ ] **Step 4: Add a synchronized contact shadow**

Place this behind `artworkImage(artwork)` in the realistic body `ZStack`:

```swift
Ellipse()
    .fill(Color.black.opacity(0.12))
    .frame(width: 92, height: 15)
    .blur(radius: 7)
    .scaleEffect(x: CGFloat(motion.shadowScale), y: 1)
    .offset(x: CGFloat(motion.shadowOffset), y: 68)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
```

- [ ] **Step 5: Compose motion transforms below interaction transforms**

Add motion to the existing scale, tilt, and offset chain:

```swift
.rotationEffect(
    .degrees(
        animatedTilt(at: time)
            + weatherTilt(at: time)
            + motion.tiltDegrees
    )
)
.offset(composedOffset(at: time, motion: motion))
```

Update `composedOffset`:

```swift
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
```

Change `animatedOffset` to accept the motion frame:

```swift
private func animatedOffset(
    at time: TimeInterval,
    motion: PetMotionFrame
) -> CGSize {
    guard !reduceMotion else { return .zero }
    if isDancing {
        return CGSize(width: 0, height: abs(sin(time * 9.0)) * -7.0)
    }
    let idleHeight = idleHeight(at: time, motion: motion)
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
```

Reduce the generic idle bob while scheduled motion is active by replacing the inline switch with:

```swift
private func idleHeight(
    at time: TimeInterval,
    motion: PetMotionFrame
) -> CGFloat {
    guard motion.event == .idle else { return 0 }
    switch kind {
    case .cat:
        return sin(time * 2.0) * 1.5 * idleAmplitudeMultiplier
    case .pauli:
        return sin(time * 2.8) * 2.0 * idleAmplitudeMultiplier
    case .dog:
        return sin(time * 2.3) * 1.8 * idleAmplitudeMultiplier
    }
}
```

Use `let idleHeight = idleHeight(at: time, motion: motion)` in `animatedOffset` so gait does not stack with the old float.

- [ ] **Step 6: Add a debug-only forced motion preview**

In `PetWindowView`, add:

```swift
private var motionPreview: PetMotionEvent? {
    #if DEBUG
    guard let raw = ProcessInfo.processInfo.environment["DESKPET_MOTION_PREVIEW"] else {
        return nil
    }
    return PetMotionEvent(rawValue: raw)
    #else
    return nil
    #endif
}
```

Add this stored input to `RealisticPetBody` and pass `motionPreview: motionPreview` from `PetWindowView`:

```swift
let motionPreview: PetMotionEvent?
```

In `scheduledMotion(at:)`, force a stable preview frame when the value is non-nil:

```swift
if let motionPreview {
    return PetMotionDirector.previewFrame(
        pet: kind,
        event: motionPreview,
        time: time,
        reduceMotion: reduceMotion
    )
}
```

Add `previewFrame` to `PetMotionDirector` by reusing the production gait/micro-action calculation rather than duplicating transform constants.

First extract the inline walk calculation from `frame` into:

```swift
private static func walkFrame(
    pet: PetKind,
    cadence: PetMotionCadence,
    stepCount: Int,
    elapsed: Double
) -> PetMotionFrame {
    let duration = Double(stepCount) / cadence.stepsPerSecond
    guard elapsed < duration else { return .idle }
    let progress = elapsed / duration
    let frameIndex = Int(progress * Double(stepCount * 3)) % 6
    let phase = progress * Double(stepCount) * .pi
    let contact = abs(sin(phase))
    return PetMotionFrame(
        event: .walk,
        artworkFrameIndex: frameIndex,
        stepCount: stepCount,
        eventProgress: progress,
        horizontalOffset: sin(phase * 0.5) * cadence.horizontalAmplitude,
        verticalOffset: -contact * cadence.verticalAmplitude,
        tiltDegrees: sin(phase) * pet.walkTiltAmplitude,
        shadowScale: 1 - contact * 0.08,
        shadowOffset: sin(phase) * cadence.horizontalAmplitude * 0.35
    )
}
```

Change the production walk branch to:

```swift
return walkFrame(
    pet: pet,
    cadence: cadence,
    stepCount: stepCount,
    elapsed: elapsed
)
```

Then add:

```swift
public static func previewFrame(
    pet: PetKind,
    event: PetMotionEvent,
    time: Double,
    reduceMotion: Bool
) -> PetMotionFrame {
    guard !reduceMotion else { return .idle }
    switch event {
    case .idle:
        return .idle
    case .walk:
        let cadence = cadence(for: pet, seed: 0)
        let stepCount = 4
        let duration = Double(stepCount) / cadence.stepsPerSecond
        return walkFrame(
            pet: pet,
            cadence: cadence,
            stepCount: stepCount,
            elapsed: euclideanModulo(time, modulus: duration)
        )
    case .idleAction1, .idleAction2:
        let duration = 1.6
        return microActionFrame(
            event: event,
            pet: pet,
            progress: euclideanModulo(time, modulus: duration) / duration
        )
    }
}
```

- [ ] **Step 7: Verify motion rendering**

Run:

```bash
swift test
swift build
DESKPET_MOTION_PREVIEW=walk swift run DeskPetMac
```

Expected: tests/build pass; debug preview loops six real gait frames without falling back to base, and interactions interrupt it.

- [ ] **Step 8: Review motion scope**

Run:

```bash
git diff --check
git diff -- Sources/DeskPetCore/PetMotionDirector.swift Sources/DeskPetCore/PetArtworkManifest.swift Sources/DeskPetMac/RealisticPetBody.swift Sources/DeskPetMac/PetWindowView.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift
```

Expected: motion scheduling, resources, rendering, and tests only.

### Task 6: Replace WeatherAnimationProfile with a Rich WeatherSceneProfile

**Files:**
- Create: `Sources/DeskPetCore/PetWeatherReaction.swift`
- Create: `Sources/DeskPetCore/WeatherSceneProfile.swift`
- Modify: `Sources/DeskPetCore/WeatherAnimationProfile.swift` (retain temporarily until Task 10)
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Replace old profile tests with failing scene-profile tests**

Replace `WeatherAnimationProfileTests` with:

```swift
@Suite("Weather scene profiles")
struct WeatherSceneProfileTests {
    @Test("particle counts stay within the forty-particle budget")
    func particleBudget() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherSceneProfile(mood: mood)
            #expect(profile.background.count >= 0)
            #expect(profile.midground.count >= 0)
            #expect(profile.foreground.count >= 0)
            #expect(profile.totalParticleCount <= 40)
            #expect(profile.transitionDuration == 0.8)
            #expect(profile.maximumFramesPerSecond == 30)
        }
    }

    @Test("rain snow and storms use multiple depth bands")
    func precipitationHasDepth() {
        for mood in [PetWeatherMood.rainy, .snowy, .stormy] {
            let profile = WeatherSceneProfile(mood: mood)
            #expect(profile.background.count > 0)
            #expect(profile.midground.count > 0)
            #expect(profile.foreground.count > 0)
        }
    }

    @Test("ground and lightning capabilities stay mood-specific")
    func capabilitiesAreMoodSpecific() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherSceneProfile(mood: mood)
            #expect(profile.showsSplashes == (mood == .rainy || mood == .stormy))
            #expect(profile.showsSnowGroundLight == (mood == .snowy))
            #expect(profile.supportsLightning == (mood == .stormy))
        }
    }

    @Test("Reduce Motion produces static profiles")
    func reduceMotionIsStatic() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherSceneProfile(mood: mood)
            #expect(profile.renderingMode(reduceMotion: true) == .staticCue)
            #expect(profile.renderingMode(reduceMotion: false) == .animated)
        }
    }

    @Test("pet reactions remain exhaustive and character-specific")
    func reactionsRemainExhaustive() {
        for pet in PetKind.allCases {
            for mood in PetWeatherMood.allCases {
                #expect(WeatherSceneProfile.reaction(for: pet, mood: mood) != .none)
            }
        }
        #expect(WeatherSceneProfile.reaction(for: .cat, mood: .rainy) == .shelter)
        #expect(WeatherSceneProfile.reaction(for: .pauli, mood: .rainy) == .visorGlow)
        #expect(WeatherSceneProfile.reaction(for: .dog, mood: .rainy) == .shake)
    }
}
```

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter WeatherSceneProfileTests
```

Expected: compilation fails because `WeatherSceneProfile` does not exist.

- [ ] **Step 3: Create the scene-profile types and mappings**

Create `Sources/DeskPetCore/PetWeatherReaction.swift` by moving the existing enum out of `WeatherAnimationProfile.swift` without changing its cases:

```swift
public enum PetWeatherReaction: String, CaseIterable, Equatable, Sendable {
    case none
    case settle
    case headLift
    case observe
    case shelter
    case antennaGlow
    case visorGlow
    case shake
    case sniff
    case startle
}
```

Remove only that enum declaration from `WeatherAnimationProfile.swift`; retain the old struct until Task 10 so current app callers continue to compile.

Create `Sources/DeskPetCore/WeatherSceneProfile.swift`:

```swift
public enum WeatherRenderingMode: Equatable, Sendable {
    case animated
    case staticCue
}

public struct WeatherDepthProfile: Equatable, Sendable {
    public let count: Int
    public let speed: Double
    public let size: ClosedRange<Double>
    public let opacity: ClosedRange<Double>
    public let blur: ClosedRange<Double>

    public init(
        count: Int,
        speed: Double,
        size: ClosedRange<Double>,
        opacity: ClosedRange<Double>,
        blur: ClosedRange<Double>
    ) {
        self.count = count
        self.speed = speed
        self.size = size
        self.opacity = opacity
        self.blur = blur
    }
}

public struct WeatherSceneProfile: Equatable, Sendable {
    public let mood: PetWeatherMood
    public let background: WeatherDepthProfile
    public let midground: WeatherDepthProfile
    public let foreground: WeatherDepthProfile
    public let wind: Double
    public let showsSplashes: Bool
    public let showsSnowGroundLight: Bool
    public let supportsLightning: Bool
    public let lightningPeriod: Double?
    public let transitionDuration: Double
    public let maximumFramesPerSecond: Double

    public var totalParticleCount: Int {
        background.count + midground.count + foreground.count
    }

    public init(mood: PetWeatherMood) {
        self.mood = mood
        self.transitionDuration = 0.8
        self.maximumFramesPerSecond = 30

        switch mood {
        case .sunny:
            background = .init(count: 2, speed: 0.010, size: 1...2, opacity: 0.08...0.16, blur: 0...0.6)
            midground = .init(count: 3, speed: 0.016, size: 1...2.5, opacity: 0.10...0.20, blur: 0...0.8)
            foreground = .init(count: 1, speed: 0.022, size: 2...3, opacity: 0.08...0.14, blur: 0.5...1.4)
            wind = 0.04
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .cloudy:
            background = .init(count: 0, speed: 0, size: 0...0, opacity: 0...0, blur: 0...0)
            midground = background
            foreground = background
            wind = 0.08
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .foggy:
            background = .init(count: 0, speed: 0, size: 0...0, opacity: 0...0, blur: 0...0)
            midground = background
            foreground = background
            wind = 0.06
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .rainy:
            background = .init(count: 9, speed: 0.28, size: 7...11, opacity: 0.18...0.30, blur: 0...0.4)
            midground = .init(count: 12, speed: 0.40, size: 10...15, opacity: 0.26...0.42, blur: 0...0.8)
            foreground = .init(count: 11, speed: 0.56, size: 15...23, opacity: 0.34...0.54, blur: 0.8...1.8)
            wind = -0.16
            showsSplashes = true
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .snowy:
            background = .init(count: 8, speed: 0.055, size: 2...3, opacity: 0.34...0.54, blur: 0...0.5)
            midground = .init(count: 12, speed: 0.080, size: 3...5, opacity: 0.48...0.70, blur: 0...0.8)
            foreground = .init(count: 12, speed: 0.105, size: 5...8, opacity: 0.58...0.82, blur: 0.8...2.0)
            wind = 0.10
            showsSplashes = false
            showsSnowGroundLight = true
            supportsLightning = false
            lightningPeriod = nil
        case .stormy:
            background = .init(count: 7, speed: 0.34, size: 9...13, opacity: 0.20...0.32, blur: 0...0.5)
            midground = .init(count: 10, speed: 0.48, size: 12...18, opacity: 0.30...0.46, blur: 0...0.9)
            foreground = .init(count: 9, speed: 0.64, size: 17...25, opacity: 0.38...0.58, blur: 0.8...2.0)
            wind = -0.22
            showsSplashes = true
            showsSnowGroundLight = false
            supportsLightning = true
            lightningPeriod = 24
        case .cozy:
            background = .init(count: 2, speed: 0.006, size: 1...2, opacity: 0.08...0.14, blur: 0...0.8)
            midground = .init(count: 2, speed: 0.010, size: 1.5...2.5, opacity: 0.09...0.16, blur: 0.3...1.0)
            foreground = .init(count: 1, speed: 0.014, size: 2...3, opacity: 0.07...0.12, blur: 0.8...1.6)
            wind = 0.02
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        }
    }

    public func renderingMode(reduceMotion: Bool) -> WeatherRenderingMode {
        reduceMotion ? .staticCue : .animated
    }

    public static func reaction(
        for pet: PetKind,
        mood: PetWeatherMood
    ) -> PetWeatherReaction {
        switch (pet, mood) {
        case (.cat, .sunny), (.cat, .cloudy), (.cat, .snowy), (.cat, .cozy): .settle
        case (.cat, .foggy): .observe
        case (.cat, .rainy): .shelter
        case (.cat, .stormy): .startle
        case (.pauli, .sunny), (.pauli, .foggy), (.pauli, .stormy): .antennaGlow
        case (.pauli, .rainy), (.pauli, .snowy): .visorGlow
        case (.pauli, .cloudy), (.pauli, .cozy): .settle
        case (.dog, .sunny): .headLift
        case (.dog, .cloudy), (.dog, .cozy): .settle
        case (.dog, .foggy): .observe
        case (.dog, .rainy): .shake
        case (.dog, .snowy): .sniff
        case (.dog, .stormy): .startle
        }
    }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --filter WeatherSceneProfileTests
```

Expected: the new suite and current app compile because `PetWeatherReaction` is shared and the old profile struct remains temporarily available.

### Task 7: Add Deterministic Weather Particle Layouts

**Files:**
- Create: `Sources/DeskPetCore/WeatherParticleLayout.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Write failing determinism tests**

Append:

```swift
@Suite("Weather particle layouts")
struct WeatherParticleLayoutTests {
    @Test("fixed seed produces repeatable particles")
    func fixedSeedIsRepeatable() {
        let profile = WeatherSceneProfile(mood: .rainy)
        let first = WeatherParticleLayout.particles(
            count: profile.midground.count,
            seed: 41,
            depth: .midground
        )
        let second = WeatherParticleLayout.particles(
            count: profile.midground.count,
            seed: 41,
            depth: .midground
        )
        #expect(first == second)
    }

    @Test("different depth bands receive different layouts")
    func depthBandsDiffer() {
        let back = WeatherParticleLayout.particles(count: 8, seed: 17, depth: .background)
        let front = WeatherParticleLayout.particles(count: 8, seed: 17, depth: .foreground)
        #expect(back != front)
    }

    @Test("animated positions remain normalized")
    func animatedPositionsStayNormalized() {
        let seeds = WeatherParticleLayout.particles(count: 40, seed: 73, depth: .foreground)
        for time in [-500.0, 0, 1, 9999] {
            for particle in seeds {
                let state = particle.state(at: time, speed: 0.64, wind: -0.22, moving: true)
                #expect((0...1).contains(state.x))
                #expect((0...1).contains(state.y))
            }
        }
    }

    @Test("static mode ignores time")
    func staticModeIgnoresTime() {
        let particle = WeatherParticleLayout.particles(count: 1, seed: 9, depth: .midground)[0]
        let first = particle.state(at: 0, speed: 0.5, wind: 0.2, moving: false)
        let second = particle.state(at: 10_000, speed: 0.5, wind: 0.2, moving: false)
        #expect(first == second)
    }
}
```

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter WeatherParticleLayoutTests
```

Expected: compilation fails because the layout types do not exist.

- [ ] **Step 3: Implement the pure particle layout**

Create `Sources/DeskPetCore/WeatherParticleLayout.swift`:

```swift
public enum WeatherDepth: Int, CaseIterable, Equatable, Sendable {
    case background
    case midground
    case foreground
}

public struct WeatherParticleState: Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct WeatherParticleSeed: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let phase: Double
    public let sizeUnit: Double
    public let opacityUnit: Double
    public let blurUnit: Double

    public func state(
        at time: Double,
        speed: Double,
        wind: Double,
        moving: Bool
    ) -> WeatherParticleState {
        guard moving else { return WeatherParticleState(x: x, y: y) }
        let animatedY = euclideanModulo(y + time * speed + phase, modulus: 1)
        let animatedX = euclideanModulo(x + animatedY * wind + sin(time * 0.35 + phase * .pi * 2) * 0.015, modulus: 1)
        return WeatherParticleState(x: animatedX, y: animatedY)
    }

    private func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

public enum WeatherParticleLayout {
    public static func particles(
        count: Int,
        seed: UInt64,
        depth: WeatherDepth
    ) -> [WeatherParticleSeed] {
        guard count > 0 else { return [] }
        var generator = SplitMix64(state: seed &+ UInt64(depth.rawValue + 1) * 0x9E3779B97F4A7C15)
        return (0..<count).map { _ in
            WeatherParticleSeed(
                x: generator.nextUnit(),
                y: generator.nextUnit(),
                phase: generator.nextUnit(),
                sizeUnit: generator.nextUnit(),
                opacityUnit: generator.nextUnit(),
                blurUnit: generator.nextUnit()
            )
        }
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
```

- [ ] **Step 4: Run focused and full tests**

Run:

```bash
swift test --filter WeatherParticleLayoutTests
swift test
git diff --check
```

Expected: deterministic layout tests and all existing tests pass.

### Task 8: Build Canvas Precipitation and Ground Feedback

**Files:**
- Create: `Sources/DeskPetMac/WeatherParticleField.swift`
- Modify: `Sources/DeskPetMac/WeatherAtmosphere.swift`

- [ ] **Step 1: Establish a failing compile contract**

Temporarily replace the old `rainParticles` and `snowParticles` calls with:

```swift
WeatherParticleField(
    mood: mood,
    profile: profile,
    depth: layer.depth,
    time: time,
    moving: moving
)
```

Run:

```bash
swift build
```

Expected: fails because `WeatherParticleField` and `WeatherLayer.depth` do not exist.

- [ ] **Step 2: Add layer-to-depth mapping**

Replace the two-value weather layer with three values:

```swift
enum WeatherLayer: Equatable {
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
```

- [ ] **Step 3: Create the Canvas particle field**

Create `Sources/DeskPetMac/WeatherParticleField.swift` with this structure:

```swift
import DeskPetCore
import SwiftUI

struct WeatherParticleField: View {
    let mood: PetWeatherMood
    let profile: WeatherSceneProfile
    let depth: WeatherDepth
    let time: TimeInterval
    let moving: Bool

    private var depthProfile: WeatherDepthProfile {
        switch depth {
        case .background: profile.background
        case .midground: profile.midground
        case .foreground: profile.foreground
        }
    }

    private var seeds: [WeatherParticleSeed] {
        WeatherParticleLayout.particles(
            count: depthProfile.count,
            seed: seed,
            depth: depth
        )
    }

    var body: some View {
        Canvas { context, size in
            for particle in seeds {
                var particleContext = context
                let state = particle.state(
                    at: time,
                    speed: depthProfile.speed,
                    wind: profile.wind,
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

            if depth == .foreground {
                drawGroundFeedback(in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var seed: UInt64 {
        UInt64(mood.seedBase + depth.rawValue * 1_009)
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
            with: .color(Color(red: 0.55, green: 0.76, blue: 0.95).opacity(opacity)),
            lineWidth: depth == .foreground ? 1.5 : 1.0
        )
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
            with: .color(Color(red: 0.80, green: 0.90, blue: 1.0).opacity(opacity))
        )
    }

    private func drawMote(
        _ particle: WeatherParticleSeed,
        at point: CGPoint,
        in context: inout GraphicsContext
    ) {
        let diameter = CGFloat(interpolate(depthProfile.size, unit: particle.sizeUnit))
        let opacity = interpolate(depthProfile.opacity, unit: particle.opacityUnit)
        let color = mood == .sunny ? Color.yellow : Color.orange
        context.fill(
            Path(ellipseIn: CGRect(x: point.x, y: point.y, width: diameter, height: diameter)),
            with: .color(color.opacity(opacity))
        )
    }

    private func drawGroundFeedback(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        if profile.showsSplashes {
            drawRainSplashes(in: &context, size: size)
        }
        if profile.showsSnowGroundLight {
            let rect = CGRect(x: size.width * 0.22, y: size.height * 0.82, width: size.width * 0.56, height: 18)
            context.addFilter(.blur(radius: 9))
            context.fill(Path(ellipseIn: rect), with: .color(Color.blue.opacity(0.12)))
        }
    }

    private func drawRainSplashes(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let phase = CGFloat(
            moving ? time.truncatingRemainder(dividingBy: 2.4) / 2.4 : 0.35
        )
        let rect = CGRect(
            x: size.width * 0.28 - phase * 6,
            y: size.height * 0.84,
            width: size.width * (0.30 + phase * 0.18),
            height: 9
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Color.blue.opacity(0.22 * Double(1 - phase))),
            lineWidth: 1
        )
    }

    private func interpolate(_ range: ClosedRange<Double>, unit: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}

private extension PetWeatherMood {
    var seedBase: Int {
        switch self {
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
```

The per-particle `particleContext` copy prevents blur filters from accumulating across particles.

- [ ] **Step 4: Compose three particle bands**

Define all three non-interactive wrappers in `WeatherAtmosphere.swift`:

```swift
struct WeatherBackdrop: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .background, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherMidground: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .midground, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherForeground: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .foreground, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
```

In `WeatherAtmosphere`, render background and foreground wrappers as follows; the pet button will sit between midground and foreground in Task 10:

```swift
WeatherParticleField(mood: mood, profile: profile, depth: .background, time: time, moving: moving)
WeatherParticleField(mood: mood, profile: profile, depth: .midground, time: time, moving: moving)
WeatherParticleField(mood: mood, profile: profile, depth: .foreground, time: time, moving: moving)
```

- [ ] **Step 5: Build and inspect rainy/snowy previews**

Run:

```bash
swift build
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=snowy swift run DeskPetMac
```

Expected: rain and snow show three depth bands; ground feedback is visible; pet interaction remains available.

### Task 9: Build Volumetric Cloud, Fog, Sun, Cozy, and Storm Atmosphere

**Files:**
- Modify: `Sources/DeskPetMac/WeatherAtmosphere.swift`

- [ ] **Step 1: Remove symbol-based weather source contracts**

Run:

```bash
rg -n 'cloud\.fill|bolt\.fill|Image\(systemName:' Sources/DeskPetMac/WeatherAtmosphere.swift
```

Expected before editing: matches for the old cloud and lightning symbols.

- [ ] **Step 2: Replace cloudy icon rendering with irregular cloud masses**

Add a Canvas helper that draws five overlapping lobes per cloud mass:

```swift
private func drawCloudMass(
    in context: inout GraphicsContext,
    size: CGSize,
    center: CGPoint,
    scale: CGFloat,
    opacity: Double
) {
    let lobes: [(CGFloat, CGFloat, CGFloat)] = [
        (-32, 4, 24), (-13, -8, 31), (12, -12, 36), (37, 2, 25), (3, 10, 44),
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
            with: .color(Color(red: 0.46, green: 0.53, blue: 0.62).opacity(opacity))
        )
    }
}
```

Draw two masses with different scales, blur, opacity, and drift speeds. Keep them behind the face and do not restore `cloud.fill`.

- [ ] **Step 3: Replace capsule fog with multi-lobe drifting volumes**

Create three fog bands from overlapping ellipses. Derive drift from stable periods of 17, 23, and 31 seconds. Use a lower foreground band that can cross feet but never rises above 72% of the weather canvas height. Static Reduce Motion uses `time = 0`.

Use this band helper:

```swift
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
            Path(ellipseIn: CGRect(x: x, y: y + CGFloat(index % 2) * 4, width: width, height: height)),
            with: .color(Color(red: 0.64, green: 0.75, blue: 0.84).opacity(opacity))
        )
    }
}
```

- [ ] **Step 4: Add sunny rays and distinguish cozy light**

Sunny background:

```swift
let rayGradient = Gradient(colors: [Color.yellow.opacity(0.16), .clear])
context.fill(
    Path(CGRect(x: -20, y: -20, width: size.width * 0.72, height: size.height * 1.1)),
    with: .linearGradient(
        rayGradient,
        startPoint: CGPoint(x: 0, y: 0),
        endPoint: CGPoint(x: size.width * 0.64, y: size.height)
    )
)
```

Cozy uses a centered warm radial gradient with a smaller radius and slower dust motes. Do not use the same gradient geometry for sunny and cozy.

- [ ] **Step 5: Replace lightning icon with a two-stage environmental flash**

Use a 24-second base period and compute:

```swift
private func lightningOpacity(time: TimeInterval, moving: Bool) -> Double {
    guard moving else { return 0 }
    let phase = euclideanModulo(time, modulus: 24)
    switch phase {
    case 0..<0.07:
        return 0.19 * (1 - phase / 0.07)
    case 0.12..<0.19:
        return 0.10 * (1 - (phase - 0.12) / 0.07)
    default:
        return 0
    }
}
```

Draw the flash as a broad white-to-blue gradient and add one thin fixed procedural branch at the far-right edge:

```swift
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
```

Keep the branch outside the central face region and do not restore any SF Symbol lightning artwork.

- [ ] **Step 6: Verify atmosphere source and runtime**

Run:

```bash
rg -n 'cloud\.fill|bolt\.fill' Sources/DeskPetMac
swift build
```

Expected: no symbol matches and build passes.

Launch:

```bash
DESKPET_WEATHER_PREVIEW=cloudy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=foggy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=sunny swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=stormy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=cozy swift run DeskPetMac
```

Expected: each mood is recognizable without text and sunny/cozy remain distinct.

### Task 10: Split Artwork Lighting and Migrate Weather Callers

**Files:**
- Create: `Sources/DeskPetMac/PetWeatherLighting.swift`
- Modify: `Sources/DeskPetMac/WeatherAtmosphere.swift`
- Modify: `Sources/DeskPetMac/RealisticPetBody.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`
- Remove: `Sources/DeskPetCore/WeatherAnimationProfile.swift`

- [ ] **Step 1: Move lighting views into their focused file**

Move the complete existing implementations of `PetWeatherArtworkLight` and `PetWeatherAccent` from `WeatherAtmosphere.swift` into `PetWeatherLighting.swift`. Rename `PetWeatherArtworkLight` to `PetWeatherLighting`, keep the existing switch bodies and Pauli accent opacity helpers, and update the outer API:

```swift
struct PetWeatherLighting: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    // Keep the existing mood switch as this body, then apply the larger frame.
    var body: some View {
        artworkLightingBody
            .frame(width: 190, height: 198)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
```

Implement `artworkLightingBody` as a private `@ViewBuilder` property containing the complete current `switch mood` body from `PetWeatherArtworkLight`; do not leave both the old and new copies in the target.

```swift
struct PetWeatherLighting: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            artworkLight
            if kind == .pauli {
                pauliAccent
            }
        }
        .frame(width: 190, height: 198)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
```

Preserve these material rules:

- Sunny/cozy use `.screen` warm light.
- Cloudy uses a low-opacity moving `.multiply` shadow.
- Rainy/stormy add cool lower reflection plus a narrow lower-body wet sheen.
- Snowy adds cool top light and ground bounce.
- Foggy reduces lower-body contrast without whitening the face.

Update the realistic renderer call exactly to:

```swift
PetWeatherLighting(
    kind: kind,
    mood: mood,
    time: time,
    reduceMotion: reduceMotion
)
.mask(artworkImage(artwork))
```

Keep `PetWeatherAccent` as a separate sibling so its existing `isVisible` and `allowsAnimation` gates remain intact.

Update the accent clipping frame from `166 x 170` to `190 x 198`; recheck the antenna and visor offsets against Pauli’s regenerated scale so both accents remain attached to the artwork rather than the window.

- [ ] **Step 2: Migrate every reaction and transition caller**

Replace:

```swift
WeatherAnimationProfile.reaction(for: kind, mood: mood)
```

with:

```swift
WeatherSceneProfile.reaction(for: kind, mood: mood)
```

Replace:

```swift
WeatherAnimationProfile(mood: displayedMood).transitionDuration
```

with:

```swift
WeatherSceneProfile(mood: displayedMood).transitionDuration
```

Update tests to reference `WeatherSceneProfile` only.

- [ ] **Step 3: Remove the obsolete profile**

After this command returns no source matches:

```bash
rg -n "WeatherAnimationProfile" Sources Tests
```

remove `Sources/DeskPetCore/WeatherAnimationProfile.swift`.

- [ ] **Step 4: Build and run tests**

Run:

```bash
swift test
swift build
git diff --check
```

Expected: all tests and build pass; no old profile references remain.

### Task 11: Expand the Window and Compose the Three Weather Depths

**Files:**
- Modify: `Sources/DeskPetMac/DeskPetMacApp.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`
- Modify: `Sources/DeskPetMac/RealisticPetBody.swift`

- [ ] **Step 1: Increase fixed app content size**

Change `DeskPetMacApp`:

```swift
PetWindowView(model: model)
    .frame(width: 260, height: 290)
```

- [ ] **Step 2: Expand pet and weather composition bounds**

Use these constants in `PetWindowView`:

```swift
private enum SceneMetrics {
    static let windowSize = CGSize(width: 260, height: 290)
    static let weatherSize = CGSize(width: 220, height: 218)
    static let artworkSize = CGSize(width: 190, height: 198)
}
```

Update the scene `ZStack` to `220 x 218`. Keep the artwork centered at `190 x 198` and the control strip at the bottom with at least 10 points of padding.

In `WeatherAtmosphereLayer`, change the clipped canvas frame and timeline cadence to:

```swift
TimelineView(
    .animation(minimumInterval: 1.0 / profile.maximumFramesPerSecond)
) { timeline in
    atmosphere(
        time: timeline.date.timeIntervalSinceReferenceDate,
        moving: true
    )
}
```

```swift
.frame(width: 220, height: 218)
.clipped()
```

In `RealisticPetBody`, change the artwork image and lighting mask frames to:

```swift
.frame(width: 190, height: 198)
```

and change the outer pet scene frame to:

```swift
.frame(width: 220, height: 218)
```

Apply the same outer `220 x 218` bounds to `VectorPetBody` while keeping its internal proportions centered rather than stretching the vector geometry.

- [ ] **Step 3: Compose weather depth around the pet**

Render in this exact order:

```swift
WeatherBackdrop(mood: displayedMood, reduceMotion: reduceMotion)
WeatherMidground(mood: displayedMood, reduceMotion: reduceMotion)

Button {
    model.pat()
} label: {
    petBody
}
.buttonStyle(.plain)
.accessibilityLabel("Pat \(model.petKind.displayName)")

WeatherForeground(mood: displayedMood, reduceMotion: reduceMotion)
```

Give all three wrappers synchronized identity and opacity transitions:

```swift
.id("weather-background-\(displayedMood.rawValue)")
.transition(.opacity)
```

Use `weather-midground-` and `weather-foreground-` prefixes for the other two wrappers.

All three weather wrappers must include:

```swift
.allowsHitTesting(false)
.accessibilityHidden(true)
```

- [ ] **Step 4: Update pointer normalization and overlays**

Replace the old hard-coded center:

```swift
private func normalizedPointerOffset(_ location: CGPoint) -> CGSize {
    CGSize(
        width: min(1, max(-1, (location.x - 130) / 130)),
        height: min(1, max(-1, (location.y - 145) / 145))
    )
}
```

Move heart particles to remain centered on the larger pet scene:

```swift
.offset(y: 92)
```

Keep bubble overlays at the top and control strip at the bottom; neither should be placed inside the clipped weather scene.

- [ ] **Step 5: Add 0.8-second weather crossfades**

Use one profile-derived animation on the complete weather scene:

```swift
.animation(
    .easeInOut(duration: WeatherSceneProfile(mood: displayedMood).transitionDuration),
    value: displayedMood
)
```

Avoid separate animations that can leave old and new weather layers out of sync.

- [ ] **Step 6: Build and inspect bounds**

Run:

```bash
swift build
rg -n "220, height: 250|width: 172, height: 178|location.x - 110|location.y - 125" Sources/DeskPetMac
```

Expected: build passes; no obsolete window, scene, or pointer constants remain where they control the main composition.

### Task 12: Document the New Motion and Weather Preview Workflow

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update feature wording**

Replace the current idle-life and integrated-weather bullets with:

```markdown
- **Character motion / 角色动作** — Cat, Pauli, and Dog occasionally take a few real animated steps and perform distinct idle actions, while pats, dance, sleep, hover, and personality poses keep priority.
- **Depth-aware weather / 景深天气** — procedural clouds, fog, rain, snow, sunlight, splashes, wet reflections, and natural storm illumination animate around and across the pet without a weather label.
```

Add one sentence under Run or Verify:

```markdown
The transparent desktop window uses a compact `260 x 290` canvas so weather can render behind and in front of the pet.
```

- [ ] **Step 2: Document debug motion preview values**

Add:

````markdown
Preview a motion event in a debug build:

```bash
DESKPET_MOTION_PREVIEW=walk swift run DeskPetMac
```

Supported values: `walk`, `idleAction1`, and `idleAction2`.
````

Keep the existing weather-preview instructions.

- [ ] **Step 3: Check documentation consistency**

Run:

```bash
rg -n "220 x 250|220×250|weather label|weather accessories|DESKPET_MOTION_PREVIEW|260 x 290|260×290|Depth-aware weather" README.md Sources
git diff --check
```

Expected: no stale compact-window or flat-weather claims remain.

### Task 13: Full Automated, Asset, Performance, and Real-Window Verification

**Files:**
- No source changes expected unless verification exposes a defect.

- [ ] **Step 1: Run formatter diagnostics without broad reformatting**

Run:

```bash
swift format lint --strict Sources/DeskPetCore/PetMotionDirector.swift Sources/DeskPetCore/PetArtworkManifest.swift Sources/DeskPetCore/WeatherSceneProfile.swift Sources/DeskPetCore/WeatherParticleLayout.swift Sources/DeskPetMac/RealisticPetBody.swift Sources/DeskPetMac/WeatherParticleField.swift Sources/DeskPetMac/WeatherAtmosphere.swift Sources/DeskPetMac/PetWeatherLighting.swift Sources/DeskPetMac/PetWindowView.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift
git diff --check
```

Expected: report the repository’s existing indentation-style mismatch without bulk-formatting unrelated code. Fix only new diagnostics that can be corrected without reformatting existing files.

- [ ] **Step 2: Run fresh automated verification**

Run:

```bash
swift test
swift build -c release
scripts/package-app.sh
find .build/release/DeskPetMac.app/Contents/Resources/DeskPetMac_DeskPetMac.bundle/Pets -type f -name '*.png' | wc -l
codesign --verify --deep --strict --verbose=2 .build/release/DeskPetMac.app
```

Expected:

- All tests pass.
- Release build and packaging exit 0.
- Packaged PNG count is exactly `51`.
- Codesign reports `valid on disk` and satisfies its designated requirement.

- [ ] **Step 3: Inspect all motion assets in the app**

For each pet, run:

```bash
DESKPET_MOTION_PREVIEW=walk swift run DeskPetMac
DESKPET_MOTION_PREVIEW=idleAction1 swift run DeskPetMac
DESKPET_MOTION_PREVIEW=idleAction2 swift run DeskPetMac
```

Switch Cat, Pauli, and Dog with `Cmd+1`, `Cmd+2`, and `Cmd+3`. Verify:

- All six gait frames loop in the intended order.
- Feet move rather than the complete image merely bobbing.
- Weight, tilt, and shadow match foot contact.
- No duplicated limbs, identity drift, scale jump, green fringe, or edge clipping.
- Pat, dance, hover, personality, and sleep interrupt motion cleanly.

- [ ] **Step 4: Observe natural scheduling**

Launch without motion override and observe each pet for at least three minutes. Verify:

- Short actions begin after 12–30 seconds.
- Walks contain 2–4 steps.
- Walk and micro-action choices vary across cycles.
- Interrupted actions restart from neutral instead of resuming midway.
- CPU usage remains appropriate for an always-on desktop utility.

- [ ] **Step 5: Inspect all 21 pet/weather combinations**

For each mood, launch:

```bash
DESKPET_WEATHER_PREVIEW=sunny swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=cloudy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=foggy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=snowy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=stormy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=cozy swift run DeskPetMac
```

Switch through all three pets and verify:

- Weather is recognizable without text.
- Cloud and storm use no SF Symbol weather icons.
- Rain/snow show depth; rain splashes and snow ground light are visible.
- Fog has irregular moving volumes, not fixed capsules.
- Sunny and cozy remain distinct.
- Faces, controls, bubbles, reminders, and hearts remain readable.
- Weather does not block click, hover, or drag.
- The `260 x 290` window contains every effect without obvious clipping.

- [ ] **Step 6: Recheck on light and dark backgrounds**

Place the packaged app above a light local image and a dark local image without changing the system wallpaper. Repeat cloudy, foggy, rainy, snowy, and stormy. Verify particle edges, fog, cloud masses, splashes, and lighting remain readable on both backgrounds.

- [ ] **Step 7: Verify Reduce Motion**

After obtaining action-time permission to change the macOS accessibility setting, temporarily enable Reduce Motion and repeat rainy, snowy, foggy, stormy, walk, and both idle-action previews. Restore the original setting immediately afterward.

Expected:

- No gait loop, micro-action loop, precipitation, fog drift, cloud drift, moving light, ripple, or lightning animation continues.
- Static low-opacity weather and identity cues remain visible.
- Direct interaction feedback such as a static pat pose remains available.

- [ ] **Step 8: Recheck motion and base-artwork fallbacks**

In separate temporary packaged-app copies:

1. Move one Dog `walk` file out of the copied resource bundle, sign the copy, launch it with `DESKPET_MOTION_PREVIEW=walk`, and verify realistic Dog idle artwork remains stable without partial gait flicker.
2. Restore the walk file, move Dog `base.png` out, sign the copy, and verify vector Dog plus the enhanced weather scene remains usable.

Restore every moved file afterward. Do not modify source assets or the final packaged app.

- [ ] **Step 9: Final scope review and restart**

Run:

```bash
git status --short
git diff --stat
git diff -- Sources/DeskPetCore Sources/DeskPetMac Tests README.md
open .build/release/DeskPetMac.app
```

Confirm the diff contains only the approved motion assets/system, realistic weather renderer, tests, documentation, and necessary window/layout changes. Do not commit or push unless the user explicitly asks.
