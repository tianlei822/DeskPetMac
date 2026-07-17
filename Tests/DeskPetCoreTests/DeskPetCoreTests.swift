import Testing
import Foundation
@testable import DeskPetCore

@Suite("Weather mood mapping")
struct WeatherMoodMappingTests {
    @Test("maps Open-Meteo weather codes into pet moods")
    func mapsWeatherCodes() {
        #expect(PetWeatherMood(openMeteoCode: 0) == .sunny)
        #expect(PetWeatherMood(openMeteoCode: 3) == .cloudy)
        #expect(PetWeatherMood(openMeteoCode: 45) == .foggy)
        #expect(PetWeatherMood(openMeteoCode: 61) == .rainy)
        #expect(PetWeatherMood(openMeteoCode: 80) == .rainy)
        #expect(PetWeatherMood(openMeteoCode: 71) == .snowy)
        #expect(PetWeatherMood(openMeteoCode: 95) == .stormy)
        #expect(PetWeatherMood(openMeteoCode: 999) == .cozy)
    }

    @Test("unknown weather snapshot stays gentle")
    func unknownWeatherStaysGentle() {
        let snapshot = WeatherSnapshot(conditionCode: nil, temperatureCelsius: nil, locationName: "Local")
        #expect(snapshot.mood == .cozy)
        #expect(snapshot.temperatureLabel == "--")
    }
}

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

    @Test("Reduce Motion uses sparse static particles without ground feedback")
    func reduceMotionUsesSparseStaticParticles() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherSceneProfile(mood: mood)
            let reducedProfiles = WeatherDepth.allCases.map {
                profile.particleProfile(for: $0, reduceMotion: true)
            }

            #expect(reducedProfiles.reduce(0) { $0 + $1.count } <= 3)
            #expect(reducedProfiles.allSatisfy { $0.speed == 0 })
            #expect(reducedProfiles.allSatisfy { $0.opacity.upperBound <= 0.28 })
            #expect(!profile.showsGroundFeedback(reduceMotion: true))
            #expect(
                profile.showsGroundFeedback(reduceMotion: false)
                    == (profile.showsSplashes || profile.showsSnowGroundLight)
            )
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

    @Test("non-finite animation inputs fall back to the static state")
    func nonFiniteInputsFallBackToStaticState() {
        let particle = WeatherParticleLayout.particles(count: 1, seed: 29, depth: .foreground)[0]
        let expected = particle.state(at: 0, speed: 0, wind: 0, moving: false)
        let inputs = [
            (time: Double.nan, speed: 0.64, wind: -0.22),
            (time: Double.infinity, speed: 0.64, wind: -0.22),
            (time: -Double.infinity, speed: 0.64, wind: -0.22),
            (time: 1.0, speed: Double.nan, wind: -0.22),
            (time: 1.0, speed: Double.infinity, wind: -0.22),
            (time: 1.0, speed: -Double.infinity, wind: -0.22),
            (time: 1.0, speed: 0.64, wind: Double.nan),
            (time: 1.0, speed: 0.64, wind: Double.infinity),
            (time: 1.0, speed: 0.64, wind: -Double.infinity)
        ]

        for input in inputs {
            let first = particle.state(
                at: input.time,
                speed: input.speed,
                wind: input.wind,
                moving: true
            )
            let second = particle.state(
                at: input.time,
                speed: input.speed,
                wind: input.wind,
                moving: true
            )

            #expect(first == expected)
            #expect(first == second)
            #expect(first.x.isFinite)
            #expect(first.y.isFinite)
            #expect((0...1).contains(first.x))
            #expect((0...1).contains(first.y))
        }
    }

    @Test("greatest finite inputs remain deterministic and normalized")
    func greatestFiniteInputsStaySafe() {
        let particle = WeatherParticleLayout.particles(count: 1, seed: 31, depth: .background)[0]
        let inputs = [
            (time: Double.greatestFiniteMagnitude, speed: 0.35, wind: -0.22),
            (time: -Double.greatestFiniteMagnitude, speed: 0.35, wind: 0.22),
            (time: 1.0, speed: Double.greatestFiniteMagnitude, wind: -0.22),
            (time: 1.0, speed: -Double.greatestFiniteMagnitude, wind: 0.22),
            (time: 1.0, speed: 0.64, wind: Double.greatestFiniteMagnitude),
            (time: 1.0, speed: 0.64, wind: -Double.greatestFiniteMagnitude)
        ]

        for input in inputs {
            let first = particle.state(
                at: input.time,
                speed: input.speed,
                wind: input.wind,
                moving: true
            )
            let second = particle.state(
                at: input.time,
                speed: input.speed,
                wind: input.wind,
                moving: true
            )

            #expect(first == second)
            #expect(first.x.isFinite)
            #expect(first.y.isFinite)
            #expect((0...1).contains(first.x))
            #expect((0...1).contains(first.y))
        }
    }

    @Test("finite multiplication overflow falls back to the static state")
    func finiteMultiplicationOverflowFallsBack() {
        let particle = WeatherParticleLayout.particles(count: 1, seed: 37, depth: .midground)[0]
        let expected = particle.state(at: 0, speed: 0, wind: 0, moving: false)
        let inputs = [
            (time: Double.greatestFiniteMagnitude, speed: 2.0),
            (time: Double.greatestFiniteMagnitude, speed: -2.0),
            (time: -Double.greatestFiniteMagnitude, speed: 2.0),
            (time: -Double.greatestFiniteMagnitude, speed: -2.0)
        ]

        for input in inputs {
            let first = particle.state(
                at: input.time,
                speed: input.speed,
                wind: -0.22,
                moving: true
            )
            let second = particle.state(
                at: input.time,
                speed: input.speed,
                wind: -0.22,
                moving: true
            )

            #expect(first == expected)
            #expect(first == second)
            #expect(first.x.isFinite)
            #expect(first.y.isFinite)
            #expect((0...1).contains(first.x))
            #expect((0...1).contains(first.y))
        }
    }
}

@Suite("Break reminders")
struct BreakReminderPolicyTests {
    @Test("default reminder interval is sixty minutes")
    func defaultReminderIntervalIsSixtyMinutes() {
        let policy = BreakReminderPolicy()

        #expect(policy.reminderInterval == 60 * 60)
    }

    @Test("does not remind before the interval")
    func quietBeforeInterval() {
        let policy = BreakReminderPolicy(reminderInterval: 45 * 60, snoozeInterval: 10 * 60)
        let state = BreakReminderState(activeSeconds: 44 * 60, lastReminderAt: nil, snoozedUntil: nil)

        #expect(policy.shouldRemind(state: state, now: Date(timeIntervalSince1970: 1_000)) == false)
    }

    @Test("reminds when active work crosses the interval")
    func remindsAtInterval() {
        let policy = BreakReminderPolicy(reminderInterval: 45 * 60, snoozeInterval: 10 * 60)
        let state = BreakReminderState(activeSeconds: 45 * 60, lastReminderAt: nil, snoozedUntil: nil)

        #expect(policy.shouldRemind(state: state, now: Date(timeIntervalSince1970: 1_000)) == true)
    }

    @Test("snooze suppresses reminders until its expiry")
    func snoozeSuppressesReminder() {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = BreakReminderPolicy(reminderInterval: 45 * 60, snoozeInterval: 10 * 60)
        let state = BreakReminderState(
            activeSeconds: 60 * 60,
            lastReminderAt: now.addingTimeInterval(-10 * 60),
            snoozedUntil: now.addingTimeInterval(60)
        )

        #expect(policy.shouldRemind(state: state, now: now) == false)
        #expect(policy.shouldRemind(state: state, now: now.addingTimeInterval(61)) == true)
    }

    @Test("taking a break resets active time")
    func takingBreakResetsActiveTime() {
        let policy = BreakReminderPolicy(reminderInterval: 45 * 60, snoozeInterval: 10 * 60)
        let now = Date(timeIntervalSince1970: 1_000)
        let state = BreakReminderState(activeSeconds: 50 * 60, lastReminderAt: now, snoozedUntil: nil)

        let rested = policy.markBreakTaken(state: state)

        #expect(rested.activeSeconds == 0)
        #expect(rested.lastReminderAt == nil)
        #expect(rested.snoozedUntil == nil)
    }
}

@Suite("Work session tracking")
struct WorkSessionTrackerTests {
    @Test("counts active time when the user is not idle")
    func countsActiveTime() {
        let tracker = WorkSessionTracker(activeIdleThreshold: 300, maxObservationInterval: 90)
        let start = Date(timeIntervalSince1970: 1_000)
        let next = start.addingTimeInterval(120)
        let initial = WorkSessionState(activeSeconds: 0, lastObservedAt: start)

        let updated = tracker.recordObservation(previous: initial, now: next, idleSeconds: 20)

        #expect(updated.activeSeconds == 90)
        #expect(updated.lastObservedAt == next)
    }

    @Test("does not count time while idle")
    func ignoresIdleTime() {
        let tracker = WorkSessionTracker(activeIdleThreshold: 300, maxObservationInterval: 90)
        let start = Date(timeIntervalSince1970: 1_000)
        let next = start.addingTimeInterval(60)
        let initial = WorkSessionState(activeSeconds: 120, lastObservedAt: start)

        let updated = tracker.recordObservation(previous: initial, now: next, idleSeconds: 600)

        #expect(updated.activeSeconds == 120)
    }
}

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

@Suite("Pet artwork manifest")
struct PetArtworkManifestTests {
    @Test("each pet has stable artwork filenames for every presentation state")
    func everyPetHasStableArtworkNames() {
        let fixtures: [(
            petKind: PetKind,
            base: String,
            blink: String,
            hover: String,
            pat: String,
            sleep: String,
            peek: String,
            perk: String,
            stretch: String,
            proud: String
        )] = [
            (
                .cat,
                "Pets/Cat/base",
                "Pets/Cat/blink",
                "Pets/Cat/hover",
                "Pets/Cat/pat",
                "Pets/Cat/sleep",
                "Pets/Cat/peek",
                "Pets/Cat/perk",
                "Pets/Cat/stretch",
                "Pets/Cat/proud"
            ),
            (
                .pauli,
                "Pets/Pauli/base",
                "Pets/Pauli/blink",
                "Pets/Pauli/hover",
                "Pets/Pauli/pat",
                "Pets/Pauli/sleep",
                "Pets/Pauli/peek",
                "Pets/Pauli/perk",
                "Pets/Pauli/stretch",
                "Pets/Pauli/proud"
            ),
            (
                .dog,
                "Pets/Dog/base",
                "Pets/Dog/blink",
                "Pets/Dog/hover",
                "Pets/Dog/pat",
                "Pets/Dog/sleep",
                "Pets/Dog/peek",
                "Pets/Dog/perk",
                "Pets/Dog/stretch",
                "Pets/Dog/proud"
            )
        ]

        for fixture in fixtures {
            let manifest = PetArtworkManifest(petKind: fixture.petKind)

            #expect(manifest.base == fixture.base)
            #expect(manifest.blink == fixture.blink)
            #expect(manifest.hover == fixture.hover)
            #expect(manifest.pat == fixture.pat)
            #expect(manifest.sleep == fixture.sleep)
            #expect(manifest.personality[.peek] == fixture.peek)
            #expect(manifest.personality[.perk] == fixture.perk)
            #expect(manifest.personality[.stretch] == fixture.stretch)
            #expect(manifest.personality[.proud] == fixture.proud)

            #expect(manifest.resourceName(for: .idle) == fixture.base)
            #expect(manifest.resourceName(for: .blink) == fixture.blink)
            #expect(manifest.resourceName(for: .hover) == fixture.hover)
            #expect(manifest.resourceName(for: .pat) == fixture.pat)
            #expect(manifest.resourceName(for: .sleep) == fixture.sleep)
            #expect(manifest.resourceName(for: .personality(.peek)) == fixture.peek)
            #expect(manifest.resourceName(for: .personality(.perk)) == fixture.perk)
            #expect(manifest.resourceName(for: .personality(.stretch)) == fixture.stretch)
            #expect(manifest.resourceName(for: .personality(.proud)) == fixture.proud)
        }
    }

    @Test("dog manifest exposes the base fallback resource name")
    func dogManifestExposesBaseFallback() {
        let manifest = PetArtworkManifest(petKind: .dog)
        #expect(manifest.resourceName(for: .idle) == "Pets/Dog/base")
        #expect(manifest.resourceName(for: .personality(.perk)) == "Pets/Dog/perk")
        #expect(manifest.fallbackResourceName == "Pets/Dog/base")
    }

    @Test("each pet exposes a complete set of motion artwork names")
    func everyPetHasCompleteMotionArtworkNames() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)

            #expect(manifest.walk.count == 6)
            #expect(manifest.idleActions.count == 2)
            #expect(manifest.walk.first?.hasSuffix("/walk1") == true)
            #expect(manifest.walk.last?.hasSuffix("/walk6") == true)
            #expect(manifest.idleActions.first?.hasSuffix("/idleAction1") == true)
            #expect(manifest.idleActions.last?.hasSuffix("/idleAction2") == true)
            #expect(manifest.motionResourceNames.count == 8)
        }
    }

    @Test("motion artwork validation rejects partial resource sets")
    func motionArtworkValidationRejectsPartialSets() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let completeResources = Set(manifest.motionResourceNames)
            let partialResources = Set(manifest.motionResourceNames.dropLast())

            #expect(manifest.hasCompleteMotionSet(
                availableResourceNames: completeResources
            ))
            #expect(!manifest.hasCompleteMotionSet(
                availableResourceNames: partialResources
            ))
        }
    }

    @Test("dog motion events map to exact artwork resources")
    func dogMotionEventsMapToExactArtworkResources() {
        let manifest = PetArtworkManifest(petKind: .dog)

        #expect(manifest.resourceName(
            for: PetMotionEvent.idle,
            frameIndex: nil
        ) == "Pets/Dog/base")
        #expect(manifest.resourceName(
            for: PetMotionEvent.walk,
            frameIndex: 0
        ) == "Pets/Dog/walk1")
        #expect(manifest.resourceName(
            for: PetMotionEvent.walk,
            frameIndex: 5
        ) == "Pets/Dog/walk6")
        #expect(manifest.resourceName(
            for: PetMotionEvent.idleAction1,
            frameIndex: nil
        ) == "Pets/Dog/idleAction1")
        #expect(manifest.resourceName(
            for: PetMotionEvent.idleAction2,
            frameIndex: nil
        ) == "Pets/Dog/idleAction2")
    }

    @Test("invalid walk frame indexes use the base artwork")
    func invalidWalkFrameIndexesUseBaseArtwork() {
        let manifest = PetArtworkManifest(petKind: .dog)

        #expect(manifest.resourceName(
            for: PetMotionEvent.walk,
            frameIndex: nil
        ) == "Pets/Dog/base")
        #expect(manifest.resourceName(
            for: PetMotionEvent.walk,
            frameIndex: -1
        ) == "Pets/Dog/base")
        #expect(manifest.resourceName(
            for: PetMotionEvent.walk,
            frameIndex: 6
        ) == "Pets/Dog/base")
    }
}

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
            var foundWalk = false

            for second in stride(from: 0.0, through: 240.0, by: 0.05) {
                let frame = PetMotionDirector.frame(
                    pet: pet,
                    time: second,
                    seed: 31,
                    isEligible: true,
                    reduceMotion: false
                )

                switch frame.event {
                case .walk:
                    foundWalk = true
                    #expect((2...4).contains(frame.stepCount))
                    #expect(frame.artworkFrameIndex != nil)
                    #expect((0...5).contains(frame.artworkFrameIndex ?? -1))
                    #expect(frame.eventProgress >= 0)
                    #expect(frame.eventProgress < 1)
                    expectFiniteTransforms(frame)
                case .idleAction1, .idleAction2:
                    #expect(frame.artworkFrameIndex == nil)
                    #expect(frame.stepCount == 0)
                    #expect(frame.eventProgress >= 0)
                    #expect(frame.eventProgress < 1)
                    #expect(abs(frame.horizontalOffset) <= 1.5)
                    #expect(frame.verticalOffset >= -1.1)
                    #expect(frame.verticalOffset <= 0)
                    #expect(abs(frame.tiltDegrees) <= 2)
                    #expect(frame.shadowScale >= 0.965)
                    #expect(frame.shadowScale <= 1)
                    #expect(abs(frame.shadowOffset) <= 0.8)
                    expectFiniteTransforms(frame)
                case .idle:
                    break
                }
            }

            #expect(foundWalk)
        }
    }

    @Test("walks return lateral motion to neutral at completion")
    func walksReturnToNeutral() {
        var samples: [Int: (
            seed: Int,
            eventStart: Double,
            cadence: PetMotionCadence
        )] = [:]

        for seed in 0...200 where samples.count < 3 {
            let cadence = PetMotionDirector.cadence(for: .cat, seed: seed)
            let eventStart = cadence.idleDuration
            let frame = PetMotionDirector.frame(
                pet: .cat,
                time: eventStart,
                seed: seed,
                isEligible: true,
                reduceMotion: false
            )

            if frame.event == .walk, samples[frame.stepCount] == nil {
                samples[frame.stepCount] = (seed, eventStart, cadence)
            }
        }

        #expect(samples.count == 3)
        for stepCount in 2...4 {
            guard let sample = samples[stepCount] else { continue }
            let duration = Double(stepCount) / sample.cadence.stepsPerSecond
            let start = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )
            let justBeforeCompletion = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart + duration - 0.000_001,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )
            let atCompletion = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart + duration,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )

            #expect(start.horizontalOffset == 0)
            #expect(justBeforeCompletion.event == .walk)
            #expect(abs(justBeforeCompletion.horizontalOffset) < 0.001)
            #expect(atCompletion == .idle)
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

    @Test("each pet advances artwork between six and ten frames per second")
    func artworkFrameRatesStayReadable() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            #expect(cadence.artworkFramesPerSecond >= 6)
            #expect(cadence.artworkFramesPerSecond <= 10)

            for expectedIndex in 0...5 {
                let frame = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: .walk,
                    time: (Double(expectedIndex) + 0.25)
                        / cadence.artworkFramesPerSecond,
                    reduceMotion: false
                )
                #expect(frame.artworkFrameIndex == expectedIndex)
            }
        }
    }

    @Test("every production step count holds a neutral walk-six landing frame")
    func productionWalksSettleBeforeReturningToIdle() {
        var samples: [Int: (
            seed: Int,
            eventStart: Double,
            cadence: PetMotionCadence
        )] = [:]

        for seed in 0...200 where samples.count < 3 {
            let cadence = PetMotionDirector.cadence(for: .cat, seed: seed)
            let eventStart = cadence.idleDuration
            let frame = PetMotionDirector.frame(
                pet: .cat,
                time: eventStart,
                seed: seed,
                isEligible: true,
                reduceMotion: false
            )
            if frame.event == .walk, samples[frame.stepCount] == nil {
                samples[frame.stepCount] = (seed, eventStart, cadence)
            }
        }

        #expect(samples.count == 3)
        for stepCount in 2...4 {
            guard let sample = samples[stepCount] else { continue }
            let duration = Double(stepCount) / sample.cadence.stepsPerSecond
            let precedingFrame = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart
                    + duration
                    - 1.5 / sample.cadence.artworkFramesPerSecond,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )
            let settlingFrame = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart
                    + duration
                    - 0.5 / sample.cadence.artworkFramesPerSecond,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )
            let atCompletion = PetMotionDirector.frame(
                pet: .cat,
                time: sample.eventStart + duration,
                seed: sample.seed,
                isEligible: true,
                reduceMotion: false
            )

            #expect(precedingFrame.event == .walk)
            #expect(precedingFrame.artworkFrameIndex == 4)
            #expect(settlingFrame.event == .walk)
            #expect(settlingFrame.artworkFrameIndex == 5)
            #expect(abs(settlingFrame.horizontalOffset) < 0.000_000_001)
            #expect(abs(settlingFrame.verticalOffset) < 0.000_000_001)
            #expect(abs(settlingFrame.tiltDegrees) < 0.000_000_001)
            #expect(abs(settlingFrame.shadowScale - 1) < 0.000_000_001)
            #expect(abs(settlingFrame.shadowOffset) < 0.000_000_001)
            #expect(atCompletion == .idle)
        }
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

    @Test("walk preview loops through all six finite gait frames")
    func walkPreviewLoopsThroughAllGaitFrames() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            let duration = 4 / cadence.stepsPerSecond
            var artworkFrames = Set<Int>()

            for slot in 0..<(4 * 6) {
                let time = (Double(slot) + 0.5)
                    / cadence.artworkFramesPerSecond
                let frame = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: .walk,
                    time: time,
                    reduceMotion: false
                )
                artworkFrames.insert(frame.artworkFrameIndex ?? -1)

                #expect(frame.event == .walk)
                #expect(frame.stepCount == 4)
                #expect(frame.eventProgress >= 0)
                #expect(frame.eventProgress < 1)
                expectFiniteTransforms(frame)
            }

            #expect(artworkFrames == Set(0...5))

            let first = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: duration * 0.37,
                reduceMotion: false
            )
            let looped = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: duration * 1.37,
                reduceMotion: false
            )
            expectEquivalentMotion(first, looped)
        }
    }

    @Test("micro-action previews loop with their requested artwork")
    func microActionPreviewsLoop() {
        for pet in PetKind.allCases {
            for event in [PetMotionEvent.idleAction1, .idleAction2] {
                let first = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: 0.8,
                    reduceMotion: false
                )
                let looped = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: 2.4,
                    reduceMotion: false
                )

                #expect(first.event == event)
                #expect(first.artworkFrameIndex == nil)
                #expect(first.stepCount == 0)
                #expect(abs(first.horizontalOffset) > 0)
                #expect(first.verticalOffset < 0)
                expectFiniteTransforms(first)
                expectEquivalentMotion(first, looped)
            }
        }
    }

    @Test("Reduce Motion keeps every preview event idle")
    func reducedPreviewMotionIsIdle() {
        for pet in PetKind.allCases {
            for event in PetMotionEvent.allCases {
                #expect(PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: 0.8,
                    reduceMotion: true
                ) == .idle)
            }
        }
    }

    @Test("motion clock restarts from neutral after an interruption")
    func motionClockRestartsAfterInterruption() {
        let pet = PetKind.dog
        let seed = 31
        let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
        var clock = PetMotionScheduleClock()

        clock.updateEligibility(true, at: 100)
        #expect(clock.origin == 100)
        #expect(clock.elapsed(at: 99) == 0)

        let underwayTime = 100 + cadence.idleDuration + 0.2
        clock.updateEligibility(true, at: underwayTime)
        let underway = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: underwayTime),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(clock.origin == 100)
        #expect(underway.event != .idle)

        clock.updateEligibility(false, at: underwayTime)
        let suppressed = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: underwayTime),
            seed: seed,
            isEligible: false,
            reduceMotion: false
        )
        #expect(clock.origin == nil)
        #expect(suppressed == .idle)

        let resumedTime = underwayTime + 5
        clock.updateEligibility(true, at: resumedTime)
        let restarted = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: resumedTime),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(clock.origin == resumedTime)
        #expect(clock.elapsed(at: resumedTime) == 0)
        #expect(restarted == .idle)
    }

    @Test("strong weather interrupts only during its active envelope")
    func strongWeatherInterruptionEnvelopesStayBounded() {
        #expect(PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: 0
        ))
        #expect(PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: 1.279_999
        ))
        #expect(!PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: 1.280_001
        ))
        #expect(PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: 16
        ))

        #expect(PetMotionDirector.isStrongWeatherReactionActive(
            .startle,
            time: 1.099_999
        ))
        #expect(!PetMotionDirector.isStrongWeatherReactionActive(
            .startle,
            time: 1.100_001
        ))
        #expect(!PetMotionDirector.isStrongWeatherReactionActive(
            .settle,
            time: 0
        ))
        #expect(!PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: .nan
        ))
    }

    @Test("idle wait survives a weather burst without starving dog motion")
    func idleWaitSurvivesWeatherBurst() {
        let pet = PetKind.dog
        let seed = 4_093
        let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
        var clock = PetMotionScheduleClock()

        #expect(cadence.idleDuration == 15)
        let firstBurstEnd = 1.28
        clock.updateEligibility(true, at: firstBurstEnd)

        let nextBurstStart = 16.0
        let candidate = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: nextBurstStart),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(candidate == .idle)
        #expect(abs(clock.elapsed(at: nextBurstStart) - 14.72) < 0.000_000_001)
        #expect(PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: nextBurstStart
        ))
        clock.suspendForWeather(
            at: nextBurstStart,
            preservingElapsed: candidate == .idle
        )

        let nextBurstEnd = 17.280_001
        #expect(!PetMotionDirector.isStrongWeatherReactionActive(
            .shake,
            time: nextBurstEnd
        ))
        #expect(abs(clock.elapsed(at: nextBurstEnd) - 14.72) < 0.000_000_001)
        clock.resumeAfterWeather(at: nextBurstEnd)

        let actionTime = nextBurstEnd + 0.29
        let action = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: actionTime),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(action.event != .idle)
        #expect(actionTime < 32)
    }

    @Test("weather-interrupted action restarts from neutral")
    func weatherInterruptedActionRestartsFromNeutral() {
        let pet = PetKind.dog
        let seed = 4_093
        let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
        let interruptionTime = 16.0
        var clock = PetMotionScheduleClock(
            origin: interruptionTime - cadence.idleDuration - 0.2
        )

        let underway = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: interruptionTime),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(underway.event != .idle)

        clock.suspendForWeather(
            at: interruptionTime,
            preservingElapsed: underway == .idle
        )
        #expect(clock.elapsed(at: interruptionTime + 1) == 0)

        let resumedTime = 17.280_001
        clock.resumeAfterWeather(at: resumedTime)
        let restarted = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: resumedTime),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(clock.elapsed(at: resumedTime) == 0)
        #expect(restarted == .idle)
    }

    @Test("normal ineligibility clears a preserved weather pause")
    func normalIneligibilityClearsWeatherPause() {
        var clock = PetMotionScheduleClock(origin: 0)

        clock.suspendForWeather(at: 5, preservingElapsed: true)
        #expect(clock.elapsed(at: 6) == 5)

        clock.updateEligibility(false, at: 6)
        clock.updateEligibility(true, at: 10)
        #expect(clock.origin == 10)
        #expect(clock.elapsed(at: 10) == 0)
    }

    @Test("idle event and cycle boundaries stay exact for positive and negative time")
    func motionBoundariesStayExact() {
        let pet = PetKind.dog
        let seed = 31
        let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
        let cycleDuration = cadence.idleDuration + 3.2

        let beforeEvent = PetMotionDirector.frame(
            pet: pet,
            time: cadence.idleDuration.nextDown,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        let atEvent = PetMotionDirector.frame(
            pet: pet,
            time: cadence.idleDuration,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        let beforeCycleEnd = PetMotionDirector.frame(
            pet: pet,
            time: cycleDuration.nextDown,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        let atCycleStart = PetMotionDirector.frame(
            pet: pet,
            time: cycleDuration,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        let negativeEventStart = PetMotionDirector.frame(
            pet: pet,
            time: -cycleDuration + cadence.idleDuration,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        let negativeCycleStart = PetMotionDirector.frame(
            pet: pet,
            time: -cycleDuration,
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )

        #expect(beforeEvent == .idle)
        #expect(atEvent.event != .idle)
        #expect(atEvent.eventProgress == 0)
        #expect(beforeCycleEnd == .idle)
        #expect(atCycleStart == .idle)
        #expect(negativeEventStart.event != .idle)
        #expect(abs(negativeEventStart.eventProgress) < 0.000_000_001)
        #expect(negativeCycleStart == .idle)
        expectFiniteTransforms(negativeEventStart)
    }

    @Test("non-finite time forces stable idle")
    func nonFiniteTimeIsIdle() {
        for time in [Double.nan, Double.infinity, -Double.infinity] {
            #expect(PetMotionDirector.frame(
                pet: .cat,
                time: time,
                seed: 17,
                isEligible: true,
                reduceMotion: false
            ) == .idle)
        }
    }

    @Test("huge finite times return deterministic valid frames")
    func hugeFiniteTimesStaySafe() {
        let pet = PetKind.pauli
        let seed = 17
        let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
        let cycleDuration = cadence.idleDuration + 3.2
        let magnitude = Double(Int.max) * 4 * cycleDuration
        let positiveTime = extremeEventTime(
            startingAt: magnitude,
            movingPositive: true,
            cadence: cadence
        )
        let negativeTime = extremeEventTime(
            startingAt: -magnitude,
            movingPositive: false,
            cadence: cadence
        )

        #expect(positiveTime != nil)
        #expect(negativeTime != nil)
        for time in [positiveTime, negativeTime].compactMap({ $0 }) {
            let first = PetMotionDirector.frame(
                pet: pet,
                time: time,
                seed: seed,
                isEligible: true,
                reduceMotion: false
            )
            let second = PetMotionDirector.frame(
                pet: pet,
                time: time,
                seed: seed,
                isEligible: true,
                reduceMotion: false
            )

            #expect(first == second)
            #expect(first.eventProgress >= 0)
            #expect(first.eventProgress < 1)
            expectFiniteTransforms(first)
        }
    }

    private func expectFiniteTransforms(_ frame: PetMotionFrame) {
        let values = [
            frame.eventProgress,
            frame.horizontalOffset,
            frame.verticalOffset,
            frame.tiltDegrees,
            frame.shadowScale,
            frame.shadowOffset
        ]
        let allFinite = values.allSatisfy { $0.isFinite }
        #expect(allFinite)
    }

    private func expectEquivalentMotion(
        _ first: PetMotionFrame,
        _ second: PetMotionFrame
    ) {
        #expect(first.event == second.event)
        #expect(first.artworkFrameIndex == second.artworkFrameIndex)
        #expect(first.stepCount == second.stepCount)
        #expect(abs(first.eventProgress - second.eventProgress) < 0.000_000_001)
        #expect(abs(first.horizontalOffset - second.horizontalOffset) < 0.000_000_001)
        #expect(abs(first.verticalOffset - second.verticalOffset) < 0.000_000_001)
        #expect(abs(first.tiltDegrees - second.tiltDegrees) < 0.000_000_001)
        #expect(abs(first.shadowScale - second.shadowScale) < 0.000_000_001)
        #expect(abs(first.shadowOffset - second.shadowOffset) < 0.000_000_001)
    }

    private func extremeEventTime(
        startingAt initialValue: Double,
        movingPositive: Bool,
        cadence: PetMotionCadence
    ) -> Double? {
        let cycleDuration = cadence.idleDuration + 3.2
        var candidate = initialValue

        for _ in 0..<4_096 {
            let remainder = candidate.truncatingRemainder(dividingBy: cycleDuration)
            let normalizedTime = remainder >= 0 ? remainder : remainder + cycleDuration
            if normalizedTime >= cadence.idleDuration {
                return candidate
            }
            candidate = movingPositive ? candidate.nextUp : candidate.nextDown
        }

        return nil
    }
}

@Suite("Pet bond")
struct PetBondTests {
    @Test("a fresh bond starts as a new friend")
    func freshBondIsNewFriend() {
        let bond = PetBond()

        #expect(bond.points == 0)
        #expect(bond.totalPats == 0)
        #expect(bond.level == .newFriend)
        #expect(bond.level.hearts == 1)
    }

    @Test("pats add affection and count toward the total")
    func patsAddAffection() {
        var bond = PetBond()

        bond.registerPat(comboMultiplier: 1)
        bond.registerPat(comboMultiplier: 1)

        #expect(bond.points == 2)
        #expect(bond.totalPats == 2)
    }

    @Test("combo multiplier is clamped to a sane range")
    func comboMultiplierIsClamped() {
        var bond = PetBond()

        bond.registerPat(comboMultiplier: 0)   // clamps up to 1
        bond.registerPat(comboMultiplier: 50)  // clamps down to 5

        #expect(bond.points == 6)
        #expect(bond.totalPats == 2)
    }

    @Test("crossing a threshold advances the bond level")
    func crossingThresholdAdvancesLevel() {
        let bond = PetBond(points: 60)

        #expect(bond.level == .buddy)
        #expect(BondLevel.level(forPoints: 19) == .newFriend)
        #expect(BondLevel.level(forPoints: 20) == .pal)
        #expect(BondLevel.level(forPoints: 300) == .soulmate)
    }

    @Test("progress reports the way to the next level and tops out at the last")
    func progressBehaviour() {
        // Halfway between pal (20) and buddy (60).
        #expect(BondLevel.progress(forPoints: 40) == 0.5)
        // Final level is always full.
        #expect(BondLevel.progress(forPoints: 999) == 1)
    }

    @Test("playful actions grant a bonus without counting as a pat")
    func playGrantsBonus() {
        var bond = PetBond()

        bond.registerPlay()

        #expect(bond.points == 3)
        #expect(bond.totalPats == 0)
    }

    @Test("a bond survives a round trip through Codable")
    func bondIsCodable() throws {
        let bond = PetBond(points: 123, totalPats: 45)
        let data = try JSONEncoder().encode(bond)
        let restored = try JSONDecoder().decode(PetBond.self, from: data)

        #expect(restored == bond)
        #expect(restored.level == .buddy)
    }
}

@Suite("Personality moments")
struct PersonalityMomentTests {
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

    @Test("catalog contains twelve unique moments for each pet and three per category")
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

    @Test("selector respects pet context and recent exclusions")
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

        let excludedIDs = selected.map { Set([$0.id]) } ?? []
        let replacement = PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: context,
            excluding: excludedIDs,
            roll: 0
        )

        #expect(replacement?.id != selected?.id)
    }

    @Test("blocked presentation produces no moment")
    func blockedSelection() {
        let context = PersonalityMomentContext(
            petKind: .cat,
            mood: .cozy,
            workProgress: 0,
            requestedCategory: nil,
            isPresentationBlocked: true
        )

        #expect(PersonalityMomentSelector.select(
            from: PersonalityMomentCatalog.all,
            context: context,
            excluding: [],
            roll: 0
        ) == nil)
    }

    @Test("interaction requests select only the requested pet interaction")
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

    @Test("weather and focus moments require matching context")
    func conditionalMatches() {
        let catWeather = PersonalityMomentCatalog.all.first {
            $0.petKind == .cat && $0.category == .weather
        }
        let catFocus = PersonalityMomentCatalog.all.first {
            $0.petKind == .cat && $0.category == .focus
        }

        #expect(catWeather != nil)
        #expect(catFocus != nil)
        if let catWeather {
            let matchingMood = catWeather.moods.first ?? .cozy
            let matching = PersonalityMomentContext(
                petKind: .cat,
                mood: matchingMood,
                workProgress: 0,
                requestedCategory: nil,
                isPresentationBlocked: false
            )
            let nonmatching = PersonalityMomentContext(
                petKind: .cat,
                mood: PetWeatherMood.allCases.first { !catWeather.moods.contains($0) } ?? matchingMood,
                workProgress: 0,
                requestedCategory: nil,
                isPresentationBlocked: false
            )

            #expect(catWeather.matches(matching))
            if nonmatching.mood != matchingMood {
                #expect(!catWeather.matches(nonmatching))
            }
        }
        if let catFocus {
            let threshold = catFocus.minimumWorkProgress ?? 0
            let below = PersonalityMomentContext(
                petKind: .cat,
                mood: .cozy,
                workProgress: max(0, threshold - 0.01),
                requestedCategory: nil,
                isPresentationBlocked: false
            )
            let atThreshold = PersonalityMomentContext(
                petKind: .cat,
                mood: .cozy,
                workProgress: threshold,
                requestedCategory: nil,
                isPresentationBlocked: false
            )

            #expect(!catFocus.matches(below))
            #expect(catFocus.matches(atThreshold))
        }
    }

    @Test("personality delay stays between ten and twenty minutes")
    func scheduleBounds() {
        #expect(PersonalityMomentSchedule.delay(for: 0) == 10 * 60)
        #expect(PersonalityMomentSchedule.delay(for: 600) == 20 * 60)
        #expect(PersonalityMomentSchedule.delay(for: Int.min) >= 10 * 60)
        #expect(PersonalityMomentSchedule.delay(for: Int.max) <= 20 * 60)
    }
}
