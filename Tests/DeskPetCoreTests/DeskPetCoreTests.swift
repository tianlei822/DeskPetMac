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

@Suite("Weather animation profiles")
struct WeatherAnimationProfileTests {
    @Test("particle counts stay bounded and transitions stay consistent")
    func particleCountsStayBounded() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherAnimationProfile(mood: mood)

            #expect(profile.backgroundParticleCount >= 0)
            #expect(profile.foregroundParticleCount >= 0)
            #expect(profile.backgroundParticleCount + profile.foregroundParticleCount <= 16)
            #expect(profile.transitionDuration == 0.6)
        }
    }

    @Test("ground ripples and lightning stay limited to applicable moods")
    func weatherEffectsStayLimitedToApplicableMoods() {
        for mood in PetWeatherMood.allCases {
            let profile = WeatherAnimationProfile(mood: mood)

            #expect(profile.showsGroundRipple == (mood == .rainy || mood == .stormy))
            #expect(profile.supportsLightning == (mood == .stormy))

            if mood == .stormy {
                #expect(profile.lightningPeriod == 22)
            } else {
                #expect(profile.lightningPeriod == nil)
            }
        }
    }

    @Test("rain and storms preserve character-specific reactions")
    func weatherReactionsStayCharacterSpecific() {
        #expect(WeatherAnimationProfile.reaction(for: .cat, mood: .rainy) == .shelter)
        #expect(WeatherAnimationProfile.reaction(for: .pauli, mood: .rainy) == .visorGlow)
        #expect(WeatherAnimationProfile.reaction(for: .dog, mood: .rainy) == .shake)
        #expect(WeatherAnimationProfile.reaction(for: .cat, mood: .stormy) == .startle)
        #expect(WeatherAnimationProfile.reaction(for: .pauli, mood: .stormy) == .antennaGlow)
        #expect(WeatherAnimationProfile.reaction(for: .dog, mood: .stormy) == .startle)
    }

    @Test("every pet and mood combination has a reaction")
    func everyPetAndMoodHasAReaction() {
        for petKind in PetKind.allCases {
            for mood in PetWeatherMood.allCases {
                #expect(WeatherAnimationProfile.reaction(for: petKind, mood: mood) != .none)
            }
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
