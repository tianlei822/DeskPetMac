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
            #expect((24...30).contains(profile.maximumFramesPerSecond))
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

    @Test("ambient weather stays static while active weather animates")
    func renderingModesRespectEnergyBudget() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherSceneProfile(mood: mood)
            #expect(profile.renderingMode(reduceMotion: true) == .staticCue)
            if mood == .sunny || mood == .cozy {
                #expect(profile.renderingMode(reduceMotion: false) == .staticCue)
            } else {
                #expect(profile.renderingMode(reduceMotion: false) == .animated)
            }
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
            let directory = String(fixture.base.dropLast("base".count))
            #expect(manifest.resourceName(for: .anticipate)
                == "\(directory)anticipate")
            #expect(manifest.resourceName(for: .turn)
                == "\(directory)turn")
            #expect(manifest.resourceName(for: .settle)
                == "\(directory)settle")

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
            #expect(manifest.transitionResourceNames.count == 3)
            #expect(manifest.motionResourceNames.count == 14)
            #expect(manifest.runtimeMotionResourceNames.count == 1)
            #expect(
                manifest.runtimeMotionResourceNames
                    == [manifest.personality[.stretch] ?? manifest.base]
            )
            #expect(
                Set(manifest.runtimeMotionResourceNames)
                    .isDisjoint(with: manifest.walk)
            )
            #expect(
                Set(manifest.runtimeMotionResourceNames)
                    .isDisjoint(with: manifest.idleActions)
            )
            #expect(
                Set(manifest.runtimeMotionResourceNames)
                    .isDisjoint(with: manifest.transitionClipResourceNames)
            )
        }
    }

    @Test("motion artwork validation rejects partial resource sets")
    func motionArtworkValidationRejectsPartialSets() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let completeResources = Set(manifest.runtimeMotionResourceNames)
            let partialResources = Set(
                manifest.runtimeMotionResourceNames.dropLast()
            )

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
        #expect(manifest.resourceName(
            for: PetMotionEvent.lookAround,
            frameIndex: nil
        ) == "Pets/Dog/peek")
        #expect(manifest.resourceName(
            for: PetMotionEvent.stretch,
            frameIndex: nil
        ) == "Pets/Dog/stretch")
        #expect(manifest.resourceName(
            for: PetMotionEvent.perkUp,
            frameIndex: nil
        ) == "Pets/Dog/perk")
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

    @Test("root-motion phases select explicit transition artwork")
    func rootMotionPhasesSelectTransitionArtwork() {
        #expect(PetRootMotionPhase.notice.transitionPose == nil)
        #expect(PetRootMotionPhase.anticipate.transitionPose == .anticipate)
        #expect(PetRootMotionPhase.turning.transitionPose == .turn)
        #expect(PetRootMotionPhase.walking.transitionPose == nil)
        #expect(PetRootMotionPhase.slowing.transitionPose == nil)
        #expect(PetRootMotionPhase.settling.transitionPose == .settle)
        #expect(PetRootMotionPhase.completed.transitionPose == nil)
    }
}

@Suite("Pet artwork layout")
struct PetArtworkLayoutTests {
    @Test("aligned idle artwork shares one registration")
    func alignedIdleArtworkSharesRegistration() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let base = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.base
            )
            let blink = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.blink
            )

            #expect(base == blink)
        }
    }

    @Test("animal sleep poses move toward a wider contact shadow")
    func animalSleepPosesAreGrounded() {
        for petKind in [PetKind.cat, .dog] {
            let manifest = PetArtworkManifest(petKind: petKind)
            let idle = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.base
            )
            let sleep = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.sleep
            )

            #expect(sleep.verticalOffset > idle.verticalOffset + 20)
            #expect(sleep.shadowWidth > idle.shadowWidth + 30)
            #expect(sleep.shadowHeight >= idle.shadowHeight)
        }
    }

    @Test("layout values stay finite and inside the scene budget")
    func layoutValuesStaySafe() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let resources = [
                manifest.base,
                manifest.blink,
                manifest.hover,
                manifest.pat,
                manifest.sleep,
            ] + manifest.walk + manifest.idleActions
                + manifest.transitionResourceNames
                + manifest.transitionClipResourceNames
                + PersonalityPose.allCases.map {
                    manifest.resourceName(for: .personality($0))
                }

            for resourceName in resources {
                let layout = PetArtworkLayout.resolve(
                    petKind: petKind,
                    resourceName: resourceName
                )
                let values = [
                    layout.scale,
                    layout.verticalOffset,
                    layout.shadowWidth,
                    layout.shadowHeight,
                    layout.shadowVerticalOffset,
                ]

                #expect(values.allSatisfy { $0.isFinite })
                #expect((0.8...1.2).contains(layout.scale))
                let verticalOffsetRange = manifest.transitionClipResourceNames
                    .contains(resourceName)
                    ? (-24.0...60)
                    : (-10.0...60)
                #expect(verticalOffsetRange.contains(layout.verticalOffset))
                #expect((70...170).contains(layout.shadowWidth))
                #expect((10...24).contains(layout.shadowHeight))
                #expect((65...90).contains(layout.shadowVerticalOffset))
            }
        }
    }

    @Test("unknown resources use the pet default registration")
    func unknownResourcesUseDefaultRegistration() {
        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            #expect(PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: "Pets/Unknown/missing"
            ) == PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.base
            ))
        }
    }

    @Test("walk frames share the idle foot baseline within two pixels")
    func walkFramesShareFootBaseline() {
        let sourceBottoms: [PetKind: (base: Double, walk: [Double])] = [
            .cat: (1_079, [1_115, 1_115, 1_117, 1_117, 1_119, 1_117]),
            .pauli: (1_185, [1_171, 1_180, 1_166, 1_177, 1_183, 1_182]),
            .dog: (1_192, [1_178, 1_208, 1_203, 1_209, 1_211, 1_185]),
        ]

        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let baseLayout = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.base
            )
            let bounds = sourceBottoms[petKind]!
            let baseLine = bounds.base * 190 / 1_254 * baseLayout.scale

            for (index, resourceName) in manifest.walk.enumerated() {
                let layout = PetArtworkLayout.resolve(
                    petKind: petKind,
                    resourceName: resourceName
                )
                let renderedLine = bounds.walk[index] * 190 / 1_254
                    * layout.scale + layout.verticalOffset
                #expect(abs(renderedLine - baseLine) < 0.25)
            }
        }
    }

    @Test("transition poses share the idle foot baseline within two pixels")
    func transitionFramesShareFootBaseline() {
        let sourceBottoms: [PetKind: (
            base: Double,
            transitions: [PetTransitionPose: Double]
        )] = [
            .cat: (1_079, [.anticipate: 1_073, .turn: 1_101, .settle: 1_049]),
            .pauli: (1_185, [.anticipate: 1_141, .turn: 1_182, .settle: 1_188]),
            .dog: (1_192, [.anticipate: 1_145, .turn: 1_141, .settle: 1_097]),
        ]

        for petKind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: petKind)
            let baseLayout = PetArtworkLayout.resolve(
                petKind: petKind,
                resourceName: manifest.base
            )
            let bounds = sourceBottoms[petKind]!
            let baseLine = bounds.base * 190 / 1_254 * baseLayout.scale

            for pose in PetTransitionPose.allCases {
                let resourceName = manifest.resourceName(for: pose)
                let layout = PetArtworkLayout.resolve(
                    petKind: petKind,
                    resourceName: resourceName
                )
                let sourceBottom = bounds.transitions[pose]!
                let renderedLine = sourceBottom * 190 / 1_254
                    * layout.scale + layout.verticalOffset
                #expect(abs(renderedLine - baseLine) < 0.25)
            }
        }
    }
}

@Suite("Pet bubble layout")
struct PetBubbleLayoutTests {
    @Test("each companion exposes a stable normalized head anchor")
    func headAnchorsStayInsideArtwork() {
        let expected: [PetKind: CGPoint] = [
            .cat: CGPoint(x: 0.44, y: 0.35),
            .pauli: CGPoint(x: 0.50, y: 0.38),
            .dog: CGPoint(x: 0.46, y: 0.39),
        ]

        for petKind in PetKind.allCases {
            let anchor = PetHeadAnchor.resolve(for: petKind)
            #expect(anchor.normalizedPoint == expected[petKind])
            #expect((0...1).contains(anchor.normalizedPoint.x))
            #expect((0...1).contains(anchor.normalizedPoint.y))
        }
    }

    @Test("personality bubble tails point at each companion head")
    func personalityTailTargetsHeadAnchor() {
        let geometry = PetBubbleGeometry.standard
        let bubbleCenters: [PetBubblePlacement: Double] = [
            .leading: geometry.horizontalPadding + geometry.bubbleWidth / 2,
            .center: geometry.sceneWidth / 2,
            .trailing: geometry.sceneWidth
                - geometry.horizontalPadding
                - geometry.bubbleWidth / 2,
        ]

        for petKind in PetKind.allCases {
            let head = PetHeadAnchor.resolve(for: petKind)
            let artworkOriginX = (
                geometry.sceneWidth - geometry.artworkWidth
            ) / 2
            let expectedTargetX = artworkOriginX
                + head.normalizedPoint.x * geometry.artworkWidth

            for placement in [
                PetBubblePlacement.leading,
                .center,
                .trailing,
            ] {
                let layout = PetBubbleLayout.resolve(
                    kind: .personality,
                    petKind: petKind,
                    placement: placement,
                    geometry: geometry
                )
                let resolvedTargetX = bubbleCenters[placement]!
                    + layout.tailHorizontalOffset

                #expect(abs(resolvedTargetX - expectedTargetX) < 0.001)
            }
        }
    }

    @Test("bubble aligns toward the roomiest side of the screen")
    func bubbleUsesAvailableScreenSpace() {
        let nearRightEdge = PetBubbleLayout.resolve(
            kind: .status,
            windowMinX: 1150,
            windowMaxX: 1410,
            visibleMinX: 0,
            visibleMaxX: 1440
        )
        let nearLeftEdge = PetBubbleLayout.resolve(
            kind: .status,
            windowMinX: 30,
            windowMaxX: 290,
            visibleMinX: 0,
            visibleMaxX: 1440
        )

        #expect(nearRightEdge.placement == .leading)
        #expect(nearRightEdge.tailHorizontalOffset > 0)
        #expect(nearLeftEdge.placement == .trailing)
        #expect(nearLeftEdge.tailHorizontalOffset < 0)
    }

    @Test("balanced screen space keeps the bubble centered")
    func balancedSpaceCentersBubble() {
        let layout = PetBubbleLayout.resolve(
            kind: .personality,
            windowMinX: 590,
            windowMaxX: 850,
            visibleMinX: 0,
            visibleMaxX: 1440
        )

        #expect(layout.placement == .center)
        #expect(layout.tailHorizontalOffset == 0)
    }

    @Test("top constrained windows mount speech beside the pet")
    func topConstrainedWindowUsesSidePlacement() {
        let nearTopRight = PetBubbleLayout.resolve(
            kind: .personality,
            windowMinX: 1150,
            windowMaxX: 1410,
            windowMinY: 590,
            windowMaxY: 880,
            visibleMinX: 0,
            visibleMaxX: 1440,
            visibleMinY: 0,
            visibleMaxY: 900
        )
        let nearTopLeft = PetBubbleLayout.resolve(
            kind: .personality,
            windowMinX: 30,
            windowMaxX: 290,
            windowMinY: 590,
            windowMaxY: 880,
            visibleMinX: 0,
            visibleMaxX: 1440,
            visibleMinY: 0,
            visibleMaxY: 900
        )

        #expect(nearTopRight.placement == .sideLeading)
        #expect(nearTopLeft.placement == .sideTrailing)
    }

    @Test("side speech frees vertical room and points inward")
    func sideSpeechUsesCompactInwardGeometry() {
        let leading = PetBubbleLayout.resolve(
            kind: .personality,
            petKind: .cat,
            placement: .sideLeading
        )
        let trailing = PetBubbleLayout.resolve(
            kind: .personality,
            petKind: .dog,
            placement: .sideTrailing
        )

        #expect(leading.bubbleWidth == PetBubbleGeometry.standard.sideBubbleWidth)
        #expect(trailing.bubbleWidth == PetBubbleGeometry.standard.sideBubbleWidth)
        #expect(leading.sceneVerticalOffset == 0)
        #expect(trailing.sceneVerticalOffset == 0)
        #expect(leading.sceneHorizontalOffset > 0)
        #expect(trailing.sceneHorizontalOffset < 0)
        #expect(leading.tailEdge == .trailing)
        #expect(trailing.tailEdge == .leading)
        #expect(leading.bubbleTopOffset > 40)
        #expect(trailing.bubbleTopOffset > 40)

        let geometry = PetBubbleGeometry.standard
        let artworkOriginX = (geometry.sceneWidth - geometry.artworkWidth) / 2
        let leadingBubbleEdge = geometry.sideHorizontalPadding
            + geometry.sideBubbleWidth
        let trailingBubbleEdge = geometry.sceneWidth
            - geometry.sideHorizontalPadding
            - geometry.sideBubbleWidth
        for petKind in PetKind.allCases {
            let headX = artworkOriginX
                + PetHeadAnchor.resolve(for: petKind).normalizedPoint.x
                    * geometry.artworkWidth
            #expect(
                headX + leading.sceneHorizontalOffset - leadingBubbleEdge
                    >= 24
            )
            #expect(
                trailingBubbleEdge
                    - (headX + trailing.sceneHorizontalOffset) >= 24
            )
        }

        #expect(
            artworkOriginX + leading.sceneHorizontalOffset
                + geometry.artworkWidth <= geometry.sceneWidth
        )
        #expect(artworkOriginX + trailing.sceneHorizontalOffset >= 0)
    }

    @Test("interactive bubbles remain overhead even near the menu bar")
    func interactiveBubblesStayOverhead() {
        for kind in [PetBubbleKind.reminder, .status] {
            let layout = PetBubbleLayout.resolve(
                kind: kind,
                petKind: .pauli,
                placement: .sideTrailing
            )

            #expect(layout.placement == .trailing)
            #expect(layout.tailEdge == .bottom)
            #expect(layout.bubbleWidth == PetBubbleGeometry.standard.bubbleWidth)
            #expect(layout.sceneVerticalOffset > 0)
        }
    }

    @Test("larger bubbles reserve more room above the pet")
    func largerBubblesReserveMoreRoom() {
        let reminder = PetBubbleLayout.resolve(kind: .reminder)
        let status = PetBubbleLayout.resolve(kind: .status)
        let personality = PetBubbleLayout.resolve(kind: .personality)

        #expect(reminder.sceneVerticalOffset > status.sceneVerticalOffset)
        #expect(status.sceneVerticalOffset > personality.sceneVerticalOffset)
        #expect(personality.sceneVerticalOffset > 0)
        #expect(reminder.sceneVerticalOffset <= 44)
    }

    @Test("invalid window geometry falls back to a finite centered layout")
    func invalidGeometryIsSafe() {
        let layout = PetBubbleLayout.resolve(
            kind: .status,
            windowMinX: .nan,
            windowMaxX: .infinity,
            visibleMinX: 0,
            visibleMaxX: 1440
        )

        #expect(layout.placement == .center)
        #expect(layout.sceneVerticalOffset.isFinite)
        #expect(layout.tailHorizontalOffset.isFinite)
    }
}

@Suite("Pet window anchor")
struct PetWindowAnchorTests {
    @Test("window position survives a visible-frame size change")
    func positionScalesWithVisibleFrame() {
        let anchor = PetWindowAnchor.capture(
            windowFrame: CGRect(x: 400, y: 300, width: 200, height: 200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        let restored = anchor.resolve(
            windowSize: CGSize(width: 200, height: 200),
            visibleFrame: CGRect(x: 100, y: 50, width: 1400, height: 900)
        )

        #expect(anchor.horizontal == 0.5)
        #expect(anchor.vertical == 0.5)
        #expect(restored == CGPoint(x: 700, y: 400))
    }

    @Test("offscreen origins are clamped into the visible frame")
    func offscreenOriginsAreClamped() {
        let anchor = PetWindowAnchor.capture(
            windowFrame: CGRect(x: 1800, y: -500, width: 260, height: 290),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        let restored = anchor.resolve(
            windowSize: CGSize(width: 260, height: 290),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(restored == CGPoint(x: 1180, y: 0))
    }

    @Test("invalid anchors and geometry use safe finite values")
    func invalidValuesAreSafe() {
        let anchor = PetWindowAnchor(horizontal: .nan, vertical: .infinity)
        let restored = anchor.resolve(
            windowSize: CGSize(width: 260, height: 290),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(anchor == .default)
        #expect(restored.x.isFinite)
        #expect(restored.y.isFinite)
    }
}

@Suite("Pet hit mask")
struct PetHitMaskTests {
    @Test("transparent window corners pass pointer events through")
    func cornersAreTransparent() {
        for petKind in PetKind.allCases {
            #expect(!PetHitMask.contains(
                normalizedPoint: CGPoint(x: 0.02, y: 0.02),
                petKind: petKind
            ))
            #expect(!PetHitMask.contains(
                normalizedPoint: CGPoint(x: 0.98, y: 0.98),
                petKind: petKind
            ))
        }
    }

    @Test("head and torso regions remain directly interactive")
    func bodyRegionsAreInteractive() {
        for petKind in PetKind.allCases {
            #expect(PetHitMask.contains(
                normalizedPoint: CGPoint(x: 0.5, y: 0.42),
                petKind: petKind
            ))
            #expect(PetHitMask.contains(
                normalizedPoint: CGPoint(x: 0.5, y: 0.65),
                petKind: petKind
            ))
        }
    }

    @Test("points outside normalized artwork bounds pass through")
    func outsidePointsAreTransparent() {
        #expect(!PetHitMask.contains(
            normalizedPoint: CGPoint(x: -0.1, y: 0.5),
            petKind: .cat
        ))
        #expect(!PetHitMask.contains(
            normalizedPoint: CGPoint(x: 0.5, y: 1.1),
            petKind: .dog
        ))
    }
}

@Suite("Pet render cadence")
struct PetRenderCadenceTests {
    @Test("direct interaction receives the 60 fps response budget")
    func directInteractionUsesFastCadence() {
        let cadence = PetRenderCadence.resolve(
            reduceMotion: false,
            isVisible: true,
            isDirectInteraction: true,
            isActiveMotion: false
        )

        #expect(cadence.maximumFramesPerSecond == 60)
        #expect(!cadence.isPaused)
    }

    @Test("idle and autonomous motion stay inside the companion budget")
    func ambientMotionUsesBoundedCadence() {
        let idle = PetRenderCadence.resolve(
            reduceMotion: false,
            isVisible: true,
            isDirectInteraction: false,
            isActiveMotion: false
        )
        let active = PetRenderCadence.resolve(
            reduceMotion: false,
            isVisible: true,
            isDirectInteraction: false,
            isActiveMotion: true
        )

        #expect(idle.maximumFramesPerSecond == 12)
        #expect(active.maximumFramesPerSecond == 30)
    }

    @Test("Reduce Motion lowers cadence and hidden windows pause")
    func accessibilityAndVisibilityReduceWork() {
        let reduced = PetRenderCadence.resolve(
            reduceMotion: true,
            isVisible: true,
            isDirectInteraction: true,
            isActiveMotion: true
        )
        let hidden = PetRenderCadence.resolve(
            reduceMotion: false,
            isVisible: false,
            isDirectInteraction: true,
            isActiveMotion: true
        )

        #expect(reduced.maximumFramesPerSecond == 8)
        #expect(!reduced.isPaused)
        #expect(hidden.isPaused)
        #expect(hidden.minimumInterval.isFinite)
        #expect(hidden.minimumInterval > 0)
    }
}

@Suite("Pet activity graph")
struct PetActivityGraphTests {
    @Test("direct interaction wins over ambient and presentation states")
    func directInteractionHasPriority() {
        let activity = PetActivityGraph.resolve(PetActivityContext(
            isSleeping: true,
            isDancing: true,
            isNuzzling: true,
            isReminderVisible: true,
            personalityPose: .peek,
            autonomyDrive: .explore
        ))

        #expect(activity.kind == .nuzzling)
        #expect(activity.priority > PetActivity.autonomous(.explore).priority)
    }

    @Test("reminder becomes a companion stretch when interaction is idle")
    func reminderMapsToStretchActivity() {
        let activity = PetActivityGraph.resolve(PetActivityContext(
            isSleeping: false,
            isDancing: false,
            isNuzzling: false,
            isReminderVisible: true,
            personalityPose: .perk,
            autonomyDrive: .selfCare
        ))

        #expect(activity.kind == .reminder)
        #expect(activity.personalityPose == .stretch)
    }

    @Test("personality and autonomy context remain attached to the activity")
    func contextStaysAttached() {
        let personality = PetActivityGraph.resolve(PetActivityContext(
            personalityPose: .proud,
            autonomyDrive: .seekAttention
        ))
        let autonomy = PetActivityGraph.resolve(PetActivityContext(
            autonomyDrive: .observeWeather
        ))

        #expect(personality.kind == .personality)
        #expect(personality.personalityPose == .proud)
        #expect(autonomy.kind == .autonomous)
        #expect(autonomy.autonomyDrive == .observeWeather)
    }

    @Test("roaming sits above autonomy but below direct interaction")
    func roamingUsesInterruptibleMidPriority() {
        let roaming = PetActivityGraph.resolve(PetActivityContext(
            isRoaming: true,
            autonomyDrive: .explore
        ))

        #expect(roaming.kind == .roaming)
        #expect(PetActivityGraph.canInterrupt(roaming, with: .dancing))
        #expect(!PetActivityGraph.canInterrupt(roaming, with: .autonomous(.explore)))
    }

    @Test("only higher-priority activities interrupt a committed activity")
    func interruptionsRespectPriority() {
        let dance = PetActivity.dancing
        let scratch = PetActivity.scratching
        let nuzzle = PetActivity.nuzzling
        let autonomy = PetActivity.autonomous(.explore)

        #expect(PetActivityGraph.canInterrupt(dance, with: scratch))
        #expect(PetActivityGraph.canInterrupt(scratch, with: nuzzle))
        #expect(PetActivityGraph.canInterrupt(dance, with: nuzzle))
        #expect(!PetActivityGraph.canInterrupt(dance, with: autonomy))
        #expect(!PetActivityGraph.canInterrupt(nuzzle, with: dance))
    }

    @Test("scratch is represented as a direct interaction activity")
    func scratchingMapsToDirectActivity() {
        let activity = PetActivityGraph.resolve(PetActivityContext(
            isSleeping: true,
            isDancing: true,
            isScratching: true,
            isReminderVisible: true,
            autonomyDrive: .rest
        ))

        #expect(activity.kind == .scratching)
        #expect(activity.priority > PetActivity.dancing.priority)
        #expect(activity.priority < PetActivity.nuzzling.priority)
    }

    @Test("feeding phases drive attentive poses below committed gestures")
    func feedingMapsToCausalPoses() {
        let watching = PetActivityGraph.resolve(PetActivityContext(
            feedingPhase: .watching,
            autonomyDrive: .selfCare
        ))
        let eating = PetActivityGraph.resolve(PetActivityContext(
            feedingPhase: .eating,
            autonomyDrive: .selfCare
        ))

        #expect(watching.kind == .feeding)
        #expect(watching.personalityPose == .perk)
        #expect(eating.personalityPose == .proud)
        #expect(PetActivityGraph.canInterrupt(watching, with: .dancing))
    }
}

@Suite("Pet root motion")
struct PetRootMotionPlanTests {
    @Test("plan flips away from a nearby screen edge")
    func planFlipsAtScreenEdge() {
        let plan = PetRootMotionPlan.resolve(
            startX: 1100,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .right
        )

        #expect(plan.direction == .left)
        #expect(plan.distance == 120)
        #expect(plan.targetX == 980)
    }

    @Test("window travel follows notice, anticipate, turn, walk, slow, and settle phases")
    func phasesStayBoundedAndMonotonic() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 100,
            preferredDirection: .right
        )
        let samples = stride(
            from: 0.0,
            through: plan.duration,
            by: plan.duration / 40
        ).map { plan.frame(at: $0) }

        #expect(plan.frame(at: 0).phase == .notice)
        #expect(samples.contains { $0.phase == .anticipate })
        #expect(samples.contains { $0.phase == .turning })
        #expect(samples.contains { $0.phase == .walking })
        #expect(samples.contains { $0.phase == .slowing })
        #expect(samples.contains { $0.phase == .settling })
        #expect(plan.frame(at: plan.duration).phase == .completed)
        #expect(plan.frame(at: plan.duration).windowX == plan.targetX)
        #expect(samples.allSatisfy { (400...500).contains($0.windowX) })
        #expect(zip(samples, samples.dropFirst()).allSatisfy {
            $0.windowX <= $1.windowX
        })
    }

    @Test("travel distance and invalid geometry stay safe")
    func travelBudgetIsSafe() {
        let bounded = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 400,
            preferredDirection: .right
        )
        let invalid = PetRootMotionPlan.resolve(
            startX: .nan,
            visibleMinX: 0,
            visibleMaxX: .infinity,
            windowWidth: 260,
            desiredDistance: .nan,
            preferredDirection: .left
        )

        #expect(bounded.distance == 160)
        #expect(invalid.distance == 0)
        #expect(invalid.targetX.isFinite)
        #expect(invalid.duration.isFinite)
    }

    @Test("window travel holds during planted-foot intervals")
    func plantedFootIntervalsHoldPosition() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 140,
            preferredDirection: .right
        )
        let samples = (0...2_000).map {
            plan.frame(at: plan.duration * Double($0) / 2_000)
        }

        #expect(plan.stepCount >= 3)
        for stepIndex in 0..<plan.stepCount {
            let leadingContact = samples.filter {
                $0.stepIndex == stepIndex
                    && ($0.phase == .walking || $0.phase == .slowing)
                    && $0.stridePhase <= 0.13
            }
            let trailingContact = samples.filter {
                $0.stepIndex == stepIndex
                    && ($0.phase == .walking || $0.phase == .slowing)
                    && $0.stridePhase >= 0.84
            }

            if let first = leadingContact.first, let last = leadingContact.last {
                #expect(abs(last.windowX - first.windowX) < 2)
            }
            if let first = trailingContact.first, let last = trailingContact.last {
                #expect(abs(last.windowX - first.windowX) < 2)
            }
        }
    }

    @Test("stride metadata is finite, bounded, and reaches every step")
    func strideMetadataIsStable() {
        let plan = PetRootMotionPlan.resolve(
            startX: 700,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .left
        )
        let samples = (0...500).map {
            plan.frame(at: plan.duration * Double($0) / 500)
        }
        let moving = samples.filter {
            $0.phase == .walking || $0.phase == .slowing
        }

        #expect(Set(moving.map(\.stepIndex)) == Set(0..<plan.stepCount))
        #expect(moving.allSatisfy { (0...1).contains($0.stridePhase) })
        #expect(moving.allSatisfy { (0...1).contains($0.travelProgress) })
        #expect(zip(moving, moving.dropFirst()).allSatisfy {
            plan.direction == .left
                ? $0.windowX >= $1.windowX
                : $0.windowX <= $1.windowX
        })
    }

    @Test("walk artwork consumes the exact root-motion stride phase")
    func artworkAndTravelShareStridePhase() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .right
        )
        let rootFrame = plan.frame(
            at: plan.preparationDuration + plan.movementDuration * 0.375
        )
        let artworkFrame = PetMotionDirector.rootMotionFrame(
            pet: .cat,
            rootMotion: rootFrame,
            reduceMotion: false
        )

        #expect(rootFrame.phase == .walking)
        #expect(rootFrame.stridePhase > 0.45)
        #expect(rootFrame.stridePhase < 0.55)
        #expect(artworkFrame.event == .walk)
        #expect(artworkFrame.presentedArtworkFrameIndex == 3)
        #expect(artworkFrame.stepCount == plan.stepCount)
    }

    @Test("transition weight shifts stay continuous across phase boundaries")
    func transitionWeightShiftIsContinuous() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .right
        )
        let boundaries = [
            plan.preparationDuration * 0.34,
            plan.preparationDuration * 0.70,
            plan.preparationDuration,
            plan.preparationDuration + plan.movementDuration * 0.78,
            plan.preparationDuration + plan.movementDuration,
            plan.duration,
        ]

        for boundary in boundaries {
            let before = PetRootTransitionMotion.pose(
                for: plan.frame(at: max(0, boundary - 0.000_001)),
                reduceMotion: false
            )
            let after = PetRootTransitionMotion.pose(
                for: plan.frame(at: boundary + 0.000_001),
                reduceMotion: false
            )
            #expect(rootPoseDistance(before, after) < 0.001)
        }
    }

    @Test("left and right weight shifts mirror without changing compression")
    func transitionWeightShiftMirrorsDirection() {
        let right = PetRootMotionPlan.resolve(
            startX: 500,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .right
        )
        let left = PetRootMotionPlan.resolve(
            startX: 500,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .left
        )

        for index in 0...120 {
            let elapsed = right.duration * Double(index) / 120
            let rightPose = PetRootTransitionMotion.pose(
                for: right.frame(at: elapsed),
                reduceMotion: false
            )
            let leftPose = PetRootTransitionMotion.pose(
                for: left.frame(at: elapsed),
                reduceMotion: false
            )

            #expect(abs(rightPose.horizontalScale - leftPose.horizontalScale) < 0.000_001)
            #expect(abs(rightPose.verticalScale - leftPose.verticalScale) < 0.000_001)
            #expect(abs(rightPose.verticalOffset - leftPose.verticalOffset) < 0.000_001)
            #expect(abs(rightPose.shadowScale - leftPose.shadowScale) < 0.000_001)
            #expect(abs(rightPose.horizontalOffset + leftPose.horizontalOffset) < 0.000_001)
            #expect(abs(rightPose.tiltDegrees + leftPose.tiltDegrees) < 0.000_001)
            #expect(abs(rightPose.shadowOffset + leftPose.shadowOffset) < 0.000_001)
        }
    }

    @Test("anticipation compresses before travel and settling returns neutral")
    func transitionWeightShiftExpressesPreparationAndRecovery() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 120,
            preferredDirection: .right
        )
        let anticipated = PetRootTransitionMotion.pose(
            for: plan.frame(at: plan.preparationDuration * 0.70 - 0.000_001),
            reduceMotion: false
        )
        let slowing = PetRootTransitionMotion.pose(
            for: plan.frame(
                at: plan.preparationDuration + plan.movementDuration - 0.000_001
            ),
            reduceMotion: false
        )
        let completed = PetRootTransitionMotion.pose(
            for: plan.frame(at: plan.duration),
            reduceMotion: false
        )

        #expect(anticipated.verticalScale < 0.98)
        #expect(anticipated.verticalOffset > 1.5)
        #expect(anticipated.shadowScale > 1.04)
        #expect(slowing.horizontalOffset > 0.8)
        #expect(slowing.verticalScale < 1)
        #expect(completed == .neutral)
    }

    @Test("weight shifts are finite bounded and disabled by Reduce Motion")
    func transitionWeightShiftStaysSafe() {
        let plan = PetRootMotionPlan.resolve(
            startX: 400,
            visibleMinX: 0,
            visibleMaxX: 1440,
            windowWidth: 260,
            desiredDistance: 160,
            preferredDirection: .left
        )

        for index in 0...1_000 {
            let frame = plan.frame(at: plan.duration * Double(index) / 1_000)
            let pose = PetRootTransitionMotion.pose(
                for: frame,
                reduceMotion: false
            )
            #expect((0.94...1.08).contains(pose.horizontalScale))
            #expect((0.94...1.03).contains(pose.verticalScale))
            #expect(abs(pose.horizontalOffset) <= 4)
            #expect(abs(pose.verticalOffset) <= 3)
            #expect(abs(pose.tiltDegrees) <= 4)
            #expect((0.9...1.12).contains(pose.shadowScale))
            #expect(abs(pose.shadowOffset) <= 2)
            #expect(PetRootTransitionMotion.pose(
                for: frame,
                reduceMotion: true
            ) == .neutral)
        }
    }

    private func rootPoseDistance(
        _ lhs: PetRootTransitionPose,
        _ rhs: PetRootTransitionPose
    ) -> Double {
        [
            lhs.horizontalScale - rhs.horizontalScale,
            lhs.verticalScale - rhs.verticalScale,
            lhs.horizontalOffset - rhs.horizontalOffset,
            lhs.verticalOffset - rhs.verticalOffset,
            lhs.tiltDegrees - rhs.tiltDegrees,
            lhs.shadowScale - rhs.shadowScale,
            lhs.shadowOffset - rhs.shadowOffset,
        ].map(abs).max() ?? 0
    }
}

@Suite("Pet interaction map")
struct PetInteractionMapTests {
    @Test("each character exposes a small nose or sensor target")
    func noseAndSensorTargetsResolveFirst() {
        let points: [PetKind: CGPoint] = [
            .cat: CGPoint(x: 0.44, y: 0.35),
            .pauli: CGPoint(x: 0.50, y: 0.38),
            .dog: CGPoint(x: 0.46, y: 0.39),
        ]

        for (petKind, point) in points {
            #expect(PetInteractionMap.resolve(
                normalizedPoint: point,
                petKind: petKind
            ) == .noseOrSensor)
        }
    }

    @Test("head and torso points resolve to distinct interactions")
    func bodyZonesStayDistinct() {
        for petKind in PetKind.allCases {
            #expect(PetInteractionMap.resolve(
                normalizedPoint: CGPoint(x: 0.38, y: 0.42),
                petKind: petKind
            ) == .head)
            #expect(PetInteractionMap.resolve(
                normalizedPoint: CGPoint(x: 0.50, y: 0.70),
                petKind: petKind
            ) == .torso)
        }
    }

    @Test("transparent and invalid points resolve to none")
    func transparentPointsResolveToNone() {
        for point in [
            CGPoint(x: 0.02, y: 0.02),
            CGPoint(x: 0.98, y: 0.98),
            CGPoint(x: .nan, y: 0.5),
        ] {
            #expect(PetInteractionMap.resolve(
                normalizedPoint: point,
                petKind: .cat
            ) == .none)
        }
    }
}

@Suite("Pet toys")
struct PetToyTests {
    @Test("each character gets a distinct play object")
    func toyKindsAreCharacterSpecific() {
        #expect(PetToyKind.forPet(.cat) == .laser)
        #expect(PetToyKind.forPet(.pauli) == .energyNode)
        #expect(PetToyKind.forPet(.dog) == .ball)
    }

    @Test("ball trajectory preserves endpoints and lifts through the middle")
    func ballTrajectoryHasAnArc() {
        let trajectory = PetToyTrajectory(
            start: CGPoint(x: 0.2, y: 0.8),
            end: CGPoint(x: 0.8, y: 0.7),
            arcHeight: 0.25
        )
        let middle = trajectory.position(at: 0.5)

        #expect(trajectory.position(at: 0) == CGPoint(x: 0.2, y: 0.8))
        #expect(trajectory.position(at: 1) == CGPoint(x: 0.8, y: 0.7))
        #expect(middle.y < 0.75)
        #expect((0...1).contains(middle.x))
        #expect((0...1).contains(middle.y))
    }

    @Test("toy positions and invalid progress remain inside the scene")
    func trajectoryStaysSafe() {
        let trajectory = PetToyTrajectory(
            start: CGPoint(x: -2, y: CGFloat.nan),
            end: CGPoint(x: 4, y: 3),
            arcHeight: .infinity
        )

        for progress in [-1.0, 0, 0.5, 1, 2, .nan] {
            let point = trajectory.position(at: progress)
            #expect(point.x.isFinite)
            #expect(point.y.isFinite)
            #expect((0...1).contains(point.x))
            #expect((0...1).contains(point.y))
        }
    }
}

@Suite("Pet quiet mode")
struct PetQuietModePolicyTests {
    @Test("quiet mode suppresses ambient presentation")
    func quietModeSuppressesAmbientPresentation() {
        for kind in [
            PetPresentationKind.status,
            .reminder,
            .personality,
        ] {
            #expect(!PetQuietModePolicy.allows(kind, isQuietModeEnabled: true))
            #expect(PetQuietModePolicy.allows(kind, isQuietModeEnabled: false))
        }
    }

    @Test("quiet mode preserves feedback for intentional interaction")
    func directFeedbackRemainsAvailable() {
        #expect(PetQuietModePolicy.allows(
            .directInteraction,
            isQuietModeEnabled: true
        ))
    }
}

@Suite("Pet animation dynamics")
struct PetAnimationDynamicsTests {
    @Test("pat response eases from and returns to neutral")
    func patResponseHasNeutralBoundaries() {
        for pet in PetKind.allCases {
            #expect(PetAnimationDynamics.patPose(for: pet, elapsed: 0) == .neutral)
            #expect(PetAnimationDynamics.patPose(for: pet, elapsed: 0.56) == .neutral)

            let peak = PetAnimationDynamics.patPose(for: pet, elapsed: 0.20)
            #expect(peak.scale > 1.01)
            #expect(peak.y < -1)
            expectFinitePose(peak)
        }
    }

    @Test("pat combos build from a soft bounce into a celebration")
    func patComboEscalatesReaction() {
        for pet in PetKind.allCases {
            let softDuration = PetAnimationDynamics.patDuration(comboCount: 1)
            let bounceDuration = PetAnimationDynamics.patDuration(comboCount: 3)
            let celebrationDuration = PetAnimationDynamics.patDuration(comboCount: 5)
            let soft = PetAnimationDynamics.patPose(
                for: pet,
                elapsed: softDuration * 0.36,
                comboCount: 1
            )
            let bounce = PetAnimationDynamics.patPose(
                for: pet,
                elapsed: bounceDuration * 0.36,
                comboCount: 3
            )
            let celebration = PetAnimationDynamics.patPose(
                for: pet,
                elapsed: celebrationDuration * 0.36,
                comboCount: 5
            )

            #expect(softDuration < bounceDuration)
            #expect(bounceDuration < celebrationDuration)
            #expect(bounce.y < soft.y)
            #expect(celebration.y < bounce.y)
            #expect(bounce.scale > soft.scale)
            #expect(celebration.scale > bounce.scale)
            #expect(
                PetAnimationDynamics.patPose(
                    for: pet,
                    elapsed: celebrationDuration,
                    comboCount: 5
                ) == .neutral
            )
            expectFinitePose(soft)
            expectFinitePose(bounce)
            expectFinitePose(celebration)
        }
    }

    @Test("hover attention follows the pointer without breaking subtle bounds")
    func attentionFollowsPointer() {
        for pet in PetKind.allCases {
            let left = PetAnimationDynamics.attentionPose(
                for: pet,
                pointerX: -1,
                pointerY: -0.8,
                time: 2
            )
            let right = PetAnimationDynamics.attentionPose(
                for: pet,
                pointerX: 1,
                pointerY: 0.8,
                time: 2
            )

            #expect(left.x < 0)
            #expect(right.x > 0)
            #expect(left.y < right.y)
            #expect(left.tiltDegrees < 0)
            #expect(right.tiltDegrees > 0)

            for pose in [left, right] {
                #expect(abs(pose.x) <= 5)
                #expect(abs(pose.y) <= 4)
                #expect((1...1.03).contains(pose.scale))
                #expect(abs(pose.tiltDegrees) <= 3)
                expectFinitePose(pose)
            }
        }

        #expect(
            PetAnimationDynamics.attentionPose(
                for: .cat,
                pointerX: .nan,
                pointerY: 0,
                time: 0
            ) == .neutral
        )
    }

    @Test("dance response is smooth and character specific")
    func danceResponseIsCharacterSpecific() {
        for pet in PetKind.allCases {
            #expect(PetAnimationDynamics.dancePose(for: pet, elapsed: 0) == .neutral)
            #expect(PetAnimationDynamics.dancePose(for: pet, elapsed: 1.8) == .neutral)
        }

        let cat = PetAnimationDynamics.dancePose(for: .cat, elapsed: 0.65)
        let pauli = PetAnimationDynamics.dancePose(for: .pauli, elapsed: 0.65)
        let dog = PetAnimationDynamics.dancePose(for: .dog, elapsed: 0.65)
        #expect(cat != pauli)
        #expect(pauli != dog)
        #expect(cat != dog)
        expectFinitePose(cat)
        expectFinitePose(pauli)
        expectFinitePose(dog)
    }

    @Test("layered idle motion stays subtle and finite")
    func idleMotionStaysSubtle() {
        for pet in PetKind.allCases {
            for time in stride(from: 0.0, through: 20.0, by: 0.125) {
                let pose = PetAnimationDynamics.idlePose(for: pet, time: time)
                #expect(abs(pose.x) <= 0.8)
                #expect(abs(pose.y) <= 2.2)
                #expect((0.99...1.01).contains(pose.scale))
                #expect(abs(pose.tiltDegrees) <= 1.2)
                expectFinitePose(pose)
            }
        }
    }

    @Test("blinks are brief irregular character beats")
    func blinkTimingFeelsNatural() {
        var patterns: [[Bool]] = []

        for pet in PetKind.allCases {
            let samples = stride(from: 0.0, through: 30.0, by: 0.02).map {
                PetAnimationDynamics.isBlinking(for: pet, time: $0)
            }
            let blinkSamples = samples.filter { $0 }.count
            #expect(blinkSamples >= 20)
            #expect(blinkSamples <= 90)
            #expect(longestRun(in: samples) <= 9)
            patterns.append(samples)
        }

        #expect(patterns[0] != patterns[1])
        #expect(patterns[1] != patterns[2])
    }

    @Test("cats and dogs have independent finite tail sway")
    func tailSwayIsIndependentAndCharacterSpecific() {
        for walking in [false, true] {
            let catSamples = stride(from: 0.0, through: 4.0, by: 0.1).map {
                PetAnimationDynamics.tailSwayDegrees(
                    for: .cat,
                    time: $0,
                    isWalking: walking
                )
            }
            let dogSamples = stride(from: 0.0, through: 4.0, by: 0.1).map {
                PetAnimationDynamics.tailSwayDegrees(
                    for: .dog,
                    time: $0,
                    isWalking: walking
                )
            }

            #expect(catSamples.allSatisfy { $0.isFinite })
            #expect(dogSamples.allSatisfy { $0.isFinite })
            #expect((catSamples.max() ?? 0) - (catSamples.min() ?? 0) > 2)
            #expect((dogSamples.max() ?? 0) - (dogSamples.min() ?? 0) > 4)
            #expect(catSamples != dogSamples)
            #expect(PetAnimationDynamics.tailSwayDegrees(
                for: .pauli,
                time: 1,
                isWalking: walking
            ) == 0)
        }
    }

    private func expectFinitePose(_ pose: PetAnimationPose) {
        #expect(pose.x.isFinite)
        #expect(pose.y.isFinite)
        #expect(pose.scale.isFinite)
        #expect(pose.tiltDegrees.isFinite)
    }

    private func longestRun(in samples: [Bool]) -> Int {
        var longest = 0
        var current = 0
        for sample in samples {
            current = sample ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}

@Suite("Pet animation polish")
struct PetAnimationPolishTests {
    @Test("blink envelope is a smooth bounded cycle")
    func blinkEnvelopeIsSmoothAndBounded() {
        for pet in PetKind.allCases {
            var sawClosure = false
            var previous = 0.0
            for time in stride(from: 0.0, through: 30.0, by: 0.01) {
                let phase = PetAnimationDynamics.blinkEnvelope(for: pet, time: time)
                #expect(phase.isFinite)
                #expect((0...1).contains(phase))
                if phase > 0.9 { sawClosure = true }
                #expect(abs(phase - previous) < 0.4)
                previous = phase
            }
            #expect(sawClosure)
        }
        #expect(PetAnimationDynamics.blinkEnvelope(for: .cat, time: .nan) == 0)
    }

    @Test("blink flag fires exactly when the envelope is mostly closed")
    func blinkFlagMatchesEnvelope() {
        for pet in PetKind.allCases {
            for time in stride(from: 0.0, through: 25.0, by: 0.017) {
                let flag = PetAnimationDynamics.isBlinking(for: pet, time: time)
                let phase = PetAnimationDynamics.blinkEnvelope(for: pet, time: time)
                #expect(flag == (phase > 0.5))
            }
        }
    }

    @Test("pat settle decays back to neutral")
    func patSettleDecaysToNeutral() {
        for pet in PetKind.allCases {
            #expect(PetAnimationDynamics.patSettlePose(
                for: pet,
                elapsed: 0,
                comboCount: 1
            ) == .neutral)
            #expect(PetAnimationDynamics.patSettlePose(
                for: pet,
                elapsed: .nan,
                comboCount: 1
            ) == .neutral)

            var sawWobble = false
            for elapsed in stride(from: 0.01, through: 2.0, by: 0.01) {
                let pose = PetAnimationDynamics.patSettlePose(
                    for: pet,
                    elapsed: elapsed,
                    comboCount: 3
                )
                #expect(pose.x.isFinite)
                #expect(pose.y.isFinite)
                #expect(pose.scale.isFinite)
                #expect(pose.tiltDegrees.isFinite)
                #expect(abs(pose.x) <= 2.5)
                #expect(abs(pose.tiltDegrees) <= 3.5)
                if abs(pose.tiltDegrees) > 0.3 { sawWobble = true }
            }
            #expect(sawWobble)
            #expect(PetAnimationDynamics.patSettlePose(
                for: pet,
                elapsed: 2.0,
                comboCount: 3
            ) == .neutral)
        }
    }

    @Test("pat settle scales with combo energy")
    func patSettleScalesWithCombo() {
        for pet in PetKind.allCases {
            let soft = settlePeak(pet: pet, comboCount: 1)
            let celebration = settlePeak(pet: pet, comboCount: 5)
            #expect(celebration > soft)
        }
    }

    @Test("dance hops squash on landing")
    func danceSquashesOnLanding() {
        for pet in PetKind.allCases {
            var lowestScale = Double.greatestFiniteMagnitude
            for elapsed in stride(from: 0.05, through: 1.75, by: 0.01) {
                let pose = PetAnimationDynamics.dancePose(for: pet, elapsed: elapsed)
                lowestScale = min(lowestScale, pose.scale)
            }
            #expect(lowestScale < 1)
        }
    }

    @Test("nuzzle purr stays within the established bounds")
    func nuzzlePurrStaysBounded() {
        for pet in PetKind.allCases {
            for elapsed in stride(from: 0.01, through: 10.0, by: 0.05) {
                let pose = PetAnimationDynamics.nuzzlePose(for: pet, elapsed: elapsed)
                #expect(abs(pose.x) <= 1)
                #expect(abs(pose.tiltDegrees) <= 2)
                #expect(abs(pose.scale - 1) <= 0.03)
            }
        }
    }

    private func settlePeak(pet: PetKind, comboCount: Int) -> Double {
        var peak = 0.0
        for elapsed in stride(from: 0.01, through: 1.0, by: 0.01) {
            let pose = PetAnimationDynamics.patSettlePose(
                for: pet,
                elapsed: elapsed,
                comboCount: comboCount
            )
            peak = max(peak, abs(pose.tiltDegrees))
        }
        return peak
    }
}

@Suite("Pet motion director")
struct PetMotionDirectorTests {
    @Test("scheduled motion includes three additional gestures")
    func scheduledMotionHasExpandedVocabulary() {
        var observed = Set<PetMotionEvent>()

        for pet in PetKind.allCases {
            for seed in 0...60 {
                for time in stride(from: 0.0, through: 180.0, by: 0.08) {
                    observed.insert(PetMotionDirector.frame(
                        pet: pet,
                        time: time,
                        seed: seed,
                        isEligible: true,
                        reduceMotion: false
                    ).event)
                }
            }
        }

        #expect(observed.contains(.lookAround))
        #expect(observed.contains(.stretch))
        #expect(observed.contains(.perkUp))
    }

    @Test("new gestures ease from neutral and loop cleanly")
    func gesturePreviewsEaseCleanly() {
        for pet in PetKind.allCases {
            for event in [
                PetMotionEvent.lookAround,
                .stretch,
                .perkUp,
            ] {
                let duration = PetMotionDirector.eventDuration(for: event, pet: pet)
                let start = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: 0,
                    reduceMotion: false
                )
                let middle = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: duration * 0.5,
                    reduceMotion: false
                )
                let looped = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: duration,
                    reduceMotion: false
                )

                #expect(start.event == event)
                #expect(start.horizontalOffset == 0)
                #expect(start.verticalOffset == 0)
                #expect(start.horizontalScale == 1)
                #expect(start.verticalScale == 1)
                #expect(middle != start)
                expectFiniteTransforms(middle)
                expectEquivalentMotion(start, looped)
            }
        }
    }

    @Test("idle intervals stay lively without becoming distracting")
    func idleIntervalsStayBounded() {
        for pet in PetKind.allCases {
            for seed in 0...100 {
                let cadence = PetMotionDirector.cadence(for: pet, seed: seed)
                #expect(cadence.idleDuration >= 9)
                #expect(cadence.idleDuration <= 22)
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
                case .lookAround, .stretch, .perkUp:
                    #expect(frame.artworkFrameIndex == nil)
                    #expect(frame.stepCount == 0)
                    #expect(frame.eventProgress >= 0)
                    #expect(frame.eventProgress < 1)
                    #expect(abs(frame.horizontalOffset) <= 1.5)
                    #expect(abs(frame.verticalOffset) <= 2.5)
                    #expect(abs(frame.tiltDegrees) <= 3)
                    #expect((0.97...1.03).contains(frame.horizontalScale))
                    #expect((0.97...1.03).contains(frame.verticalScale))
                    #expect((0.94...1.05).contains(frame.shadowScale))
                    #expect(abs(frame.shadowOffset) <= 0.9)
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

    @Test("walk cadence stays at a relaxed natural pace")
    func walkCadenceStaysRelaxed() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            #expect((1.0...1.2).contains(cadence.stepsPerSecond))
            #expect(abs(
                cadence.artworkFramesPerSecond - cadence.stepsPerSecond * 6
            ) < 0.000_001)
        }
    }

    @Test("look around turns ease into readable holds")
    func lookAroundHasReadableHolds() {
        for pet in PetKind.allCases {
            let duration = PetMotionDirector.eventDuration(for: .lookAround, pet: pet)
            let firstArrival = PetMotionDirector.previewFrame(
                pet: pet,
                event: .lookAround,
                time: duration * 0.18,
                reduceMotion: false
            )
            let firstHold = PetMotionDirector.previewFrame(
                pet: pet,
                event: .lookAround,
                time: duration * 0.28,
                reduceMotion: false
            )
            let center = PetMotionDirector.previewFrame(
                pet: pet,
                event: .lookAround,
                time: duration * 0.52,
                reduceMotion: false
            )

            #expect(abs(firstArrival.tiltDegrees - firstHold.tiltDegrees) < 0.05)
            #expect(abs(firstHold.tiltDegrees) >= 1)
            #expect(abs(center.tiltDegrees) < 0.01)
        }
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

    @Test("every production step count eases through the walk-six landing frame")
    func productionWalksEaseBeforeReturningToIdle() {
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
            #expect(abs(settlingFrame.horizontalOffset) < abs(precedingFrame.horizontalOffset))
            #expect(abs(settlingFrame.verticalOffset) < abs(precedingFrame.verticalOffset))
            #expect(abs(settlingFrame.tiltDegrees) < abs(precedingFrame.tiltDegrees))
            #expect(abs(settlingFrame.shadowScale - 1) < abs(precedingFrame.shadowScale - 1))
            #expect(abs(settlingFrame.shadowOffset) < abs(precedingFrame.shadowOffset))
            #expect(atCompletion == .idle)
        }
    }

    @Test("walk transforms flow continuously into the landing frame")
    func walkLandingIsContinuous() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            let duration = 4 / cadence.stepsPerSecond
            let oldLandingBoundary = duration - 1 / cadence.artworkFramesPerSecond
            let before = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: oldLandingBoundary - 0.000_001,
                reduceMotion: false
            )
            let after = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: oldLandingBoundary + 0.000_001,
                reduceMotion: false
            )

            #expect(abs(before.horizontalOffset - after.horizontalOffset) < 0.01)
            #expect(abs(before.verticalOffset - after.verticalOffset) < 0.01)
            #expect(abs(before.tiltDegrees - after.tiltDegrees) < 0.01)
            #expect(abs(before.horizontalScale - after.horizontalScale) < 0.01)
            #expect(abs(before.verticalScale - after.verticalScale) < 0.01)
        }
    }

    @Test("walk transition timing presents one gait frame at a time")
    func walkArtworkUsesSingleTransitionFrame() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            let frameDuration = 1 / cadence.artworkFramesPerSecond
            let early = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: frameDuration * 0.55,
                reduceMotion: false
            )
            let late = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: frameDuration * 0.90,
                reduceMotion: false
            )

            #expect(early.artworkFrameIndex == 0)
            #expect(early.nextArtworkFrameIndex == 1)
            #expect(early.artworkBlend == 0)
            #expect(!early.usesEventArtwork)
            #expect(early.presentedArtworkFrameIndex == nil)
            #expect(late.artworkFrameIndex == 0)
            #expect(late.nextArtworkFrameIndex == 1)
            #expect(late.artworkBlend > 0)
            #expect(late.artworkBlend < 1)
            #expect(late.usesEventArtwork)
            #expect(late.presentedArtworkFrameIndex == 1)
        }
    }

    @Test("events select the base pose at both boundaries")
    func eventArtworkUsesBaseAtBoundaries() {
        for pet in PetKind.allCases {
            let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
            let walkDuration = 4 / cadence.stepsPerSecond
            let walkStart = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: 0,
                reduceMotion: false
            )
            let walkMiddle = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: walkDuration * 0.5,
                reduceMotion: false
            )
            let walkEnd = PetMotionDirector.previewFrame(
                pet: pet,
                event: .walk,
                time: walkDuration - 0.000_1,
                reduceMotion: false
            )

            #expect(walkStart.artworkOpacity == 0)
            #expect(walkMiddle.artworkOpacity == 1)
            #expect(walkEnd.artworkOpacity < 0.01)
            #expect(!walkStart.usesEventArtwork)
            #expect(walkMiddle.usesEventArtwork)
            #expect(!walkEnd.usesEventArtwork)

            for event in [
                PetMotionEvent.idleAction1,
                .idleAction2,
                .lookAround,
                .stretch,
                .perkUp,
            ] {
                let duration = PetMotionDirector.eventDuration(for: event, pet: pet)
                let start = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: 0,
                    reduceMotion: false
                )
                let middle = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: duration * 0.5,
                    reduceMotion: false
                )
                let end = PetMotionDirector.previewFrame(
                    pet: pet,
                    event: event,
                    time: duration - 0.000_1,
                    reduceMotion: false
                )

                #expect(start.artworkOpacity == 0)
                #expect(middle.artworkOpacity == 1)
                #expect(end.artworkOpacity < 0.01)
            }
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

        let nextBurstStart = 16.0
        let elapsedBeforeBurst = cadence.idleDuration - 0.28
        clock.updateEligibility(
            true,
            at: nextBurstStart - elapsedBeforeBurst
        )

        let candidate = PetMotionDirector.frame(
            pet: pet,
            time: clock.elapsed(at: nextBurstStart),
            seed: seed,
            isEligible: true,
            reduceMotion: false
        )
        #expect(candidate == .idle)
        #expect(abs(
            clock.elapsed(at: nextBurstStart) - elapsedBeforeBurst
        ) < 0.000_000_001)
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
        #expect(abs(
            clock.elapsed(at: nextBurstEnd) - elapsedBeforeBurst
        ) < 0.000_000_001)
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
        let cycleDuration = cadence.idleDuration
            + PetMotionDirector.eventWindowDuration

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
        let cycleDuration = cadence.idleDuration
            + PetMotionDirector.eventWindowDuration
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
            frame.horizontalScale,
            frame.verticalScale,
            frame.artworkBlend,
            frame.artworkOpacity,
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
        #expect(abs(first.horizontalScale - second.horizontalScale) < 0.000_000_001)
        #expect(abs(first.verticalScale - second.verticalScale) < 0.000_000_001)
        #expect(first.nextArtworkFrameIndex == second.nextArtworkFrameIndex)
        #expect(abs(first.artworkBlend - second.artworkBlend) < 0.000_000_001)
        #expect(abs(first.artworkOpacity - second.artworkOpacity) < 0.000_000_001)
        #expect(abs(first.shadowScale - second.shadowScale) < 0.000_000_001)
        #expect(abs(first.shadowOffset - second.shadowOffset) < 0.000_000_001)
    }

    private func extremeEventTime(
        startingAt initialValue: Double,
        movingPositive: Bool,
        cadence: PetMotionCadence
    ) -> Double? {
        let cycleDuration = cadence.idleDuration
            + PetMotionDirector.eventWindowDuration
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
        #expect(dogMoments.count == 15)
        #expect(Set(dogMoments.map(\.id)).count == 15)
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

    @Test("catalog contains fifteen unique moments for each pet and three per category")
    func catalogShape() {
        let moments = PersonalityMomentCatalog.all

        for pet in PetKind.allCases {
            let petMoments = moments.filter { $0.petKind == pet }

            #expect(petMoments.count == 15)
            #expect(Set(petMoments.map(\.id)).count == 15)
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

    @Test("treat requests select a playful pet-specific response")
    func treatSelection() {
        for pet in PetKind.allCases {
            let context = PersonalityMomentContext(
                petKind: pet,
                mood: .cozy,
                workProgress: 0,
                requestedCategory: .treat,
                isPresentationBlocked: false
            )
            let selected = PersonalityMomentSelector.select(
                from: PersonalityMomentCatalog.all,
                context: context,
                excluding: [],
                roll: 1
            )

            #expect(selected?.petKind == pet)
            #expect(selected?.category == .treat)
        }
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

@Suite("Storm lightning schedule")
struct StormLightningScheduleTests {
    @Test("flash intensity stays bounded and deterministic")
    func intensityIsBoundedAndDeterministic() {
        for time in stride(from: -50.0, through: 500.0, by: 0.013) {
            let first = StormLightningSchedule.flashIntensity(at: time, period: 24)
            let second = StormLightningSchedule.flashIntensity(at: time, period: 24)
            #expect(first == second)
            #expect((0...StormLightningSchedule.peakIntensity).contains(first))
        }
    }

    @Test("flashes fire at irregular offsets across cycles")
    func flashesAreIrregular() {
        var onsets = Set<Int>()
        for cycle in 0..<6 {
            let start = Double(cycle) * 24
            for step in 0..<2400 {
                let time = start + Double(step) * 0.01
                if StormLightningSchedule.flashIntensity(at: time, period: 24) > 0 {
                    onsets.insert(step)
                    break
                }
            }
        }
        #expect(onsets.count > 1)
    }

    @Test("every cycle has both a flash and quiet gaps")
    func cyclesHaveFlashAndQuiet() {
        for cycle in 0..<4 {
            let start = Double(cycle) * 24
            var sawFlash = false
            var sawQuiet = false
            for step in 0..<2400 {
                let value = StormLightningSchedule.flashIntensity(
                    at: start + Double(step) * 0.01,
                    period: 24
                )
                if value > 0 {
                    sawFlash = true
                } else {
                    sawQuiet = true
                }
            }
            #expect(sawFlash)
            #expect(sawQuiet)
        }
    }

    @Test("bolt variants stay in range deterministic and varied")
    func boltVariants() {
        for time in stride(from: 0.0, through: 300.0, by: 0.7) {
            let first = StormLightningSchedule.boltVariant(
                at: time,
                period: 24,
                variantCount: 3
            )
            let second = StormLightningSchedule.boltVariant(
                at: time,
                period: 24,
                variantCount: 3
            )
            #expect(first == second)
            #expect((0..<3).contains(first.index))
        }
        var seen = Set<Int>()
        for cycle in 0..<9 {
            seen.insert(
                StormLightningSchedule.boltVariant(
                    at: Double(cycle) * 24 + 0.5,
                    period: 24,
                    variantCount: 3
                ).index
            )
        }
        #expect(seen.count > 1)
    }

    @Test("non finite inputs are safe")
    func nonFiniteIsSafe() {
        #expect(StormLightningSchedule.flashIntensity(at: .nan, period: 24) == 0)
        #expect(StormLightningSchedule.flashIntensity(at: 1, period: .infinity) == 0)
        #expect(StormLightningSchedule.flashIntensity(at: 1, period: 0) == 0)
        #expect(StormLightningSchedule.flashIntensity(at: 1, period: -4) == 0)
        let variant = StormLightningSchedule.boltVariant(
            at: .nan,
            period: 24,
            variantCount: 3
        )
        #expect(variant.index == 0)
        #expect(!variant.mirrored)
    }
}

@Suite("Drag lean tracker")
struct DragLeanTrackerTests {
    @Test("no movement stays neutral")
    func noMovementIsNeutral() {
        let tracker = DragLeanTracker()
        #expect(tracker.lean(at: 10) == .neutral)
    }

    @Test("movement produces a bounded lean that decays to neutral")
    func leanDecays() {
        var tracker = DragLeanTracker()
        for index in 0..<10 {
            tracker.recordWindowOrigin(
                x: Double(index) * 40,
                y: 0,
                at: Double(index) * 0.016
            )
        }
        let duringDrag = tracker.lean(at: 10 * 0.016)
        #expect(duringDrag != .neutral)
        #expect(abs(duringDrag.tiltDegrees) <= 6.5)
        #expect(abs(duringDrag.offsetX) <= 4)
        #expect(abs(duringDrag.offsetY) <= 3)

        let settled = tracker.lean(at: 10 * 0.016 + 5)
        #expect(settled == .neutral)
    }

    @Test("lean trails the drag direction")
    func leanDirection() {
        var right = DragLeanTracker()
        for index in 0..<8 {
            right.recordWindowOrigin(
                x: Double(index) * 60,
                y: 0,
                at: Double(index) * 0.016
            )
        }
        #expect(right.lean(at: 8 * 0.016).tiltDegrees < 0)

        var left = DragLeanTracker()
        for index in 0..<8 {
            left.recordWindowOrigin(
                x: -Double(index) * 60,
                y: 0,
                at: Double(index) * 0.016
            )
        }
        #expect(left.lean(at: 8 * 0.016).tiltDegrees > 0)
    }

    @Test("non finite samples are ignored")
    func nonFiniteSafe() {
        var tracker = DragLeanTracker()
        tracker.recordWindowOrigin(x: .nan, y: 0, at: 0)
        tracker.recordWindowOrigin(x: 0, y: 0, at: .nan)
        #expect(tracker.lean(at: 1) == .neutral)

        tracker.recordWindowOrigin(x: 0, y: 0, at: 0)
        tracker.recordWindowOrigin(x: 100, y: 0, at: 0.5)
        let lean = tracker.lean(at: 0.5)
        #expect(lean.tiltDegrees.isFinite)
        #expect(lean.offsetX.isFinite)
        #expect(lean.offsetY.isFinite)
        #expect(tracker.lean(at: .nan) == .neutral)
    }
}

@Suite("Nuzzle pose")
struct NuzzlePoseTests {
    @Test("nuzzle starts at neutral and stays finite and bounded")
    func nuzzleBounds() {
        #expect(PetAnimationDynamics.nuzzlePose(for: .cat, elapsed: 0) == .neutral)
        #expect(PetAnimationDynamics.nuzzlePose(for: .dog, elapsed: -1) == .neutral)
        #expect(
            PetAnimationDynamics.nuzzlePose(for: .pauli, elapsed: .nan) == .neutral
        )
        for pet in PetKind.allCases {
            for elapsed in stride(from: 0.01, through: 30.0, by: 0.37) {
                let pose = PetAnimationDynamics.nuzzlePose(
                    for: pet,
                    elapsed: elapsed
                )
                #expect(pose.x.isFinite)
                #expect(pose.y.isFinite)
                #expect(pose.scale.isFinite)
                #expect(pose.tiltDegrees.isFinite)
                #expect(abs(pose.x) <= 1)
                #expect(abs(pose.tiltDegrees) <= 2)
                #expect(abs(pose.scale - 1) <= 0.03)
            }
        }
    }

    @Test("nuzzle ramps in smoothly instead of snapping")
    func nuzzleRampsIn() {
        let early = PetAnimationDynamics.nuzzlePose(for: .cat, elapsed: 0.02)
        let settled = PetAnimationDynamics.nuzzlePose(for: .cat, elapsed: 2)
        #expect(abs(early.scale - 1) < abs(settled.scale - 1))
    }

    @Test("pose scaling interpolates toward neutral")
    func poseScaling() {
        let pose = PetAnimationPose(x: 4, y: -2, scale: 1.04, tiltDegrees: 3)
        #expect(pose.scaled(by: 1) == pose)
        #expect(pose.scaled(by: 0) == .neutral)
        #expect(pose.scaled(by: 2) == pose)
        #expect(pose.scaled(by: -1) == .neutral)
        #expect(pose.scaled(by: .nan) == .neutral)
        let half = pose.scaled(by: 0.5)
        #expect(abs(half.x - 2) < 0.000_001)
        #expect(abs(half.y + 1) < 0.000_001)
        #expect(abs(half.scale - 1.02) < 0.000_001)
        #expect(abs(half.tiltDegrees - 1.5) < 0.000_001)
    }
}

@Suite("Weather particle variation")
struct WeatherParticleVariationTests {
    @Test("fall speed multipliers vary within bounds")
    func fallSpeedVariance() {
        let seeds = WeatherParticleLayout.particles(
            count: 40,
            seed: 91,
            depth: .midground
        )
        let multipliers = seeds.map(\.fallSpeedMultiplier)
        for multiplier in multipliers {
            #expect((0.82...1.18).contains(multiplier))
        }
        #expect(Set(multipliers).count > 1)
    }

    @Test("snow sway is bounded deterministic and varied")
    func snowSway() {
        let seeds = WeatherParticleLayout.particles(
            count: 30,
            seed: 53,
            depth: .foreground
        )
        for time in [-100.0, 0, 3.3, 999] {
            let offsets = seeds.map { $0.swayOffset(at: time) }
            for offset in offsets {
                #expect(abs(offset) <= 0.030_000_1)
            }
            #expect(offsets == seeds.map { $0.swayOffset(at: time) })
        }
        let rounded = Set(seeds.map { ($0.swayOffset(at: 7) * 10_000).rounded() })
        #expect(rounded.count > 1)
        #expect(seeds[0].swayOffset(at: .nan) == 0)
    }

    @Test("twinkle stays in range")
    func twinkleRange() {
        let seeds = WeatherParticleLayout.particles(
            count: 20,
            seed: 77,
            depth: .background
        )
        for time in stride(from: -5.0, through: 60.0, by: 0.31) {
            for seed in seeds {
                #expect((0.8...1.0).contains(seed.twinkle(at: time)))
            }
        }
        #expect(seeds[0].twinkle(at: .infinity) == 0.9)
    }
}
