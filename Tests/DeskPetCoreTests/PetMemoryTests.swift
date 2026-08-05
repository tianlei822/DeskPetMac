import Foundation
import Testing
@testable import DeskPetCore

@Suite("Pet memory")
struct PetMemoryTests {
    @Test("memories remain isolated per pet")
    func memoriesRemainIsolated() {
        var collection = PetMemoryCollection()
        var cat = collection[.cat]
        cat.updateBond(PetBond(points: 42, totalPats: 9))
        cat.setLearnedName("Mikan")
        cat.recordInteraction(.pat, at: Date(timeIntervalSince1970: 3_600))
        collection[.cat] = cat

        #expect(collection[.cat].bond.points == 42)
        #expect(collection[.cat].learnedName == "Mikan")
        #expect(collection[.cat].preferredInteraction == .pat)
        #expect(collection[.dog].bond.points == 0)
        #expect(collection[.dog].learnedName == nil)
    }

    @Test("preference follows repeated interaction with deterministic ties")
    func preferenceReflectsInteractionHistory() {
        var memory = PetMemory()
        memory.recordInteraction(.pat, at: Date(timeIntervalSince1970: 0))
        memory.recordInteraction(.boop, at: Date(timeIntervalSince1970: 1))
        memory.recordInteraction(.boop, at: Date(timeIntervalSince1970: 2))

        #expect(memory.preferredInteraction == .boop)
        #expect(memory.familiarity > 0)
        #expect(memory.dailyRhythm.reduce(0, +) == 3)
    }

    @Test("recent moments are unique and bounded")
    func recentMomentsStayBounded() {
        var memory = PetMemory()
        for index in 0..<10 {
            memory.recordMoment("moment-\(index)")
        }
        memory.recordMoment("moment-9")

        #expect(memory.recentMomentIDs.count == 6)
        #expect(memory.recentMomentIDs.last == "moment-9")
        #expect(Set(memory.recentMomentIDs).count == 6)
    }

    @Test("memory collection survives Codable persistence")
    func collectionRoundTrips() throws {
        var collection = PetMemoryCollection()
        var pauli = collection[.pauli]
        pauli.updateBond(PetBond(points: 73, totalPats: 12))
        pauli.recordInteraction(.toy, at: Date(timeIntervalSince1970: 7_200))
        pauli.markSeen(
            at: Date(timeIntervalSince1970: 9_000),
            mood: .stormy
        )
        collection[.pauli] = pauli

        let data = try JSONEncoder().encode(collection)
        let restored = try JSONDecoder().decode(
            PetMemoryCollection.self,
            from: data
        )

        #expect(restored == collection)
    }

    @Test("greeting changes with time apart")
    func greetingReflectsTimeApart() {
        let now = Date(timeIntervalSince1970: 10 * 24 * 60 * 60)
        #expect(PetMemory.greeting(
            lastSeenAt: now.addingTimeInterval(-30 * 60),
            now: now
        ) == .returningSoon)
        #expect(PetMemory.greeting(
            lastSeenAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            now: now
        ) == .welcomeBack)
        #expect(PetMemory.greeting(
            lastSeenAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
            now: now
        ) == .longTimeNoSee)
    }

    @Test("daily rhythm recognizes a familiar interaction hour")
    func dailyRhythmFindsFamiliarHour() {
        var rhythm = Array(repeating: 0, count: 24)
        rhythm[8] = 3
        rhythm[9] = 12
        rhythm[10] = 4
        let memory = PetMemory(dailyRhythm: rhythm)

        #expect(memory.rhythmAffinity(atHour: 9) > 0.7)
        #expect(memory.rhythmAffinity(atHour: 9) > memory.rhythmAffinity(atHour: 18))
        #expect(memory.rhythmAffinity(atHour: -100).isFinite)
    }
}
