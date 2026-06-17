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
    @Test("offers explicit selectable pet kinds")
    func offersExplicitPetKinds() {
        #expect(PetKind.allCases == [.cat, .pauli])
        #expect(PetKind.cat.displayName == "Cat")
        #expect(PetKind.pauli.displayName == "Pauli")
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
