# Integrated Weather Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace weather text and badge-like accessories with restrained, layered weather animation and subtle Cat, Pauli, and Dog reactions.

**Architecture:** Keep Open-Meteo and `PetViewModel.mood` unchanged. Add a pure `DeskPetCore` profile for exhaustive, testable particle budgets and pet reactions, render deterministic SwiftUI backdrop/foreground layers around the existing pet button, and apply low-priority reaction transforms inside realistic and vector bodies. Remove legacy weather text/accessories without changing the `220 x 250` window, control strip, artwork cache, or interaction priority.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, existing SwiftPM resource bundle and packaging scripts.

**Approved spec:** `docs/superpowers/specs/2026-07-16-integrated-weather-animation-design.md`

**Repository constraint:** Do not commit or push unless the user explicitly asks. Replace the usual per-task commit steps with `git diff --check` and scoped diff review checkpoints.

---

## File Structure

- Create `Sources/DeskPetCore/WeatherAnimationProfile.swift`: pure, testable weather particle budgets, transition duration, and character-reaction mapping.
- Create `Sources/DeskPetMac/WeatherAtmosphere.swift`: deterministic backdrop/foreground SwiftUI weather layers and artwork-local lighting/accent views.
- Modify `Sources/DeskPetMac/RealisticPetBody.swift`: accept mood and combine low-priority weather transforms with existing motion.
- Modify `Sources/DeskPetMac/PetWindowView.swift`: wrap the pet in weather layers, pass mood, simplify the status bubble, remove legacy `WeatherParticles` and `MoodAccessory`, and add a debug-only preview override.
- Modify `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`: profile budgets, reaction mapping, and storm/reduce-motion invariants.
- Modify `README.md`: describe integrated weather motion and remove stale weather-accessory wording.

### Task 1: Add Testable Weather Animation Profiles

**Files:**
- Create: `Sources/DeskPetCore/WeatherAnimationProfile.swift`
- Modify: `Tests/DeskPetCoreTests/DeskPetCoreTests.swift`

- [ ] **Step 1: Write failing profile tests**

Append this suite after `WeatherMoodMappingTests`:

```swift
@Suite("Weather animation profiles")
struct WeatherAnimationProfileTests {
    @Test("every weather stays within the particle budget")
    func particleBudget() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherAnimationProfile(mood: mood)

            #expect(profile.backgroundParticleCount >= 0)
            #expect(profile.foregroundParticleCount >= 0)
            #expect(
                profile.backgroundParticleCount + profile.foregroundParticleCount <= 16
            )
            #expect(profile.transitionDuration == 0.6)
        }
    }

    @Test("only storms support lightning")
    func lightningIsStormOnly() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherAnimationProfile(mood: mood)
            #expect(profile.supportsLightning == (mood == .stormy))
        }

        #expect(WeatherAnimationProfile(mood: .stormy).lightningPeriod == 22)
    }

    @Test("weather reactions are character specific")
    func reactionsAreCharacterSpecific() {
        #expect(WeatherAnimationProfile.reaction(for: .cat, mood: .rainy) == .shelter)
        #expect(WeatherAnimationProfile.reaction(for: .pauli, mood: .rainy) == .visorGlow)
        #expect(WeatherAnimationProfile.reaction(for: .dog, mood: .rainy) == .shake)
        #expect(WeatherAnimationProfile.reaction(for: .cat, mood: .stormy) == .startle)
        #expect(WeatherAnimationProfile.reaction(for: .pauli, mood: .stormy) == .antennaGlow)
        #expect(WeatherAnimationProfile.reaction(for: .dog, mood: .stormy) == .startle)
    }

    @Test("every pet and mood has a reaction")
    func exhaustiveReactions() {
        for pet in PetKind.allCases {
            for mood in PetWeatherMood.allCases {
                #expect(WeatherAnimationProfile.reaction(for: pet, mood: mood) != .none)
            }
        }
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```bash
swift test --filter WeatherAnimationProfileTests
```

Expected: compilation fails because `WeatherAnimationProfile` does not exist.

- [ ] **Step 3: Add the minimal pure profile implementation**

Create `Sources/DeskPetCore/WeatherAnimationProfile.swift`:

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

public struct WeatherAnimationProfile: Equatable, Sendable {
    public let backgroundParticleCount: Int
    public let foregroundParticleCount: Int
    public let showsGroundRipple: Bool
    public let supportsLightning: Bool
    public let lightningPeriod: Double?
    public let transitionDuration: Double

    public init(mood: PetWeatherMood) {
        transitionDuration = 0.6

        switch mood {
        case .sunny:
            backgroundParticleCount = 0
            foregroundParticleCount = 0
            showsGroundRipple = false
            supportsLightning = false
            lightningPeriod = nil
        case .cloudy:
            backgroundParticleCount = 1
            foregroundParticleCount = 0
            showsGroundRipple = false
            supportsLightning = false
            lightningPeriod = nil
        case .foggy:
            backgroundParticleCount = 1
            foregroundParticleCount = 1
            showsGroundRipple = false
            supportsLightning = false
            lightningPeriod = nil
        case .rainy:
            backgroundParticleCount = 6
            foregroundParticleCount = 6
            showsGroundRipple = true
            supportsLightning = false
            lightningPeriod = nil
        case .snowy:
            backgroundParticleCount = 6
            foregroundParticleCount = 8
            showsGroundRipple = false
            supportsLightning = false
            lightningPeriod = nil
        case .stormy:
            backgroundParticleCount = 4
            foregroundParticleCount = 4
            showsGroundRipple = true
            supportsLightning = true
            lightningPeriod = 22
        case .cozy:
            backgroundParticleCount = 0
            foregroundParticleCount = 0
            showsGroundRipple = false
            supportsLightning = false
            lightningPeriod = nil
        }
    }

    public static func reaction(
        for pet: PetKind,
        mood: PetWeatherMood
    ) -> PetWeatherReaction {
        switch (pet, mood) {
        case (.cat, .sunny), (.cat, .cloudy), (.cat, .snowy), (.cat, .cozy):
            .settle
        case (.cat, .foggy):
            .observe
        case (.cat, .rainy):
            .shelter
        case (.cat, .stormy):
            .startle

        case (.pauli, .sunny), (.pauli, .foggy), (.pauli, .stormy):
            .antennaGlow
        case (.pauli, .rainy), (.pauli, .snowy):
            .visorGlow
        case (.pauli, .cloudy), (.pauli, .cozy):
            .settle

        case (.dog, .sunny):
            .headLift
        case (.dog, .cloudy), (.dog, .cozy):
            .settle
        case (.dog, .foggy):
            .observe
        case (.dog, .rainy):
            .shake
        case (.dog, .snowy):
            .sniff
        case (.dog, .stormy):
            .startle
        }
    }
}
```

- [ ] **Step 4: Run focused and full core tests**

Run:

```bash
swift test --filter WeatherAnimationProfileTests
swift test
```

Expected: the focused suite and all existing suites pass.

- [ ] **Step 5: Review the scoped diff**

Run:

```bash
git diff --check
git diff -- Sources/DeskPetCore/WeatherAnimationProfile.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift
```

Expected: no whitespace errors; only the profile and its tests changed.

### Task 2: Build Deterministic Weather Backdrop and Foreground Layers

**Files:**
- Create: `Sources/DeskPetMac/WeatherAtmosphere.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Establish a failing compile contract**

Temporarily replace the existing root `WeatherParticles` call with these missing types around the pet button scene:

```swift
WeatherBackdrop(mood: model.mood, reduceMotion: reduceMotion)
WeatherForeground(mood: model.mood, reduceMotion: reduceMotion)
```

Run:

```bash
swift build
```

Expected: compilation fails with `cannot find 'WeatherBackdrop' in scope` and `cannot find 'WeatherForeground' in scope`.

- [ ] **Step 2: Create deterministic particle helpers and public-in-target view APIs**

Create `Sources/DeskPetMac/WeatherAtmosphere.swift` with these declarations and deterministic helpers:

```swift
import DeskPetCore
import SwiftUI

struct WeatherBackdrop: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .back, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WeatherForeground: View {
    let mood: PetWeatherMood
    let reduceMotion: Bool

    var body: some View {
        WeatherAtmosphereLayer(mood: mood, layer: .front, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private enum WeatherLayer: Equatable {
    case back
    case front
}

private struct WeatherAtmosphereLayer: View {
    let mood: PetWeatherMood
    let layer: WeatherLayer
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                atmosphere(time: 0, moving: false)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    atmosphere(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        moving: true
                    )
                }
            }
        }
        .frame(width: 172, height: 178)
    }

    @ViewBuilder
    private func atmosphere(time: TimeInterval, moving: Bool) -> some View {
        let profile = WeatherAnimationProfile(mood: mood)

        ZStack {
            switch mood {
            case .sunny:
                if layer == .back {
                    Circle()
                        .fill(Color.yellow.opacity(0.10))
                        .frame(width: 132, height: 132)
                        .blur(radius: 12)
                        .scaleEffect(moving ? 1 + sin(time * 1.2) * 0.025 : 1)
                        .offset(y: 6)
                }
            case .cloudy:
                if layer == .back {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.16))
                        .offset(
                            x: moving ? CGFloat(sin(time * 0.30)) * 44 : -22,
                            y: -54
                        )
                }
            case .foggy:
                fogBands(time: time, moving: moving)
            case .rainy:
                rain(
                    count: layer == .back
                        ? profile.backgroundParticleCount
                        : profile.foregroundParticleCount,
                    time: time,
                    moving: moving
                )
                if layer == .front, profile.showsGroundRipple {
                    groundRipple(time: time, moving: moving, color: .blue)
                }
            case .snowy:
                snow(
                    count: layer == .back
                        ? profile.backgroundParticleCount
                        : profile.foregroundParticleCount,
                    time: time,
                    moving: moving
                )
                if layer == .back {
                    Ellipse()
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 110, height: 22)
                        .blur(radius: 8)
                        .offset(y: 66)
                }
            case .stormy:
                if layer == .back {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.indigo.opacity(0.10))
                        .frame(width: 168, height: 174)
                    rain(
                        count: profile.backgroundParticleCount,
                        time: time,
                        moving: moving
                    )
                } else {
                    rain(
                        count: profile.foregroundParticleCount,
                        time: time,
                        moving: moving
                    )
                    if moving {
                        stormFlash(time: time, period: profile.lightningPeriod ?? 22)
                    }
                }
            case .cozy:
                if layer == .back {
                    Ellipse()
                        .fill(Color.orange.opacity(0.10))
                        .frame(width: 136, height: 116)
                        .blur(radius: 16)
                        .scaleEffect(moving ? 1 + sin(time * 0.8) * 0.02 : 1)
                        .offset(y: 12)
                }
            }
        }
    }

    private func normalized(_ index: Int, salt: Int) -> CGFloat {
        CGFloat((index * 37 + salt * 17) % 101) / 100
    }

    private func wrappedY(
        index: Int,
        time: TimeInterval,
        speed: Double,
        moving: Bool
    ) -> CGFloat {
        let start = Double(normalized(index, salt: 3)) * 210 - 105
        guard moving else { return CGFloat(start) }
        return CGFloat((start + time * speed + 105).truncatingRemainder(dividingBy: 210) - 105)
    }

    private func rain(
        count: Int,
        time: TimeInterval,
        moving: Bool
    ) -> some View {
        ForEach(0..<count, id: \.self) { index in
            Capsule()
                .fill(Color.blue.opacity(layer == .front ? 0.42 : 0.22))
                .frame(width: layer == .front ? 2.5 : 2, height: layer == .front ? 13 : 10)
                .rotationEffect(.degrees(-8))
                .offset(
                    x: normalized(index, salt: layer == .front ? 7 : 11) * 154 - 77,
                    y: wrappedY(index: index, time: time, speed: 62, moving: moving)
                )
        }
    }

    private func snow(
        count: Int,
        time: TimeInterval,
        moving: Bool
    ) -> some View {
        ForEach(0..<count, id: \.self) { index in
            let size = 3 + normalized(index, salt: 13) * 3
            Circle()
                .fill(.white.opacity(layer == .front ? 0.76 : 0.42))
                .frame(width: size, height: size)
                .offset(
                    x: normalized(index, salt: 19) * 154 - 77
                        + (moving ? CGFloat(sin(time * 0.8 + Double(index))) * 5 : 0),
                    y: wrappedY(index: index, time: time, speed: 20, moving: moving)
                )
        }
    }

    @ViewBuilder
    private func fogBands(time: TimeInterval, moving: Bool) -> some View {
        let isFront = layer == .front
        Capsule()
            .fill(.white.opacity(isFront ? 0.20 : 0.12))
            .frame(width: isFront ? 132 : 148, height: isFront ? 17 : 22)
            .blur(radius: isFront ? 6 : 9)
            .offset(
                x: moving ? CGFloat(sin(time * (isFront ? 0.22 : 0.16))) * 24 : 0,
                y: isFront ? 54 : 42
            )
    }

    @ViewBuilder
    private func groundRipple(
        time: TimeInterval,
        moving: Bool,
        color: Color
    ) -> some View {
        let phase = moving ? time.truncatingRemainder(dividingBy: 2.8) / 2.8 : 0.35
        Ellipse()
            .stroke(color.opacity(0.22 * (1 - phase)), lineWidth: 1.5)
            .frame(width: 34, height: 10)
            .scaleEffect(0.65 + phase * 0.85)
            .offset(x: 26, y: 68)
    }

    @ViewBuilder
    private func stormFlash(time: TimeInterval, period: Double) -> some View {
        let phase = time.truncatingRemainder(dividingBy: period)
        let opacity = phase < 0.08 ? 0.16 * (1 - phase / 0.08) : 0

        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(opacity))
            .frame(width: 168, height: 174)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.yellow.opacity(opacity * 3))
                    .padding(18)
            }
    }
}
```

- [ ] **Step 3: Keep the temporary integration compiling without changing final layering yet**

For this task only, place both new views as non-interactive root layers using the existing mood:

```swift
WeatherBackdrop(mood: model.mood, reduceMotion: reduceMotion)
WeatherForeground(mood: model.mood, reduceMotion: reduceMotion)
```

The final pet-scene placement happens in Task 3.

- [ ] **Step 4: Build and inspect deterministic constraints**

Run:

```bash
swift build
rg -n "random|Double.random|CGFloat.random" Sources/DeskPetMac/WeatherAtmosphere.swift
```

Expected: build passes; `rg` returns no matches, proving particle locations do not re-randomize in `body`.

- [ ] **Step 5: Review the scoped diff**

Run:

```bash
git diff --check
git diff -- Sources/DeskPetMac/WeatherAtmosphere.swift Sources/DeskPetMac/PetWindowView.swift
```

Expected: no whitespace errors and no changes to controls, bubbles, pet selection, or artwork loading.

### Task 3: Integrate Weather Around the Pet and Remove Weather Text/Badges

**Files:**
- Modify: `Sources/DeskPetMac/PetWindowView.swift`

- [ ] **Step 1: Add the debug-only weather preview selector**

Add this computed property to `PetWindowView`:

```swift
private var displayedMood: PetWeatherMood {
    #if DEBUG
    if let rawValue = ProcessInfo.processInfo.environment["DESKPET_WEATHER_PREVIEW"],
       let preview = PetWeatherMood(rawValue: rawValue) {
        return preview
    }
    #endif

    return model.mood
}
```

This creates no release UI and does not alter weather fetching or refresh cadence.

- [ ] **Step 2: Replace the pet button with a layered pet scene**

Inside the existing `VStack`, replace the bare pet `Button` with:

```swift
ZStack {
    WeatherBackdrop(mood: displayedMood, reduceMotion: reduceMotion)
        .id("weather-back-\(displayedMood.rawValue)")
        .transition(.opacity)

    Button {
        model.pat()
    } label: {
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
                    mood: displayedMood,
                    isHovering: hover,
                    pulse: model.affectionPulse,
                    isSleeping: model.isSleeping,
                    isDancing: model.isDancing,
                    personalityPose: model.activePersonalityMoment?.pose,
                    reduceMotion: reduceMotion
                )
            }
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Pat \(model.petKind.displayName)")

    WeatherForeground(mood: displayedMood, reduceMotion: reduceMotion)
        .id("weather-front-\(displayedMood.rawValue)")
        .transition(.opacity)
}
.frame(width: 172, height: 178)
.animation(
    .easeInOut(duration: WeatherAnimationProfile(mood: displayedMood).transitionDuration),
    value: displayedMood
)
```

Remove the temporary root weather calls from Task 2. Keep `ControlStrip`, `HeartParticleOverlay`, `bubbleOverlay`, and combo badge in their current ZStack order.

- [ ] **Step 3: Remove weather content from the status bubble**

Replace the top of `StatusBubble.body` with:

```swift
VStack(spacing: 4) {
    Text(model.petKind.displayName)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)

    Text("Focus \(model.activeMinutes)m")
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)

    ProgressView(value: model.workProgress)
        .controlSize(.small)
        .tint(.mint)
        .frame(width: 124)

    BondReadout(model: model)
}
```

Delete the old mood line and the `locationName` / `temperatureLabel` HStack. Do not change reminder or personality bubbles.

- [ ] **Step 4: Remove badge-like legacy weather rendering**

Delete both of these from `PetWindowView.swift`:

- The `MoodAccessory(mood:)` call inside `VectorPetBody`.
- The complete private `MoodAccessory` and `WeatherParticles` structs.
- The private `CloudPuff` and `LightningBolt` shapes if `rg` confirms they have no remaining callers.

Use:

```bash
rg -n "MoodAccessory|WeatherParticles|locationName|temperatureLabel|petLine" Sources/DeskPetMac/PetWindowView.swift
```

Expected: no matches.

- [ ] **Step 5: Build and verify UI contracts**

Run:

```bash
swift build
swift test
rg -n "ControlStrip|HeartParticleOverlay|bubbleOverlay|accessibilityLabel" Sources/DeskPetMac/PetWindowView.swift
git diff --check
```

Expected: build and all tests pass; control/bubble/heart/accessibility calls remain present; whitespace check passes.

### Task 4: Add Low-Priority Character-Specific Weather Reactions

**Files:**
- Modify: `Sources/DeskPetMac/RealisticPetBody.swift`
- Modify: `Sources/DeskPetMac/PetWindowView.swift`
- Modify: `Sources/DeskPetMac/WeatherAtmosphere.swift`

- [ ] **Step 1: Add mood to the realistic renderer API and confirm the compile failure**

Add this stored property after `kind`:

```swift
let mood: PetWeatherMood
```

Update the Task 3 `RealisticPetBody` construction at the same time by adding:

```swift
mood: displayedMood,
```

Run:

```bash
swift build
```

Expected before completing this step: any remaining `RealisticPetBody` construction without `mood` fails to compile. Update only genuine construction sites; do not add a default value that hides missing wiring.

- [ ] **Step 2: Define reaction priority and deterministic timing helpers**

Add these helpers to `RealisticPetBody`:

```swift
private var weatherReaction: PetWeatherReaction {
    WeatherAnimationProfile.reaction(for: kind, mood: mood)
}

private var allowsWeatherReaction: Bool {
    !reduceMotion
        && !isSleeping
        && !isDancing
        && personalityPose == nil
        && !isShowingPat
        && !isHovering
}

private func weatherPhase(at time: TimeInterval, period: Double) -> Double {
    time.truncatingRemainder(dividingBy: period) / period
}

private var weatherIdleMultiplier: Double {
    guard allowsWeatherReaction else { return 1 }
    switch mood {
    case .cloudy: 0.68
    case .snowy: 0.76
    case .sunny, .foggy, .rainy, .stormy, .cozy: 1
    }
}

private func weatherScale(at time: TimeInterval) -> CGFloat {
    guard allowsWeatherReaction else { return 1 }
    switch weatherReaction {
    case .settle:
        return 0.998 + sin(time * 0.45) * 0.001
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
        return sin(time * 0.55) * 1.2
    case .shake:
        let phase = weatherPhase(at: time, period: 16)
        return phase < 0.08 ? sin(phase / 0.08 * .pi * 6) * 2.4 : 0
    case .startle:
        let phase = weatherPhase(at: time, period: 22)
        return phase < 0.05 ? sin(phase / 0.05 * .pi) * 1.8 : 0
    case .none, .settle, .headLift, .shelter, .antennaGlow, .visorGlow, .sniff:
        return 0
    }
}

private func weatherOffset(at time: TimeInterval) -> CGSize {
    guard allowsWeatherReaction else { return .zero }

    switch weatherReaction {
    case .headLift:
        return CGSize(width: 0, height: sin(time * 0.42) * -1.2)
    case .observe:
        return CGSize(width: sin(time * 0.55) * 1.1, height: 0)
    case .shelter:
        return CGSize(width: 0, height: 1.2)
    case .sniff:
        return CGSize(width: 0, height: sin(time * 0.62) * -1.0)
    case .shake:
        let phase = weatherPhase(at: time, period: 16)
        return phase < 0.08
            ? CGSize(width: sin(phase / 0.08 * .pi * 6) * 1.8, height: 0)
            : .zero
    case .startle:
        let phase = weatherPhase(at: time, period: 22)
        return phase < 0.05
            ? CGSize(width: 0, height: sin(phase / 0.05 * .pi) * -2.0)
            : .zero
    case .none, .settle, .antennaGlow, .visorGlow:
        return .zero
    }
}
```

These fixed 16- and 22-second cycles satisfy the approved 12-20 second rain reaction and 16-28 second storm reaction ranges without runtime randomness.

- [ ] **Step 3: Compose reactions with existing motion without changing state priority**

Multiply the existing breathing and idle-height amplitudes by `weatherIdleMultiplier`. Replace the existing scale, rotation, and offset modifiers with the following composition so existing animation remains primary and no duplicate scale modifier remains:

```swift
.scaleEffect(animatedScale(at: time) * weatherScale(at: time))
.rotationEffect(.degrees(animatedTilt(at: time) + weatherTilt(at: time)))
.offset(combinedOffset(at: time))
```

Add:

```swift
private func combinedOffset(at time: TimeInterval) -> CGSize {
    let existing = animatedOffset(at: time)
    let weather = weatherOffset(at: time)
    return CGSize(
        width: existing.width + weather.width,
        height: existing.height + weather.height
    )
}
```

Do not change `presentationState(at:)`; sleep, personality, pat, hover, blink, and idle artwork priority must remain exactly as implemented.

- [ ] **Step 4: Add artwork-local light and Pauli accent views**

Append these target-internal views to `WeatherAtmosphere.swift`:

```swift
struct PetWeatherArtworkLight: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        switch mood {
        case .sunny:
            LinearGradient(
                colors: [.yellow.opacity(0.12), .clear, .orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cloudy:
            LinearGradient(
                colors: [.clear, .black.opacity(0.07), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: reduceMotion ? 0 : CGFloat(sin(time * 0.30)) * 46)
        case .rainy, .stormy:
            LinearGradient(
                colors: [.cyan.opacity(kind == .pauli ? 0.12 : 0.04), .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .snowy:
            LinearGradient(
                colors: [.white.opacity(0.09), .cyan.opacity(0.04), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        case .foggy:
            LinearGradient(
                colors: [.clear, .white.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cozy:
            RadialGradient(
                colors: [.orange.opacity(0.07), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 90
            )
        }
    }
}

struct PetWeatherAccent: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        if kind == .pauli {
            let reaction = WeatherAnimationProfile.reaction(for: kind, mood: mood)
            let pulsing = !reduceMotion && (reaction == .antennaGlow || reaction == .visorGlow)
            let stormPhase = time.truncatingRemainder(dividingBy: 22)
            let stormOpacity = stormPhase < 0.08 ? 0.48 : 0.20
            let opacity = if mood == .stormy {
                stormOpacity
            } else if pulsing {
                0.28 + abs(sin(time * 1.4)) * 0.20
            } else {
                0.28
            }

            if reaction == .antennaGlow {
                Circle()
                    .fill((mood == .sunny ? Color.yellow : Color.cyan).opacity(opacity))
                    .frame(width: 13, height: 13)
                    .blur(radius: 5)
                    .offset(y: -68)
            } else if reaction == .visorGlow {
                Capsule()
                    .fill(Color.cyan.opacity(opacity * 0.55))
                    .frame(width: 62, height: 34)
                    .blur(radius: 8)
                    .offset(y: -13)
            }
        }
    }
}
```

Wrap the existing realistic `Image` in a `ZStack`. Apply `PetWeatherArtworkLight` as an overlay masked by the same resized artwork, and place `PetWeatherAccent` above it:

```swift
ZStack {
    Image(nsImage: artwork)
        .resizable()
        .interpolation(.high)
        .aspectRatio(contentMode: .fit)
        .frame(width: 166, height: 170)
        .overlay {
            PetWeatherArtworkLight(
                kind: kind,
                mood: mood,
                time: time,
                reduceMotion: reduceMotion
            )
            .mask {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }

    PetWeatherAccent(
        kind: kind,
        mood: mood,
        time: time,
        reduceMotion: reduceMotion
    )
}
.frame(width: 166, height: 170)
```

Keep the existing scale, rotation, offset, and shadow on this outer `ZStack`.

- [ ] **Step 5: Add the same reaction priority and transforms to vector fallback**

Add the same short-lived pat state used by `RealisticPetBody`:

```swift
@State private var isShowingPat = false
@State private var patTask: Task<Void, Never>?
```

Attach this to the outer `TimelineView` result:

```swift
.onChange(of: pulse) {
    patTask?.cancel()
    isShowingPat = true
    patTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        isShowingPat = false
    }
}
.onDisappear {
    patTask?.cancel()
}
```

Inside the `VectorPetBody` timeline, derive:

```swift
let weatherReaction = WeatherAnimationProfile.reaction(for: kind, mood: mood)
let allowsWeatherReaction = !reduceMotion
    && !isSleeping
    && !isDancing
    && personalityPose == nil
    && !isHovering
    && !isShowingPat
let weatherIdleMultiplier: Double = if allowsWeatherReaction {
    switch mood {
    case .cloudy: 0.68
    case .snowy: 0.76
    case .sunny, .foggy, .rainy, .stormy, .cozy: 1
    }
} else {
    1
}
let weatherTilt: Double = if allowsWeatherReaction {
    switch weatherReaction {
    case .observe: sin(t * 0.55) * 1.2
    case .shake:
        t.truncatingRemainder(dividingBy: 16) < 1.2 ? sin(t * 18) * 2.0 : 0
    case .startle:
        t.truncatingRemainder(dividingBy: 22) < 0.8 ? sin(t * 8) * 1.5 : 0
    case .none, .settle, .headLift, .shelter, .antennaGlow, .visorGlow, .sniff: 0
    }
} else {
    0
}
let weatherLift: Double = if allowsWeatherReaction {
    switch weatherReaction {
    case .headLift, .sniff: sin(t * 0.55) * -1.0
    case .shelter: 1.0
    case .none, .settle, .observe, .antennaGlow, .visorGlow, .shake, .startle: 0
    }
} else {
    0
}
```

Multiply the existing non-sleep idle bob by `weatherIdleMultiplier`, add `weatherLift` to `bob`, and add `weatherTilt` to the final rotation. Keep all Reduce Motion gates from the realistic redesign.

- [ ] **Step 6: Build, test, and inspect reaction priority**

Run:

```bash
swift test
swift build
rg -n "presentationState|allowsWeatherReaction|reduceMotion|isSleeping|isDancing|personalityPose|isHovering" Sources/DeskPetMac/RealisticPetBody.swift Sources/DeskPetMac/PetWindowView.swift
git diff --check
```

Expected: tests/build pass; the source shows weather gated below sleep/dance/personality/pat/hover and Reduce Motion.

### Task 5: Document Integrated Weather and Add Runtime Preview Checks

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace stale feature wording**

Replace the weather-accessory feature bullet with:

```markdown
- **Integrated weather / 融合天气动画** — sunlight, cloud shadow, fog, rain, snow, and restrained lightning animate around the pet, with subtle Cat, Pauli, and Dog reactions instead of a weather label.
```

Keep the Open-Meteo fallback bullet. Do not add forecast or provider claims.

- [ ] **Step 2: Document the debug preview command under Verify**

Add:

````markdown
Preview a weather mood in a debug build:

```bash
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
```

Supported preview values: `sunny`, `cloudy`, `foggy`, `rainy`, `snowy`, `stormy`, and `cozy`.
````

- [ ] **Step 3: Check documentation and source consistency**

Run:

```bash
rg -n "weather accessories|weather label|DESKPET_WEATHER_PREVIEW|Integrated weather" README.md Sources
git diff --check
```

Expected: README describes integrated animation and the debug override; no stale weather-accessory claim remains.

### Task 6: Full Automated and Real-Window Verification

**Files:**
- No source changes expected unless verification exposes a defect.

- [ ] **Step 1: Run strict scoped formatter diagnostics**

Run:

```bash
swift format lint --strict Sources/DeskPetCore/WeatherAnimationProfile.swift Sources/DeskPetMac/WeatherAtmosphere.swift Sources/DeskPetMac/RealisticPetBody.swift Sources/DeskPetMac/PetWindowView.swift Tests/DeskPetCoreTests/DeskPetCoreTests.swift
git diff --check
```

Expected: report the repository's existing four-space indentation mismatch without bulk-formatting unrelated code; fix diagnostics introduced specifically by new lines where doing so does not reformat existing files.

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
- Packaged resource count is exactly `27`.
- Codesign reports `valid on disk` and satisfies its designated requirement.

- [ ] **Step 3: Inspect all 21 pet/weather combinations**

For each mood, launch the debug app with `DESKPET_WEATHER_PREVIEW=<mood>` and switch among Cat, Pauli, and Dog using `Cmd+1`, `Cmd+2`, and `Cmd+3`:

```bash
DESKPET_WEATHER_PREVIEW=sunny swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=cloudy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=foggy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=snowy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=stormy swift run DeskPetMac
DESKPET_WEATHER_PREVIEW=cozy swift run DeskPetMac
```

For every mood, verify at normal Retina scale:

- The weather is recognizable without text.
- Cat, Pauli, and Dog stay fully inside the `220 x 250` window.
- Faces, control strip, status bubble, personality bubble, reminder bubble, and heart particles remain readable.
- Rain/snow/fog do not block pat or hover.
- No new green fringe or full-artwork recoloring appears.
- Character reactions are present but lower priority than sleep, pat, dance, hover, and personality poses.

- [ ] **Step 4: Verify Reduce Motion**

Enable macOS Reduce Motion and repeat `rainy`, `snowy`, `foggy`, and `stormy` previews.

Expected:

- No precipitation, fog, cloud shadow, character displacement, or lightning moves continuously.
- Static low-opacity weather cues remain visible.
- Blink and permitted subtle state feedback continue.

- [ ] **Step 5: Recheck artwork fallback with weather**

In a temporary copy of the packaged app, move one Dog base file out of the resource bundle, ad-hoc sign the temporary copy, launch it in `rainy`, and verify `VectorDogBody` plus rainy atmosphere appears. Restore the file afterward. Do not modify the source resource directory or final packaged app.

Expected: the app remains usable, the vector Dog is visible, and weather layers remain non-interactive.

- [ ] **Step 6: Review final scope and restart the final app**

Run:

```bash
git status --short
git diff --stat
git diff -- Sources/DeskPetCore Sources/DeskPetMac Tests README.md
open .build/release/DeskPetMac.app
```

Confirm only the approved integrated-weather feature, its tests, documentation, and the already-approved realistic redesign are present. Do not commit or push unless the user explicitly asks.
