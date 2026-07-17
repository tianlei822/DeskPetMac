# Realistic Pet Redesign and Dog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default Cat and Pauli presentation with visibly lively realistic 3D artwork, add an enthusiastic Dog throughout the product, and preserve the current vector characters as safe fallbacks.

**Architecture:** Pure pet identity, personality content, and artwork-manifest data stay in `DeskPetCore`. `DeskPetMac` packages PNG resources and renders them through a focused `RealisticPetBody`, while `PetWindowView` retains window-level composition and falls back to vector drawing when base artwork is unavailable. Existing `PetViewModel` state remains the single source of truth for interaction, sleep, dance, weather, and personality poses.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager resources, Swift Testing, built-in image generation, local chroma-key removal

**Repository rule:** Do not create commits or push unless the user explicitly asks. Use verification checkpoints as save points in this plan.

---

## File map

- Modify `Sources/DeskPetCore/Models.swift`: add the stable `.dog` identity and display name.
- Modify `Sources/DeskPetCore/PersonalityMoment.swift`: add exactly 12 Dog moments with distinct enthusiastic voice and make `PersonalityPose` usable as a manifest key.
- Create `Sources/DeskPetCore/PetArtworkManifest.swift`: stable pet/state resource names and fallback semantics, independent of AppKit.
- Modify `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`: Dog identity, catalog, selector, and artwork-manifest tests.
- Modify `Package.swift`: package `Sources/DeskPetMac/Resources` in the executable target.
- Create `Sources/DeskPetMac/Resources/Pets/...`: generated Retina PNG artwork for Cat, Pauli, and Dog.
- Create `Sources/DeskPetMac/RealisticPetBody.swift`: resource loading, state resolution, layered transforms, pointer response, and Reduce Motion behavior.
- Modify `Sources/DeskPetMac/PetWindowView.swift`: route to realistic rendering, add a Dog picker choice, and keep vector fallback rendering.
- Modify `Sources/DeskPetMac/DeskPetMacApp.swift`: add the `⌘3` Dog command.
- Modify `README.md`: document Dog and realistic always-on character motion.

### Task 1: Add Dog as a stable product identity

**Files:**
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`
- Modify: `Sources/DeskPetCore/Models.swift`

- [ ] **Step 1: Write the failing PetKind test**

Replace the existing `PetKindTests.offersExplicitPetKinds` expectations with:

```swift
@Suite("Pet kinds")
struct PetKindTests {
    @Test("offers stable selectable pet kinds")
    func offersStablePetKinds() {
        #expect(PetKind.allCases == [.cat, .pauli, .dog])
        #expect(PetKind.cat.rawValue == "cat")
        #expect(PetKind.pauli.rawValue == "pauli")
        #expect(PetKind.dog.rawValue == "dog")
        #expect(PetKind.cat.displayName == "Cat")
        #expect(PetKind.pauli.displayName == "Pauli")
        #expect(PetKind.dog.displayName == "Dog")
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PetKindTests
```

Expected: compilation fails because `PetKind.dog` does not exist.

- [ ] **Step 3: Add the minimal Dog identity**

Update `PetKind` without changing existing raw values:

```swift
public enum PetKind: String, CaseIterable, Equatable, Sendable {
    case cat
    case pauli
    case dog

    public var displayName: String {
        switch self {
        case .cat: "Cat"
        case .pauli: "Pauli"
        case .dog: "Dog"
        }
    }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```bash
swift test --filter PetKindTests
```

Expected: the Pet kinds suite passes.

### Task 2: Give Dog a distinct personality catalog

**Files:**
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`
- Modify: `Sources/DeskPetCore/PersonalityMoment.swift`

- [ ] **Step 1: Add a failing Dog selector test**

Add this test inside `PersonalityMomentTests`:

```swift
@Test("dog moments are enthusiastic and stay dog-specific")
func dogMomentsStayDogSpecific() {
    let dogMoments = PersonalityMomentCatalog.all.filter { $0.petKind == .dog }

    #expect(dogMoments.count == 12)
    #expect(Set(dogMoments.map(\.id)).count == 12)
    for category in PersonalityMomentCategory.allCases {
        #expect(dogMoments.filter { $0.category == category }.count == 3)
    }

    let context = PersonalityMomentContext(
        petKind: .dog,
        mood: .sunny,
        workProgress: 1,
        requestedCategory: .interaction,
        isPresentationBlocked: false
    )
    let selected = PersonalityMomentSelector.select(
        from: PersonalityMomentCatalog.all,
        context: context,
        excluding: [],
        roll: 0
    )

    #expect(selected?.petKind == .dog)
    #expect(selected?.category == .interaction)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PersonalityMomentTests
```

Expected: `catalogShape` and the new Dog test fail because Dog has no catalog entries.

- [ ] **Step 3: Append the exact 12 Dog moments**

Append these entries to `PersonalityMomentCatalog.all`:

```swift
.init(
    id: "dog.general.adventure",
    petKind: .dog,
    category: .general,
    pose: .peek,
    line: "You moved! Adventure?",
    weight: 3
),
.init(
    id: "dog.general.desk-patrol",
    petKind: .dog,
    category: .general,
    pose: .proud,
    line: "Desk patrol ready. Tail systems online!",
    weight: 3
),
.init(
    id: "dog.general.best-seat",
    petKind: .dog,
    category: .general,
    pose: .perk,
    line: "Best seat, best human, excellent day.",
    weight: 3
),
.init(
    id: "dog.weather.sunny-walk",
    petKind: .dog,
    category: .weather,
    pose: .perk,
    line: "Sunshine detected. Walk possibility: huge!",
    moods: [.sunny],
    weight: 2
),
.init(
    id: "dog.weather.rain-team",
    petKind: .dog,
    category: .weather,
    pose: .proud,
    line: "Rain outside. Cozy team inside!",
    moods: [.rainy, .stormy],
    weight: 2
),
.init(
    id: "dog.weather.snuggle-forecast",
    petKind: .dog,
    category: .weather,
    pose: .stretch,
    line: "Forecast says one hundred percent snuggles.",
    moods: [.cloudy, .foggy, .snowy, .cozy],
    weight: 2
),
.init(
    id: "dog.focus.guard",
    petKind: .dog,
    category: .focus,
    pose: .proud,
    line: "You focus. I guard the whole desk!",
    minimumWorkProgress: 0.25,
    weight: 2
),
.init(
    id: "dog.focus.still-here",
    petKind: .dog,
    category: .focus,
    pose: .peek,
    line: "Still working? I am still cheering!",
    minimumWorkProgress: 0.55,
    weight: 2
),
.init(
    id: "dog.focus.finish-line",
    petKind: .dog,
    category: .focus,
    pose: .perk,
    line: "Finish line close. Tail speed increasing!",
    minimumWorkProgress: 0.80,
    weight: 2
),
.init(
    id: "dog.interaction.best-pat",
    petKind: .dog,
    category: .interaction,
    pose: .perk,
    line: "Best pat yet! Again?"
),
.init(
    id: "dog.interaction.favorite",
    petKind: .dog,
    category: .interaction,
    pose: .proud,
    line: "Confirmed: you are my favorite."
),
.init(
    id: "dog.interaction.team",
    petKind: .dog,
    category: .interaction,
    pose: .stretch,
    line: "Teamwork! You pat, I wag."
)
```

- [ ] **Step 4: Run all Core tests and verify GREEN**

Run:

```bash
swift test
```

Expected: all suites pass, and the catalog test validates 12 moments for all three pets.

### Task 3: Define a testable artwork manifest and package resources

**Files:**
- Create: `Sources/DeskPetCore/PetArtworkManifest.swift`
- Modify: `Sources/DeskPetCore/PersonalityMoment.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Write failing artwork-manifest tests**

Append:

```swift
@Suite("Pet artwork manifest")
struct PetArtworkManifestTests {
    @Test("each pet has stable artwork filenames for every presentation state")
    func everyPetHasStableArtworkNames() {
        for pet in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: pet)

            #expect(manifest.base.hasSuffix("/base"))
            #expect(manifest.blink.hasSuffix("/blink"))
            #expect(manifest.hover.hasSuffix("/hover"))
            #expect(manifest.pat.hasSuffix("/pat"))
            #expect(manifest.sleep.hasSuffix("/sleep"))
            for pose in PersonalityPose.allCases {
                #expect(manifest.personality[pose]?.hasSuffix("/\(pose.rawValue)") == true)
            }
        }
    }

    @Test("missing state artwork falls back to the base resource name")
    func missingStateFallsBackToBase() {
        let manifest = PetArtworkManifest(petKind: .dog)

        #expect(manifest.resourceName(for: .idle) == "Pets/Dog/base")
        #expect(manifest.resourceName(for: .personality(.perk)) == "Pets/Dog/perk")
        #expect(manifest.fallbackResourceName == "Pets/Dog/base")
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PetArtworkManifestTests
```

Expected: compilation fails because the manifest types do not exist.

- [ ] **Step 3: Implement the pure manifest API**

Add `Hashable` to the existing pose enum without changing its cases or raw values:

```swift
public enum PersonalityPose: String, CaseIterable, Equatable, Hashable, Sendable {
    case peek
    case perk
    case stretch
    case proud
}
```

Create `PetArtworkManifest.swift`:

```swift
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
        self.petKind = petKind
        let directory = "Pets/\(petKind.resourceDirectoryName)"
        base = "\(directory)/base"
        blink = "\(directory)/blink"
        hover = "\(directory)/hover"
        pat = "\(directory)/pat"
        sleep = "\(directory)/sleep"
        personality = Dictionary(uniqueKeysWithValues: PersonalityPose.allCases.map {
            ($0, "\(directory)/\($0.rawValue)")
        })
    }

    public var fallbackResourceName: String { base }

    public func resourceName(for state: PetPresentationState) -> String {
        switch state {
        case .idle: base
        case .blink: blink
        case .hover: hover
        case .pat: pat
        case .sleep: sleep
        case .personality(let pose): personality[pose] ?? base
        }
    }
}

private extension PetKind {
    var resourceDirectoryName: String {
        switch self {
        case .cat: "Cat"
        case .pauli: "Pauli"
        case .dog: "Dog"
        }
    }
}
```

- [ ] **Step 4: Package the resource directory**

Update the executable target in `Package.swift`:

```swift
.executableTarget(
    name: "DeskPetMac",
    dependencies: ["DeskPetCore"],
    path: "Sources/DeskPetMac",
    resources: [.copy("Resources/Pets")]
),
```

Do not create placeholder PNGs. The generated resources land in Task 4.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
swift test --filter PetArtworkManifestTests
swift test
```

Expected: manifest tests and all existing suites pass.

### Task 4: Generate and validate realistic 3D artwork

**Files:**
- Create: `Sources/DeskPetMac/Resources/Pets/Cat/*.png`
- Create: `Sources/DeskPetMac/Resources/Pets/Pauli/*.png`
- Create: `Sources/DeskPetMac/Resources/Pets/Dog/*.png`

- [ ] **Step 1: Create the resource directories**

Run:

```bash
mkdir -p Sources/DeskPetMac/Resources/Pets/Cat
mkdir -p Sources/DeskPetMac/Resources/Pets/Pauli
mkdir -p Sources/DeskPetMac/Resources/Pets/Dog
```

- [ ] **Step 2: Generate one canonical base image per pet**

Use the built-in `imagegen` tool once per pet. Use the exact shared constraints below and change only the subject paragraph.

```text
Use case: stylized-concept
Asset type: Retina macOS desktop pet sprite
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background; no floor, gradient, texture, reflection, or cast shadow
Style/medium: premium photoreal 3D character render with physically based materials
Composition: one full-body subject, centered, front three-quarter view, generous padding, entire silhouette visible, square canvas
Lighting: soft warm studio key light with subtle cool fill; lighting belongs only on the subject
Constraints: fixed identity across every later state; no text, watermark, props, accessories, floor plane, contact shadow, or background variation; never use #00ff00 in the subject
```

Cat subject:

```text
An anatomically believable orange tabby cat with short dense fur, amber eyes, visible whiskers, relaxed asymmetric posture, slightly curved tail, alert natural ears, friendly but mildly mischievous expression; realistic fur strands and moist nose, not chibi and not cartoon.
```

Pauli subject:

```text
A compact friendly robot named Pauli with ivory brushed-polymer shell, teal panels, small metal joints, dark curved glass face screen, cyan expressive eyes, one antenna, balanced upright posture; realistic PBR plastic, metal, and glass, not a toy caricature.
```

Dog subject:

```text
An anatomically believable medium golden-brown dog with soft wavy fur, floppy ears, warm brown eyes, open friendly mouth, eager forward-leaning posture, and raised tail suggesting a wag; enthusiastic and loyal, not chibi and not cartoon.
```

- [ ] **Step 3: Derive eight identity-preserving states per pet**

For each canonical image, load the selected local base with `view_image`, then issue targeted built-in image edits with that visible image as the edit reference. Repeat the shared invariants in every request:

```text
Preserve the exact same character identity, anatomy, fur pattern or robot panel layout, camera, scale, lighting, and flat #00ff00 background. Change only the requested expression or pose. Keep the full silhouette inside the square canvas. No text, watermark, floor, shadow, or new object.
```

Create these variants and save them with these stable names:

| Filename | Targeted change |
| --- | --- |
| `blink.png` | eyes naturally closed, otherwise identical |
| `hover.png` | eyes and head turn slightly up-left with attentive expression |
| `pat.png` | brief delighted response; Cat pleased squint, Pauli bright smiling screen, Dog happy open-mouth lean |
| `sleep.png` | comfortable sleeping posture with closed eyes |
| `peek.png` | curious forward peek |
| `perk.png` | alert response; Cat ears forward, Pauli antenna raised, Dog head tilt and ears lifted |
| `stretch.png` | natural stretch; Dog front-leg play bow |
| `proud.png` | confident upright pose |

Copy each selected built-in output to the deterministic staging tree below:

```text
tmp/imagegen/Cat/{base,blink,hover,pat,sleep,peek,perk,stretch,proud}-source.png
tmp/imagegen/Pauli/{base,blink,hover,pat,sleep,peek,perk,stretch,proud}-source.png
tmp/imagegen/Dog/{base,blink,hover,pat,sleep,peek,perk,stretch,proud}-source.png
```

Keep these chroma-key sources outside the app resources until background removal succeeds.

- [ ] **Step 4: Remove chroma key into the final PNG paths**

Run the installed helper over the exact staging tree:

```bash
for pet in Cat Pauli Dog; do
  for state in base blink hover pat sleep peek perk stretch proud; do
    python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
      --input "tmp/imagegen/${pet}/${state}-source.png" \
      --out "Sources/DeskPetMac/Resources/Pets/${pet}/${state}.png" \
      --auto-key border \
      --soft-matte \
      --transparent-threshold 12 \
      --opaque-threshold 220 \
      --despill
  done
done
```

If a visible fringe remains, retry that image once with `--edge-contract 1`. Do not globally contract every animal edge.

- [ ] **Step 5: Validate each final asset**

For all 27 final PNGs, run:

```bash
find Sources/DeskPetMac/Resources/Pets -name '*.png' -print0 \
  | xargs -0 -n1 sips -g pixelWidth -g pixelHeight -g hasAlpha
```

Expected for every file: square dimensions at least 512×512 and `hasAlpha: yes`.

Open all 27 resources at 100% and verify:

- transparent corners;
- no green fringe around fur, whiskers, ears, antenna, or tail;
- identity and camera remain consistent within each pet;
- full silhouette is visible;
- no embedded floor, caption, watermark, or accessory.

Reject and regenerate only failing states.

### Task 5: Render realistic artwork with always-on micro-motion

**Files:**
- Create: `Sources/DeskPetMac/RealisticPetBody.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Add the resource loader and presentation-state resolver**

Create `RealisticPetBody.swift` with a focused loader:

```swift
import AppKit
import DeskPetCore
import ImageIO
import SwiftUI

enum PetArtworkLoader {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 6
        return cache
    }()

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
        if let cached = cache.object(forKey: resourceName as NSString) {
            return cached
        }

        let components = resourceName.split(separator: "/")
        guard let last = components.last else { return nil }
        let name = String(last)
        let subdirectory = components.dropLast().joined(separator: "/")
        guard let url = resourceBundle?.url(
            forResource: name,
            withExtension: "png",
            subdirectory: subdirectory
        ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }

        let image = NSImage(
            cgImage: thumbnail,
            size: NSSize(width: thumbnail.width, height: thumbnail.height)
        )
        cache.setObject(image, forKey: resourceName as NSString)
        return image
    }

    static func hasBaseArtwork(for kind: PetKind) -> Bool {
        image(named: PetArtworkManifest(petKind: kind).base) != nil
    }
}

struct RealisticPetBody: View {
    let kind: PetKind
    let isHovering: Bool
    let pulse: Int
    let isSleeping: Bool
    let isDancing: Bool
    let personalityPose: PersonalityPose?
    let pointerOffset: CGSize
    let reduceMotion: Bool

    @State private var isShowingPat = false
    @State private var patTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let state = presentationState(at: time)
            let manifest = PetArtworkManifest(petKind: kind)
            let requested = manifest.resourceName(for: state)
            let image = PetArtworkLoader.image(named: requested)
                ?? PetArtworkLoader.image(named: manifest.fallbackResourceName)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 166, height: 170)
                    .scaleEffect(animatedScale(at: time))
                    .rotationEffect(.degrees(animatedTilt(at: time)))
                    .offset(animatedOffset(at: time))
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
            }
        }
        .frame(width: 172, height: 178)
        .onChange(of: pulse) {
            patTask?.cancel()
            isShowingPat = true
            patTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                isShowingPat = false
            }
        }
        .onDisappear { patTask?.cancel() }
    }
}
```

Implement the helpers with these exact priorities:

```swift
private func presentationState(at time: TimeInterval) -> PetPresentationState {
    if isSleeping { return .sleep }
    if let personalityPose { return .personality(personalityPose) }
    if isShowingPat { return .pat }
    if isHovering { return .hover }
    if Int(time * 1.2).isMultiple(of: 7) { return .blink }
    return .idle
}
```

Motion rules:

- Reduce Motion: scale `1`, tilt `0`, offset `.zero`.
- Cat idle: `sin(time * 2.0) * 1.5` vertical breathing and `sin(time * 0.9) * 0.7°` tilt.
- Pauli idle: `sin(time * 2.8) * 2.0` vertical calibration and `sin(time * 1.6) * 0.5°` tilt.
- Dog idle: `sin(time * 2.3) * 1.8` vertical breathing and `sin(time * 3.4) * 0.9°` eager sway.
- Hover adds a clamped pointer response of at most 3pt horizontal, 2pt vertical, and 1.5° tilt.
- Dance adds `abs(sin(time * 9)) * -7pt` vertical movement and `sin(time * 9) * 7°` tilt.
- Personality pose adds at most 3pt and 3°; do not stack movement above the dance maximum.

- [ ] **Step 2: Track pointer position in the window view**

Add:

```swift
@State private var pointerOffset = CGSize.zero
```

Attach a named coordinate space to the root and update the offset during hover movement using an AppKit tracking view or SwiftUI continuous hover API available on macOS 14. Clamp the normalized result before passing it to the renderer:

```swift
private func normalizedPointerOffset(_ location: CGPoint) -> CGSize {
    CGSize(
        width: min(1, max(-1, (location.x - 110) / 110)),
        height: min(1, max(-1, (location.y - 125) / 125))
    )
}
```

Reset to `.zero` when the pointer exits.

- [ ] **Step 3: Route to realistic art with vector fallback**

Rename the current private `PetBody` to `VectorPetBody`. In the pet button label, use:

```swift
Group {
    if PetArtworkLoader.hasBaseArtwork(for: model.petKind) {
        RealisticPetBody(
            kind: model.petKind,
            isHovering: hover,
            pulse: model.affectionPulse,
            isSleeping: model.isSleeping,
            isDancing: model.isDancing,
            personalityPose: model.activePersonalityMoment?.pose,
            pointerOffset: pointerOffset,
            reduceMotion: reduceMotion
        )
    } else {
        VectorPetBody(
            kind: model.petKind,
            mood: model.mood,
            isHovering: hover,
            pulse: model.affectionPulse,
            isSleeping: model.isSleeping,
            isDancing: model.isDancing,
            personalityPose: model.activePersonalityMoment?.pose,
            reduceMotion: reduceMotion
        )
    }
}
```

Do not change bubble priority, heart particles, status reveal behavior, or button accessibility.

- [ ] **Step 4: Build the app**

Run:

```bash
swift build
```

Expected: build succeeds and SwiftPM reports processing the pet resources.

### Task 6: Add Dog controls and vector fallback

**Files:**
- Modify: `Sources/DeskPetMac/PetWindowView.swift`
- Modify: `Sources/DeskPetMac/DeskPetMacApp.swift`

- [ ] **Step 1: Add Dog to the picker**

Change the picker help to `Choose Cat, Pauli, or Dog`. Add a third button beside Cat and Pauli:

```swift
Button {
    model.selectPetKind(.dog)
} label: {
    Label("Dog", systemImage: "dog.fill")
}
.buttonStyle(
    PetChoiceButtonStyle(
        isSelected: model.petKind == .dog,
        tint: .orange
    )
)
```

If three buttons do not fit comfortably in one row, use a vertical `VStack` of three full-width choices inside the popover; do not enlarge the pet window.

- [ ] **Step 2: Add the Dog keyboard command**

In `DeskPetMacApp.swift`, append after Pauli:

```swift
Button("Use Dog") { model.selectPetKind(.dog) }
    .keyboardShortcut("3", modifiers: [.command])
```

- [ ] **Step 3: Make vector fallback exhaustive for Dog**

Update `VectorPetBody` branching from a Pauli-versus-Cat binary to an exhaustive switch:

```swift
switch kind {
case .pauli:
    PauliBody(...)
case .cat:
    VectorCatBody(...)
case .dog:
    VectorDogBody(...)
}
```

Extract only the existing Cat branch into `VectorCatBody`; do not restyle it. Add a compact `VectorDogBody` using the existing `PetPalette` warm colors, rounded head/body shapes, two floppy-ear shapes, muzzle, eyes, and an animated tail. Keep it deliberately lightweight because it is a fallback, but ensure it supports sleep/blink and the four semantic poses.

- [ ] **Step 4: Build and test after UI integration**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and the executable builds with exhaustive `PetKind` switches.

### Task 7: Documentation and full verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document the visible behavior**

Update the pet feature description to state:

```markdown
- Three distinct companions: a mischievous realistic Cat, curious PBR robot Pauli, and enthusiastic realistic Dog.
- Always-on idle life through breathing, gaze, ears, antenna, and character-specific motion.
- Choose Cat, Pauli, or Dog from the picker or with `⌘1`, `⌘2`, and `⌘3`.
```

- [ ] **Step 2: Check formatting scope and whitespace**

Run:

```bash
swift format lint --strict Sources/DeskPetCore/Models.swift Sources/DeskPetCore/PersonalityMoment.swift Sources/DeskPetCore/PetArtworkManifest.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift Sources/DeskPetMac/RealisticPetBody.swift Sources/DeskPetMac/PetWindowView.swift Sources/DeskPetMac/DeskPetMacApp.swift
git diff --check
```

If the formatter reports the repository's existing four-space-style mismatch in untouched sections, report it and do not bulk-format unrelated code. Fix all new-code diagnostics.

- [ ] **Step 3: Run the full automated verification**

Run fresh:

```bash
swift test
swift build -c release
scripts/package-app.sh
```

Expected: every command exits 0.

- [ ] **Step 4: Restart and visually inspect the real app**

Restart `.build/release/DeskPetMac.app`. Inspect Cat, Pauli, and Dog at normal Retina scale for at least 10 seconds each. Exercise:

- idle motion;
- pointer hover and exit;
- pat response;
- sleep visual by using the available debug/runtime path without mutating persisted bond state;
- dance;
- all four personality pose PNGs at 100% and in the rendered contact sheet;
- missing-resource fallback by temporarily moving one base PNG, verifying vector display, then restoring it before packaging.

Verify no pet is cropped, no animal has green fringe, and the three silhouettes are distinguishable without reading the name.

- [ ] **Step 5: Review the final diff**

Run:

```bash
git status --short
git diff --stat
git diff -- Sources/DeskPetCore Sources/DeskPetMac Tests README.md Package.swift
```

Confirm the diff contains only the approved realistic redesign, Dog integration, tests, resources, and documentation. Do not commit or push unless the user asks.
