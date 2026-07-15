# DeskPet Personality Moments and Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add occasional contextual personality moments with distinct Cat/Pauli voices, then refine the character presentation with natural independent cat ears, expressive poses, and an unobtrusive speech bubble.

**Architecture:** Pure moment content, filtering, weighted choice, and interval calculation live in `DeskPetCore` so they are deterministic and testable. `PetViewModel` owns task scheduling and presentation state, while SwiftUI views only render the active moment and map semantic poses to character-specific motion.

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing, SwiftUI, AppKit

**Repository rule:** Do not create commits unless the user explicitly asks. The plan therefore uses verification checkpoints without commit steps.

---

## File map

- Create `Sources/DeskPetCore/PersonalityMoment.swift`: moment models, 24-line catalog, eligibility, weighted selection, and interval calculation.
- Modify `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`: deterministic selector, exclusion, eligibility, catalog, and interval tests.
- Modify `Sources/DeskPetMac/PetViewModel.swift`: scheduler tasks, active moment publication, conflict checks, and pat conversion.
- Create `Sources/DeskPetMac/PersonalityBubble.swift`: focused SwiftUI speech bubble with accessibility behavior.
- Modify `Sources/DeskPetMac/PetWindowView.swift`: bubble priority, semantic poses, natural cat ears, Pauli pose mapping, Reduce Motion, and control feedback polish.
- Modify `README.md`: document personality moments and distinct pet behavior.

### Task 1: Core personality model and deterministic selection

**Files:**
- Create: `Sources/DeskPetCore/PersonalityMoment.swift`
- Test: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Add failing model, catalog, filtering, and schedule tests**

Append a `Personality moments` suite that asserts:

```swift
@Suite("Personality moments")
struct PersonalityMomentTests {
    @Test("catalog contains twelve unique lines for each pet and three per category")
    func catalogShape() {
        let moments = PersonalityMomentCatalog.all
        for pet in PetKind.allCases {
            let petMoments = moments.filter { $0.petKind == pet }
            #expect(petMoments.count == 12)
            #expect(Set(petMoments.map(\.id)).count == 12)
            for category in PersonalityMomentCategory.allCases {
                #expect(petMoments.filter { $0.category == category }.count == 3)
            }
        }
    }

    @Test("selector respects pet, context, exclusions, and presentation blocks")
    func contextualSelection() {
        let context = PersonalityMomentContext(
            petKind: .cat,
            mood: .rainy,
            workProgress: 0.8,
            requestedCategory: nil,
            isPresentationBlocked: false
        )
        let selected = PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: context,
            excluding: [],
            roll: 0
        )
        #expect(selected?.petKind == .cat)
        #expect(selected?.category != .interaction)
        #expect(selected.map { $0.matches(context) } == true)

        let excluded = selected.map { Set([$0.id]) } ?? []
        let replacement = PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: context,
            excluding: excluded,
            roll: 0
        )
        #expect(replacement?.id != selected?.id)

        let blocked = PersonalityMomentContext(
            petKind: .cat,
            mood: .rainy,
            workProgress: 0.8,
            requestedCategory: nil,
            isPresentationBlocked: true
        )
        #expect(PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: blocked,
            excluding: [],
            roll: 0
        ) == nil)
    }

    @Test("interaction requests select only interaction lines")
    func interactionSelection() {
        let context = PersonalityMomentContext(
            petKind: .pauli,
            mood: .cozy,
            workProgress: 0,
            requestedCategory: .interaction,
            isPresentationBlocked: false
        )
        let selected = PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: context,
            excluding: [],
            roll: 2
        )
        #expect(selected?.petKind == .pauli)
        #expect(selected?.category == .interaction)
    }

    @Test("personality delay stays between ten and twenty minutes")
    func scheduleBounds() {
        #expect(PersonalityMomentSchedule.delay(for: 0) == 10 * 60)
        #expect(PersonalityMomentSchedule.delay(for: 600) == 20 * 60)
        #expect((10 * 60)...(20 * 60) ~= PersonalityMomentSchedule.delay(for: 9_999))
    }
}
```

- [ ] **Step 2: Run the new suite and verify it fails**

Run:

```bash
swift test --filter PersonalityMomentTests
```

Expected: compilation fails because the personality types do not exist.

- [ ] **Step 3: Implement the minimal Core API and exact catalog**

Create public `Sendable` and `Equatable` types with these signatures:

```swift
public enum PersonalityPose: String, CaseIterable, Equatable, Sendable {
    case peek, perk, stretch, proud
}

public enum PersonalityMomentCategory: String, CaseIterable, Equatable, Sendable {
    case general, weather, focus, interaction
}

public struct PersonalityMoment: Identifiable, Equatable, Sendable {
    public let id: String
    public let petKind: PetKind
    public let category: PersonalityMomentCategory
    public let pose: PersonalityPose
    public let line: String
    public let moods: [PetWeatherMood]
    public let minimumWorkProgress: Double?
    public let weight: Int

    public func matches(_ context: PersonalityMomentContext) -> Bool
}

public struct PersonalityMomentContext: Equatable, Sendable {
    public let petKind: PetKind
    public let mood: PetWeatherMood
    public let workProgress: Double
    public let requestedCategory: PersonalityMomentCategory?
    public let isPresentationBlocked: Bool
}

public enum PersonalityMomentSelector {
    public static func select(
        from moments: [PersonalityMoment],
        context: PersonalityMomentContext,
        excluding recentIDs: Set<String>,
        roll: Int
    ) -> PersonalityMoment?
}

public enum PersonalityMomentSchedule {
    public static func delay(for roll: Int) -> TimeInterval
}
```

Implement `matches` with these exact rules:

- pet must match;
- when `requestedCategory` is non-nil, category must equal it;
- spontaneous requests exclude `.interaction`;
- `.weather` requires `moods` to contain the current mood;
- `.focus` requires `workProgress >= minimumWorkProgress`;
- blocked contexts yield no selection.

Implement weighted choice by filtering eligible non-recent moments, summing `max(1, weight)`, normalizing `abs(roll)` safely without overflowing, and walking cumulative weights. `delay(for:)` maps any integer to the closed range `600...1200` seconds.

Populate exactly 12 moments per pet and exactly 3 per category. Use stable IDs such as `cat.general.supervising` and the approved character voices from the design spec. Weather entries may each cover multiple related moods so every weather mood has at least one eligible line.

- [ ] **Step 4: Run Core tests and verify green**

Run:

```bash
swift test --filter PersonalityMomentTests
swift test
```

Expected: the new suite and all existing suites pass.

### Task 2: ViewModel scheduling and interaction conversion

**Files:**
- Modify: `Sources/DeskPetMac/PetViewModel.swift`

- [ ] **Step 1: Add presentation state and task lifecycle**

Add:

```swift
@Published private(set) var activePersonalityMoment: PersonalityMoment?

private var personalityScheduleTask: Task<Void, Never>?
private var personalityDismissTask: Task<Void, Never>?
private var recentPersonalityMomentIDs: [String] = []
```

Call `startPersonalitySchedule()` from `start()` after existing monitors start. The schedule task sleeps for `PersonalityMomentSchedule.delay(for: Int.random(in: 0...600))`, attempts one spontaneous moment, then repeats until cancelled.

- [ ] **Step 2: Implement context, selection, presentation, and cleanup helpers**

Add focused private helpers:

```swift
private var isPersonalityPresentationBlocked: Bool {
    isSleeping || isReminderVisible || isStatusVisible || isPetPickerVisible
        || isSettingsVisible || isRefreshingWeather || isDancing
}

private func personalityContext(
    requestedCategory: PersonalityMomentCategory? = nil,
    ignoringCurrentMoment: Bool = false
) -> PersonalityMomentContext

@discardableResult
private func presentPersonalityMoment(
    category: PersonalityMomentCategory? = nil,
    ignoringCurrentMoment: Bool = false
) -> Bool

private func clearPersonalityMoment()
```

`presentPersonalityMoment` uses the catalog, the last three IDs, and `Int.random(in: Int.min...Int.max)`. On success it publishes the selected moment, records its ID, trims history to three, cancels/restarts the 3.5-second dismiss task, and returns `true`.

- [ ] **Step 3: Convert a click during a moment into an interaction response**

At the beginning of `pat()`, capture whether a moment was active. Preserve all existing wake, combo, bond, pulse, heart, reminder, and persistence behavior. If a moment was active, replace it with a `.interaction` moment and do not reveal the status bubble; otherwise preserve `revealStatusBriefly()`.

Clear an active personality moment when refresh, settings, pet selection, dance, sleep, or a break reminder takes priority. Do not activate the app, post notifications, play audio, or add persistence keys.

- [ ] **Step 4: Compile the integration**

Run:

```bash
swift build
```

Expected: build succeeds with Swift 6 strict concurrency.

### Task 3: Speech bubble and presentation priority

**Files:**
- Create: `Sources/DeskPetMac/PersonalityBubble.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Add a focused speech bubble view**

Create an internal `PersonalityBubble` that accepts `PersonalityMoment` and renders:

```swift
struct PersonalityBubble: View {
    let moment: PersonalityMoment

    var body: some View {
        Text(moment.line)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(red: 0.27, green: 0.21, blue: 0.25))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 194)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottom) { SpeechTail().offset(y: 7) }
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.42)))
            .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
            .accessibilityLabel(moment.line)
    }
}
```

Implement `SpeechTail` as a small rounded triangular `Shape` filled with the same warm translucent surface.

- [ ] **Step 2: Add bubble priority and transitions**

Update `bubbleOverlay` so the order is exactly:

```swift
if model.isReminderVisible {
    BreakBubble(model: model)
} else if hover || model.isStatusVisible || model.isRefreshingWeather || model.isSettingsVisible {
    StatusBubble(model: model)
} else if let moment = model.activePersonalityMoment {
    PersonalityBubble(moment: moment)
}
```

Pass `model.activePersonalityMoment?.pose` into `PetBody`. Add animation keyed to the active moment ID, and use `.move(edge: .top).combined(with: .opacity)` for the bubble.

- [ ] **Step 3: Compile the SwiftUI presentation**

Run:

```bash
swift build
```

Expected: build succeeds and the window remains `220×250`.

### Task 4: Natural cat ears and pet-specific pose language

**Files:**
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Replace the existing ear shape with an anchored layered ear**

Replace `Ear` with `CatEarShape` and `CatEarView`. `CatEarShape` must use a broad lower base, curved sides, and a softened tip. `CatEarView` layers the palette ear color, a smaller pink inner ear at reduced opacity, and a narrow white highlight. Keep ears drawn before the face so the head naturally occludes their bases.

- [ ] **Step 2: Drive left and right ears independently**

Inside `PetBody`, derive separate values from `t` and `personalityPose`:

```swift
let leftEarDrift = sin(t * 3.7) * 2.4
let rightEarDrift = sin(t * 3.3 + 1.1) * 2.0
let leftPoseAngle = personalityPose == .perk ? 10.0 : personalityPose == .stretch ? -8.0 : 0
let rightPoseAngle = personalityPose == .proud ? 9.0 : personalityPose == .peek ? -7.0 : 0
```

Apply different rotation anchors, offsets, and spring responses. When Reduce Motion is enabled, keep the static pose angles but remove timeline drift and large tilt/translation.

- [ ] **Step 3: Map semantic poses to Cat and Pauli expressions**

Extend `Face`, `Eye`, `PauliBody`, and `PauliFace` to accept `PersonalityPose?`. Cat maps poses to wink/squint/alert eyes, cheek intensity, and slight head tilt. Pauli maps the same semantics to eye-screen geometry, antenna tilt, status-light pulse, and pod offset. Keep weather and sleep behavior authoritative.

- [ ] **Step 4: Refine control feedback without changing behavior**

Standardize `PetIconButtonStyle` to a `29×27` hit presentation, slightly deepen the warm material shadow, and keep the existing pressed scale and all accessibility/help text. Do not change button order, shortcuts, popovers, or actions.

- [ ] **Step 5: Compile and run regression tests**

Run:

```bash
swift build
swift test
```

Expected: build succeeds and all tests pass.

### Task 5: Documentation and final verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document the shipped behavior**

Add feature bullets in Chinese and English describing occasional personality moments, distinct Cat/Pauli voices, and the natural independent cat-ear reactions. Do not claim tasks, collectibles, streaks, audio, or new settings.

- [ ] **Step 2: Run formatting and whitespace checks**

Run:

```bash
swift format lint --strict --recursive Sources Tests Package.swift
git diff --check
```

Expected: formatter reports no violations and `git diff --check` is silent. If `swift format` is unavailable, report that result and still run `git diff --check`.

- [ ] **Step 3: Run full automated verification**

Run:

```bash
swift test
swift build
scripts/package-app.sh
```

Expected: tests pass, debug build succeeds, and packaging prints the path to `.build/release/DeskPetMac.app`.

- [ ] **Step 4: Inspect the packaged app in the real macOS UI**

Launch the packaged app and verify the default state, hover controls, Cat and Pauli appearance, pat conversion, bubble priority, and Reduce Motion behavior where observable. Confirm that the app does not activate itself or post personality notifications.

- [ ] **Step 5: Review the final diff and report without committing**

Run:

```bash
git status --short --branch
git diff --stat
git diff --check
```

Expected: only the scoped Core, app UI, tests, README, spec, and plan files are changed; visual companion files remain untracked under `.superpowers/`. Do not stage, commit, or push.
