import DeskPetCore
import Foundation

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var weather = WeatherSnapshot.placeholder
    @Published private(set) var breakState = BreakReminderState(activeSeconds: 0, lastReminderAt: nil, snoozedUntil: nil)
    @Published private(set) var isReminderVisible = false
    @Published private(set) var affectionPulse = 0
    @Published private(set) var isRefreshingWeather = false
    @Published private(set) var isStatusVisible = false
    @Published private(set) var petKind: PetKind = .cat
    @Published private(set) var bond = PetBond()
    @Published private(set) var isSleeping = false
    @Published private(set) var isDancing = false
    @Published private(set) var comboCount = 0
    @Published private(set) var heartBurst = 0
    @Published var isPetPickerVisible = false
    @Published var isSettingsVisible = false
    @Published var reminderMinutes = 60.0 {
        didSet { defaults.set(reminderMinutes, forKey: StoreKey.reminderMinutes) }
    }

    private let locationService = LocationService()
    private let weatherService = WeatherService()
    private let idleMonitor = IdleMonitor()
    private let notifications = BreakNotificationService()
    private let workTracker = WorkSessionTracker()
    private let defaults = UserDefaults.standard
    private var sessionState = WorkSessionState(activeSeconds: 0, lastObservedAt: Date())
    private var monitorTask: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var danceTask: Task<Void, Never>?
    private var comboResetTask: Task<Void, Never>?
    private var statusRevealToken = 0
    private var lastPatAt: Date?

    private let comboWindow: TimeInterval = 1.4
    private let sleepIdleThreshold: TimeInterval = 90

    private enum StoreKey {
        static let petKind = "deskpet.petKind"
        static let reminderMinutes = "deskpet.reminderMinutes"
        static let bond = "deskpet.bond"
    }

    init() {
        loadPersistedState()
    }

    var mood: PetWeatherMood {
        weather.mood
    }

    var activeMinutes: Int {
        breakState.activeSeconds / 60
    }

    var workProgress: Double {
        min(1, Double(breakState.activeSeconds) / (reminderMinutes * 60))
    }

    var bondTitle: String { bond.level.title }

    var bondHearts: Int { bond.level.hearts }

    var bondProgress: Double { bond.levelProgress }

    func start() async {
        await notifications.requestAuthorization()
        sessionState = workTracker.start()
        startWorkMonitor()
        startSleepMonitor()
        startWeatherLoop()
        await refreshWeather()
    }

    func refreshWeather() async {
        revealStatusBriefly()
        isRefreshingWeather = true
        defer {
            isRefreshingWeather = false
            revealStatusBriefly()
        }

        guard let place = await locationService.requestCurrentPlace() else {
            weather = .placeholder
            return
        }

        do {
            weather = try await weatherService.currentWeather(for: place)
        } catch {
            weather = WeatherSnapshot(
                conditionCode: nil,
                temperatureCelsius: nil,
                locationName: place.name
            )
        }
    }

    func pat() {
        wake()
        let now = Date()
        if let last = lastPatAt, now.timeIntervalSince(last) <= comboWindow {
            comboCount = min(comboCount + 1, 99)
        } else {
            comboCount = 1
        }
        lastPatAt = now

        bond.registerPat(comboMultiplier: comboCount)
        persistBond()

        affectionPulse += 1
        heartBurst += 1
        isReminderVisible = false
        scheduleComboReset()
        revealStatusBriefly()
    }

    func dance() {
        wake()
        bond.registerPlay()
        persistBond()

        affectionPulse += 1
        heartBurst += 1
        isDancing = true
        revealStatusBriefly()

        danceTask?.cancel()
        danceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            self?.isDancing = false
        }
    }

    func takeBreak() {
        let policy = currentReminderPolicy()
        breakState = policy.markBreakTaken(state: breakState)
        sessionState = workTracker.start()
        isReminderVisible = false
        revealStatusBriefly()
    }

    func snoozeBreak() {
        let policy = currentReminderPolicy()
        breakState = policy.snooze(state: breakState)
        isReminderVisible = false
    }

    func toggleSettings() {
        isSettingsVisible.toggle()
        revealStatusBriefly()
    }

    func selectPetKind(_ kind: PetKind) {
        guard petKind != kind else {
            isPetPickerVisible = false
            revealStatusBriefly()
            return
        }
        petKind = kind
        defaults.set(kind.rawValue, forKey: StoreKey.petKind)
        isPetPickerVisible = false
        affectionPulse += 1
        revealStatusBriefly()
    }

    private func wake() {
        if isSleeping { isSleeping = false }
    }

    private func scheduleComboReset() {
        comboResetTask?.cancel()
        comboResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            self?.comboCount = 0
        }
    }

    private func startSleepMonitor() {
        sleepTask?.cancel()
        sleepTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                let sleeping = self.idleMonitor.idleSeconds() >= self.sleepIdleThreshold
                if sleeping != self.isSleeping {
                    self.isSleeping = sleeping
                }
            }
        }
    }

    private func startWorkMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.recordWorkObservation()
            }
        }
    }

    private func startWeatherLoop() {
        weatherTask?.cancel()
        weatherTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20 * 60))
                await self?.refreshWeather()
            }
        }
    }

    private func recordWorkObservation() {
        sessionState = workTracker.recordObservation(
            previous: sessionState,
            idleSeconds: idleMonitor.idleSeconds()
        )

        var candidate = BreakReminderState(
            activeSeconds: sessionState.activeSeconds,
            lastReminderAt: breakState.lastReminderAt,
            snoozedUntil: breakState.snoozedUntil
        )
        let policy = currentReminderPolicy()

        if policy.shouldRemind(state: candidate) {
            candidate = policy.markReminderShown(state: candidate)
            isReminderVisible = true
            notifications.showBreakReminder()
        }

        breakState = candidate
    }

    private func currentReminderPolicy() -> BreakReminderPolicy {
        BreakReminderPolicy(reminderInterval: reminderMinutes * 60, snoozeInterval: 10 * 60)
    }

    private func loadPersistedState() {
        if let raw = defaults.string(forKey: StoreKey.petKind), let kind = PetKind(rawValue: raw) {
            petKind = kind
        }
        let savedMinutes = defaults.double(forKey: StoreKey.reminderMinutes)
        if savedMinutes >= 20, savedMinutes <= 90 {
            reminderMinutes = savedMinutes
        }
        if let data = defaults.data(forKey: StoreKey.bond),
           let saved = try? JSONDecoder().decode(PetBond.self, from: data) {
            bond = saved
        }
    }

    private func persistBond() {
        if let data = try? JSONEncoder().encode(bond) {
            defaults.set(data, forKey: StoreKey.bond)
        }
    }

    private func revealStatusBriefly() {
        statusRevealToken += 1
        let token = statusRevealToken
        isStatusVisible = true

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if self.statusRevealToken == token, !self.isSettingsVisible, !self.isRefreshingWeather {
                self.isStatusVisible = false
            }
        }
    }
}
