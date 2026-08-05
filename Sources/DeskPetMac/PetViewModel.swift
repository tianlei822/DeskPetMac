import AppKit
import DeskPetCore
import Foundation

@MainActor
final class PetViewModel: ObservableObject {
  @Published private(set) var weather = WeatherSnapshot.placeholder
  @Published private(set) var breakState = BreakReminderState(
    activeSeconds: 0, lastReminderAt: nil, snoozedUntil: nil)
  @Published private(set) var isReminderVisible = false
  @Published private(set) var breakRitualPhase = PetBreakRitualPhase.idle
  @Published private(set) var affectionPulse = 0
  @Published private(set) var isRefreshingWeather = false
  @Published private(set) var isStatusVisible = false
  @Published private(set) var petKind: PetKind = .cat
  @Published private(set) var bond = PetBond()
  @Published private(set) var isSleeping = false
  @Published private(set) var wakeRitualPhase: PetWakeRitualPhase?
  @Published private(set) var isDancing = false
  @Published private(set) var isScratching = false
  @Published private(set) var scratchRegion: PetScratchRegion?
  @Published private(set) var swipeDirection: PetSwipeDirection?
  @Published private(set) var swipeIntensity = 0.0
  @Published private(set) var comboCount = 0
  @Published private(set) var heartBurst = 0
  @Published private(set) var treatJourneyFrame: PetTreatJourneyFrame?
  @Published private(set) var activePersonalityMoment: PersonalityMoment?
  @Published private(set) var isNuzzling = false
  @Published private(set) var autonomyState = PetAutonomyState.neutral
  @Published private(set) var bubblePlacement = PetBubblePlacement.center
  @Published private(set) var isPetWindowVisible = true
  @Published private(set) var rootMotionRequest: PetRootMotionRequest?
  @Published private(set) var rootMotionFrame: PetRootMotionFrame?
  @Published private(set) var interactionCallout: String?
  @Published private(set) var activeToyKind: PetToyKind?
  @Published private(set) var toyPosition = CGPoint(x: 0.72, y: 0.46)
  @Published private(set) var learnedName = ""
  @Published var reminderMinutes = 60.0 {
    didSet { defaults.set(reminderMinutes, forKey: StoreKey.reminderMinutes) }
  }
  @Published var isSoundEnabled = PetSoundPreference.defaultEnabled {
    didSet {
      defaults.set(isSoundEnabled, forKey: StoreKey.soundEnabled)
      if !isSoundEnabled {
        soundPlayer.stop()
      }
    }
  }
  @Published var isQuietModeEnabled = false {
    didSet {
      defaults.set(isQuietModeEnabled, forKey: StoreKey.quietMode)
      guard isQuietModeEnabled else { return }
      cancelRootMotion()
      cancelBreakReminderRitual()
      clearPersonalityMoment()
      isStatusVisible = false
      soundPlayer.stop()
    }
  }

  private let locationService = LocationService()
  private let weatherService = WeatherService()
  private let idleMonitor = IdleMonitor()
  private let notifications = BreakNotificationService()
  private let workTracker = WorkSessionTracker()
  private let soundPlayer: any PetSoundPlaying
  private let hapticPlayer: any PetHapticFeedbackPlaying
  private let defaults: UserDefaults
  private let isRunningDiagnosticInteractions: Bool
  private let reminderStretchDuration: Duration
  private let postsReminderNotifications: Bool
  private let wakeRitualTiming: PetWakeRitualTiming
  private let wakeReduceMotionProvider: () -> Bool
  private var startupGate = PetStartupGate()
  private var sessionState = WorkSessionState(activeSeconds: 0, lastObservedAt: Date())
  private var monitorTask: Task<Void, Never>?
  private var reminderPresentationTask: Task<Void, Never>?
  private var weatherTask: Task<Void, Never>?
  private var sleepTask: Task<Void, Never>?
  private var wakeRitualTask: Task<Void, Never>?
  private var danceTask: Task<Void, Never>?
  private var scratchTask: Task<Void, Never>?
  private var swipeTask: Task<Void, Never>?
  private var treatJourneyTask: Task<Void, Never>?
  private var comboResetTask: Task<Void, Never>?
  private var personalityScheduleTask: Task<Void, Never>?
  private var personalityDismissTask: Task<Void, Never>?
  private var greetingTask: Task<Void, Never>?
  private var nuzzleTask: Task<Void, Never>?
  private var autonomyTask: Task<Void, Never>?
  private var interactionCalloutTask: Task<Void, Never>?
  private var toyMotionTask: Task<Void, Never>?
  private var diagnosticInteractionTask: Task<Void, Never>?
  private var petMemories = PetMemoryCollection()
  private var pendingStartupGreeting: PetGreeting?
  private var recentPersonalityMomentIDs: [String] = []
  private var lastRelationshipCueAt: Date?
  private var statusRevealToken = 0
  private var lastPatAt: Date?
  private var lastInteractionAt = Date()
  private var dragLeanTracker = DragLeanTracker()
  private let cursorTracker = CursorTracker()
  private var windowMoveObserver: NSObjectProtocol?

  private let comboWindow: TimeInterval = 1.8
  private let comboResetDelay: TimeInterval = 2.2
  private let sleepIdleThreshold: TimeInterval = 90

  private enum StoreKey {
    static let petKind = "deskpet.petKind"
    static let reminderMinutes = "deskpet.reminderMinutes"
    static let bond = "deskpet.bond"
    static let quietMode = "deskpet.quietMode"
    static let memories = "deskpet.memories"
    static let soundEnabled = "deskpet.soundEnabled"
  }

  init(
    defaults: UserDefaults = .standard,
    reminderStretchDuration: Duration = .seconds(1.2),
    postsReminderNotifications: Bool = true,
    wakeRitualTiming: PetWakeRitualTiming = .standard,
    wakeReduceMotionProvider: @escaping () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    },
    soundPlayer: any PetSoundPlaying = PetSoundPlayer(),
    hapticPlayer: any PetHapticFeedbackPlaying = PetHapticFeedbackPlayer()
  ) {
    self.defaults = defaults
    self.reminderStretchDuration = reminderStretchDuration
    self.postsReminderNotifications = postsReminderNotifications
    self.wakeRitualTiming = wakeRitualTiming
    self.wakeReduceMotionProvider = wakeReduceMotionProvider
    self.soundPlayer = soundPlayer
    self.hapticPlayer = hapticPlayer
    self.isRunningDiagnosticInteractions =
      DeskPetDiagnosticOverrides
      .interactionLoopEnabled(defaults: defaults)
    loadPersistedState()
    pendingStartupGreeting = PetMemory.greeting(
      lastSeenAt: petMemories[petKind].lastSeenAt,
      now: Date()
    )
    refreshAutonomyState()
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

  var petDisplayName: String {
    learnedName.isEmpty ? petKind.displayName : learnedName
  }

  var preferredInteractionSummary: String? {
    petMemories[petKind].preferredInteraction.map {
      "Likes \($0.displayName)"
    }
  }

  var activeActivity: PetActivity {
    PetActivityGraph.resolve(
      PetActivityContext(
        isSleeping: isSleeping,
        wakePose: wakeRitualPhase?.pose,
        isDancing: isDancing,
        isScratching: isScratching,
        isNuzzling: isNuzzling,
        isReminderVisible: breakRitualPhase != .idle,
        isRoaming: rootMotionRequest != nil,
        feedingPhase: treatJourneyFrame?.phase,
        personalityPose: activePersonalityMoment?.pose,
        relationshipGesture: activePersonalityMoment?.relationshipGesture,
        autonomyDrive: autonomyState.dominantDrive
      ))
  }

  var weatherTemperatureSummary: String {
    guard let apparent = weather.details.apparentTemperatureCelsius,
      apparent.isFinite
    else { return weather.temperatureLabel }
    return "\(weather.temperatureLabel) · feels \(Int(apparent.rounded()))C"
  }

  var weatherAtmosphereSummary: String {
    if let wind = weather.details.windSpeedKilometersPerHour,
      wind.isFinite
    {
      return "Wind \(Int(max(0, wind).rounded())) km/h"
    }
    return weather.locationName
  }

  func start() async {
    guard startupGate.claim() else { return }
    if !isRunningDiagnosticInteractions {
      await notifications.requestAuthorization()
    }
    sessionState = workTracker.start()
    startWorkMonitor()
    startSleepMonitor()
    startWeatherLoop()
    startPersonalitySchedule()
    startAutonomyLoop()
    startInteractionTracking()
    if let pendingStartupGreeting {
      _ = showGreeting(pendingStartupGreeting)
      self.pendingStartupGreeting = nil
    }
    if isRunningDiagnosticInteractions {
      startDiagnosticInteractionLoop()
    } else {
      await refreshWeather()
    }
  }

  func setPetWindowVisible(_ isVisible: Bool) {
    guard isPetWindowVisible != isVisible else { return }
    isPetWindowVisible = isVisible
    if !isVisible {
      cancelRootMotion()
      if breakRitualPhase == .stretching {
        cancelBreakReminderRitual()
      }
    }
  }

  func updateRootMotion(
    id: UUID,
    frame: PetRootMotionFrame
  ) {
    guard rootMotionRequest?.id == id,
      rootMotionFrame != frame
    else { return }
    rootMotionFrame = frame
  }

  func completeRootMotion(id: UUID) {
    guard rootMotionRequest?.id == id else { return }
    rootMotionRequest = nil
    rootMotionFrame = nil
  }

  func refreshWeather() async {
    revealStatusBriefly()
    isRefreshingWeather = true
    defer {
      isRefreshingWeather = false
      refreshAutonomyState()
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
    let interruptedActivity = activeActivity.kind
    wake()
    noteInteraction()
    let shouldShowInteractionResponse = activePersonalityMoment != nil
    let now = Date()
    if let last = lastPatAt, now.timeIntervalSince(last) <= comboWindow {
      comboCount = min(comboCount + 1, 99)
    } else {
      comboCount = 1
    }
    lastPatAt = now
    let response = touchResponse(
      for: .pat(comboCount: comboCount),
      interruptedActivity: interruptedActivity
    )

    bond.registerPat(comboMultiplier: comboCount)
    recordMemoryInteraction(.pat, at: now)
    persistBond()

    affectionPulse += 1
    heartBurst += 1
    playInteractionFeedback(.pat)
    isReminderVisible = false
    scheduleComboReset()
    if shouldShowInteractionResponse {
      _ = presentPersonalityMoment(category: .interaction)
    } else if response.presentsCallout {
      showInteractionCallout(response.line)
    } else {
      revealStatusBriefly()
    }
  }

  func interact(at zone: PetInteractionZone) {
    switch zone {
    case .noseOrSensor:
      boop()
    case .head, .torso:
      pat()
    case .none:
      break
    }
  }

  func handleStroke(_ gesture: PetStrokeGesture) {
    switch gesture {
    case .scratch(let region):
      scratch(region)
    case .swipe(let direction, let intensity):
      swipe(direction: direction, intensity: intensity)
    case .none:
      break
    }
  }

  var strokeOffset: CGSize {
    guard let swipeDirection else {
      return isScratching ? CGSize(width: 0, height: 3) : .zero
    }
    let amount = 5 + 7 * swipeIntensity
    return switch swipeDirection {
    case .left:
      CGSize(width: -amount, height: 0)
    case .right:
      CGSize(width: amount, height: 0)
    case .up:
      CGSize(width: 0, height: -amount)
    case .down:
      CGSize(width: 0, height: amount * 0.65)
    }
  }

  var strokeTiltDegrees: Double {
    guard let swipeDirection else {
      return isScratching ? 2.5 : 0
    }
    let amount = 3 + 5 * swipeIntensity
    return switch swipeDirection {
    case .left, .up:
      -amount
    case .right, .down:
      amount
    }
  }

  var strokeScale: Double {
    isScratching ? 1.025 : 1
  }

  var toyActionTitle: String {
    if activeToyKind != nil {
      return "Hide Toy"
    }
    return "Play with \(PetToyKind.forPet(petKind).displayName)"
  }

  func toggleToy() {
    toyMotionTask?.cancel()
    toyMotionTask = nil
    if activeToyKind != nil {
      activeToyKind = nil
      return
    }

    wake()
    noteInteraction()
    cancelTreatJourney()
    clearPersonalityMoment()
    isReminderVisible = false
    isStatusVisible = false
    toyPosition = CGPoint(x: 0.72, y: 0.46)
    activeToyKind = .forPet(petKind)
  }

  func moveToy(to position: CGPoint) {
    guard activeToyKind != nil else { return }
    toyMotionTask?.cancel()
    toyMotionTask = nil
    toyPosition = PetToyTrajectory.clamp(position)
  }

  func releaseToy(at predictedPosition: CGPoint) {
    guard let activeToyKind else { return }
    let target = PetToyTrajectory.clamp(predictedPosition)
    guard activeToyKind == .ball else {
      toyPosition = target
      registerToyPlay(activeToyKind)
      return
    }

    let trajectory = PetToyTrajectory(
      start: toyPosition,
      end: target,
      arcHeight: 0.22
    )
    toyMotionTask?.cancel()
    toyMotionTask = Task { [weak self] in
      let startedAt = Date().timeIntervalSinceReferenceDate
      let duration = 0.72
      while !Task.isCancelled {
        let elapsed = Date().timeIntervalSinceReferenceDate - startedAt
        let progress = min(1, elapsed / duration)
        self?.toyPosition = trajectory.position(at: progress)
        if progress >= 1 {
          self?.registerToyPlay(.ball)
          self?.toyMotionTask = nil
          return
        }
        do {
          try await Task.sleep(for: .seconds(1.0 / 30.0))
        } catch {
          return
        }
      }
    }
  }

  func dance() {
    wake()
    noteInteraction()
    cancelTreatJourney()
    clearPersonalityMoment()
    bond.registerPlay()
    recordMemoryInteraction(.dance)
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

  func takeStroll() {
    takeStroll(
      desiredDistance: Double.random(in: 90...140),
      preferredDirection: Bool.random() ? .left : .right
    )
  }

  func takeStroll(
    desiredDistance: Double,
    preferredDirection: PetRootMotionDirection
  ) {
    wake()
    noteInteraction()
    cancelTreatJourney()
    clearPersonalityMoment()
    isReminderVisible = false
    isStatusVisible = false

    activeToyKind = nil
    toyMotionTask?.cancel()
    toyMotionTask = nil
    danceTask?.cancel()
    danceTask = nil
    isDancing = false
    scratchTask?.cancel()
    scratchTask = nil
    isScratching = false
    scratchRegion = nil
    nuzzleTask?.cancel()
    nuzzleTask = nil
    isNuzzling = false
    swipeTask?.cancel()
    swipeTask = nil
    swipeDirection = nil
    swipeIntensity = 0

    rootMotionFrame = nil
    rootMotionRequest = PetRootMotionRequest(
      desiredDistance: desiredDistance,
      preferredDirection: preferredDirection
    )
    showInteractionCallout(strollCallout)
  }

  private func boop() {
    let response = touchResponse(
      for: .boop,
      interruptedActivity: activeActivity.kind
    )
    wake()
    noteInteraction()
    clearPersonalityMoment()
    isReminderVisible = false
    bond.registerPlay(points: 2)
    recordMemoryInteraction(.boop)
    persistBond()
    affectionPulse += 1
    heartBurst += 1
    showInteractionCallout(response.line)
    playInteractionFeedback(.boop)
  }

  private func scratch(_ region: PetScratchRegion) {
    let response = touchResponse(
      for: .scratch(region),
      interruptedActivity: activeActivity.kind
    )
    wake()
    noteInteraction()
    clearPersonalityMoment()
    guard !isNuzzling else { return }

    scratchTask?.cancel()
    isScratching = true
    scratchRegion = region
    isReminderVisible = false
    bond.registerPlay(points: 1)
    recordMemoryInteraction(.scratch)
    persistBond()
    affectionPulse += 1
    heartBurst += 1
    showInteractionCallout(response.line)
    playInteractionFeedback(.scratch)

    scratchTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(950))
      } catch {
        return
      }
      self?.isScratching = false
      self?.scratchRegion = nil
      self?.scratchTask = nil
    }
  }

  private func swipe(
    direction: PetSwipeDirection,
    intensity: Double
  ) {
    let resolvedIntensity = min(1, max(0, intensity.isFinite ? intensity : 0))
    let response = touchResponse(
      for: .swipe(
        direction: direction,
        intensity: resolvedIntensity
      ),
      interruptedActivity: activeActivity.kind
    )
    wake()
    noteInteraction()
    clearPersonalityMoment()
    isReminderVisible = false
    swipeTask?.cancel()
    swipeDirection = direction
    swipeIntensity = resolvedIntensity
    recordMemoryInteraction(.swipe)
    bond.registerPlay(points: 1)
    persistBond()
    affectionPulse += 1
    if response.addsHeart {
      heartBurst += 1
    }
    showInteractionCallout(response.line)
    playInteractionFeedback(.swipe)

    swipeTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(120))
      } catch {
        return
      }
      self?.swipeDirection = nil
      self?.swipeIntensity = 0
      self?.swipeTask = nil
    }
  }

  private func touchResponse(
    for action: PetTouchAction,
    interruptedActivity: PetActivityKind
  ) -> PetTouchResponse {
    PetTouchResponsePlanner.response(
      for: PetTouchResponseContext(
        petKind: petKind,
        action: action,
        mood: mood,
        bondLevel: bond.level,
        familiarity: petMemories[petKind].familiarity,
        interruptedActivity: interruptedActivity
      )
    )
  }

  private var strollCallout: String {
    switch petKind {
    case .cat:
      "Let's prowl."
    case .pauli:
      "Route mapped."
    case .dog:
      "Let's go!"
    }
  }

  private func showInteractionCallout(_ text: String) {
    interactionCalloutTask?.cancel()
    interactionCallout = text
    interactionCalloutTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(900))
      } catch {
        return
      }
      self?.interactionCallout = nil
    }
  }

  private func registerToyPlay(_ toyKind: PetToyKind) {
    noteInteraction()
    bond.registerPlay(points: 1)
    recordMemoryInteraction(.toy)
    persistBond()
    heartBurst += 1
    let callout =
      switch toyKind {
      case .laser:
        "pounce!"
      case .energyNode:
        "locked!"
      case .ball:
        "fetch!"
      }
    showInteractionCallout(callout)
    playInteractionFeedback(.toy)
  }

  func beginNuzzle() {
    wake()
    guard !isNuzzling, !isDancing, !isScratching else { return }
    noteInteraction()
    cancelTreatJourney()
    clearPersonalityMoment()
    isNuzzling = true
    isReminderVisible = false
    bond.registerPlay(points: 1)
    recordMemoryInteraction(.nuzzle)
    persistBond()
    affectionPulse += 1
    heartBurst += 1

    nuzzleTask?.cancel()
    nuzzleTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(0.7))
        guard !Task.isCancelled else { return }
        self?.heartBurst += 1
      }
    }
  }

  func endNuzzle() {
    guard isNuzzling else { return }
    isNuzzling = false
    nuzzleTask?.cancel()
    nuzzleTask = nil
  }

  /// A quiet "you noticed me" moment: one small heart and a play point,
  /// triggered when the pointer lingers on the pet.
  func delight() {
    noteInteraction()
    heartBurst += 1
    bond.registerPlay(points: 1)
    persistBond()
  }

  func dragLean(at time: TimeInterval) -> PetDragLean {
    dragLeanTracker.lean(at: time)
  }

  func cursorAttention(at time: TimeInterval) -> PetAttentionSample? {
    cursorTracker.attentionSample(at: time)
  }

  func takeBreak() {
    noteInteraction()
    clearPersonalityMoment()
    let policy = currentReminderPolicy()
    breakState = policy.markBreakTaken(state: breakState)
    sessionState = workTracker.start()
    isReminderVisible = false
    revealStatusBriefly()
  }

  func snoozeBreak() {
    cancelBreakReminderRitual()
    let policy = currentReminderPolicy()
    breakState = policy.snooze(state: breakState)
  }

  func selectPetKind(_ kind: PetKind) {
    wake()
    noteInteraction()
    clearPersonalityMoment()
    guard petKind != kind else {
      revealStatusBriefly()
      return
    }
    persistBond()
    let greeting = PetMemory.greeting(
      lastSeenAt: petMemories[kind].lastSeenAt,
      now: Date()
    )
    petKind = kind
    activeToyKind = nil
    cancelTreatJourney()
    toyMotionTask?.cancel()
    toyMotionTask = nil
    defaults.set(kind.rawValue, forKey: StoreKey.petKind)
    loadCurrentMemory()
    refreshAutonomyState()
    let usesPersonalityGreeting = showGreeting(greeting)
    if !usesPersonalityGreeting {
      revealStatusBriefly()
    }
  }

  func giveTreat() {
    wake()
    noteInteraction()
    clearPersonalityMoment()
    isReminderVisible = false
    isStatusVisible = false
    activeToyKind = nil
    toyMotionTask?.cancel()
    toyMotionTask = nil
    danceTask?.cancel()
    isDancing = false

    let journey = treatJourney(for: petKind)
    treatJourneyTask?.cancel()
    treatJourneyFrame = journey.frame(at: 0)
    treatJourneyTask = Task { [weak self] in
      let startedAt = Date.timeIntervalSinceReferenceDate
      var didReward = false
      while !Task.isCancelled {
        let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
        let frame = journey.frame(at: elapsed)
        self?.treatJourneyFrame = frame

        if frame.phase == .eating, !didReward {
          didReward = true
          self?.completeTreatReward()
        }
        if frame.phase == .completed {
          self?.treatJourneyFrame = nil
          self?.treatJourneyTask = nil
          self?.showInteractionCallout(
            self?.petKind == .pauli ? "energy restored!" : "yum!"
          )
          _ = self?.presentPersonalityMoment(category: .treat)
          return
        }

        do {
          try await Task.sleep(for: .seconds(1.0 / 30.0))
        } catch {
          return
        }
      }
    }
  }

  private func completeTreatReward() {
    bond.registerPlay(points: 2)
    recordMemoryInteraction(.treat)
    persistBond()
    refreshAutonomyState()
    heartBurst += 1
    affectionPulse += 1
    playInteractionFeedback(.treatSatisfied)
  }

  private func treatJourney(for petKind: PetKind) -> PetTreatJourney {
    let landing: CGPoint
    let mouth: CGPoint
    switch petKind {
    case .cat:
      landing = CGPoint(x: 0.25, y: 0.78)
      mouth = CGPoint(x: 0.44, y: 0.40)
    case .pauli:
      landing = CGPoint(x: 0.28, y: 0.77)
      mouth = CGPoint(x: 0.50, y: 0.43)
    case .dog:
      landing = CGPoint(x: 0.26, y: 0.78)
      mouth = CGPoint(x: 0.46, y: 0.43)
    }
    return PetTreatJourney(
      start: CGPoint(x: 0.88, y: 0.08),
      landing: landing,
      mouth: mouth
    )
  }

  private func cancelTreatJourney() {
    treatJourneyTask?.cancel()
    treatJourneyTask = nil
    treatJourneyFrame = nil
  }

  private func wake() {
    cancelWakeRitual()
    if isSleeping { isSleeping = false }
  }

  func beginWakeRitual() {
    cancelWakeRitual()
    isSleeping = false
    let steps = PetWakeRitualPlanner.steps(
      timing: wakeRitualTiming,
      reduceMotion: wakeReduceMotionProvider()
    )
    guard let firstStep = steps.first else { return }
    wakeRitualPhase = firstStep.phase

    wakeRitualTask = Task { [weak self] in
      for (index, step) in steps.enumerated() {
        guard !Task.isCancelled else { return }
        if index > 0 {
          self?.wakeRitualPhase = step.phase
        }
        do {
          try await Task.sleep(for: .seconds(step.duration))
        } catch {
          return
        }
      }
      guard !Task.isCancelled else { return }
      self?.wakeRitualPhase = nil
      self?.wakeRitualTask = nil
    }
  }

  private func cancelWakeRitual() {
    wakeRitualTask?.cancel()
    wakeRitualTask = nil
    wakeRitualPhase = nil
  }

  private func scheduleComboReset() {
    comboResetTask?.cancel()
    let resetDelay = comboResetDelay
    comboResetTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(resetDelay))
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      self?.comboCount = 0
    }
  }

  private func startSleepMonitor() {
    sleepTask?.cancel()
    sleepTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        guard let self else { return }
        self.observeIdleState(idleSeconds: self.idleMonitor.idleSeconds())
      }
    }
  }

  func observeIdleState(idleSeconds: TimeInterval) {
    let shouldSleep = idleSeconds >= sleepIdleThreshold
    if shouldSleep {
      guard !isSleeping || wakeRitualPhase != nil else { return }
      cancelWakeRitual()
      isSleeping = true
      cancelRootMotion()
      if breakRitualPhase == .stretching {
        cancelBreakReminderRitual()
      }
      clearPersonalityMoment()
    } else if isSleeping {
      beginWakeRitual()
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

  private func startPersonalitySchedule() {
    personalityScheduleTask?.cancel()
    personalityScheduleTask = Task { [weak self] in
      while !Task.isCancelled {
        let delay = PersonalityMomentSchedule.delay(for: Int.random(in: 0...600))
        try? await Task.sleep(for: .seconds(delay))
        guard let self, !Task.isCancelled else { return }
        self.presentPersonalityMoment()
      }
    }
  }

  private func startAutonomyLoop() {
    autonomyTask?.cancel()
    autonomyTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(45))
        guard !Task.isCancelled else { return }
        self?.refreshAutonomyState()
        self?.presentRelationshipCueIfNeeded()
        self?.scheduleRootMotionIfNeeded()
      }
    }
  }

  private func startDiagnosticInteractionLoop() {
    guard isRunningDiagnosticInteractions else { return }
    diagnosticInteractionTask?.cancel()
    diagnosticInteractionTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(60))
      } catch {
        return
      }
      var step = 0
      while !Task.isCancelled {
        guard let self else { return }
        switch step % 6 {
        case 0:
          self.pat()
        case 1:
          self.dance()
        case 2:
          self.scratch(.earOrTemple)
        case 3:
          self.swipe(direction: .right, intensity: 0.8)
        case 4:
          self.giveTreat()
        default:
          self.boop()
        }
        step += 1
        do {
          try await Task.sleep(for: .seconds(5))
        } catch {
          return
        }
      }
    }
  }

  private func startInteractionTracking() {
    guard windowMoveObserver == nil else { return }
    let petWindow =
      NSApp.windows.first(where: { $0.title == "DeskPet" })
      ?? NSApp.windows.first
    if let petWindow {
      updateBubblePlacement(for: petWindow)
    }
    windowMoveObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: petWindow,
      queue: .main
    ) { [weak self] notification in
      guard let window = notification.object as? NSWindow else { return }
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.rootMotionRequest == nil {
          self.dragLeanTracker.recordWindowOrigin(
            x: window.frame.origin.x,
            y: window.frame.origin.y,
            at: Date().timeIntervalSinceReferenceDate
          )
        }
        self.updateBubblePlacement(for: window)
      }
    }
    cursorTracker.start()
  }

  private func updateBubblePlacement(for window: NSWindow) {
    guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
      bubblePlacement = .center
      return
    }

    bubblePlacement =
      PetBubbleLayout.resolve(
        kind: .personality,
        windowMinX: window.frame.minX,
        windowMaxX: window.frame.maxX,
        windowMinY: window.frame.minY,
        windowMaxY: window.frame.maxY,
        visibleMinX: visibleFrame.minX,
        visibleMaxX: visibleFrame.maxX,
        visibleMinY: visibleFrame.minY,
        visibleMaxY: visibleFrame.maxY
      ).placement
  }

  private var isPersonalityPresentationBlocked: Bool {
    isQuietModeEnabled
      || rootMotionRequest != nil
      || isSleeping
      || wakeRitualPhase != nil
      || breakRitualPhase != .idle
      || isStatusVisible
      || isRefreshingWeather
      || isDancing
      || treatJourneyFrame != nil
  }

  private func personalityContext(
    requestedCategory: PersonalityMomentCategory? = nil
  ) -> PersonalityMomentContext {
    PersonalityMomentContext(
      petKind: petKind,
      mood: mood,
      workProgress: workProgress,
      requestedCategory: requestedCategory,
      isPresentationBlocked: isPersonalityPresentationBlocked
    )
  }

  @discardableResult
  private func presentPersonalityMoment(
    category: PersonalityMomentCategory? = nil
  ) -> Bool {
    let context = personalityContext(requestedCategory: category)
    let recentIDs = Set(recentPersonalityMomentIDs)
    let roll = Int.random(in: Int.min...Int.max)
    var moment = PersonalityMomentSelector.select(
      from: PersonalityMomentCatalog.all,
      context: context,
      excluding: recentIDs,
      roll: roll
    )

    if moment == nil, category == .interaction || category == .treat {
      moment = PersonalityMomentSelector.select(
        from: PersonalityMomentCatalog.all,
        context: context,
        excluding: [],
        roll: roll
      )
    }

    guard let moment else { return false }
    activePersonalityMoment = moment
    recentPersonalityMomentIDs.append(moment.id)
    recentPersonalityMomentIDs = Array(recentPersonalityMomentIDs.suffix(3))
    var memory = petMemories[petKind]
    memory.recordMoment(moment.id)
    petMemories[petKind] = memory
    persistBond()

    personalityDismissTask?.cancel()
    personalityDismissTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3.5))
      guard !Task.isCancelled, self?.activePersonalityMoment?.id == moment.id else { return }
      self?.activePersonalityMoment = nil
    }
    return true
  }

  private func clearPersonalityMoment() {
    cancelGreetingRitual()
    personalityDismissTask?.cancel()
    activePersonalityMoment = nil
  }

  private func presentRelationshipCueIfNeeded(now: Date = Date()) {
    if let lastRelationshipCueAt,
      now.timeIntervalSince(lastRelationshipCueAt) < 30 * 60
    {
      return
    }

    let memory = petMemories[petKind]
    let hour = Calendar.current.component(.hour, from: now)
    let context = PetRelationshipCueContext(
      petKind: petKind,
      preferredInteraction: memory.preferredInteraction,
      familiarity: memory.familiarity,
      rhythmAffinity: memory.rhythmAffinity(atHour: hour),
      autonomyDrive: autonomyState.dominantDrive,
      isPresentationBlocked: isPersonalityPresentationBlocked
        || activePersonalityMoment != nil
    )
    guard let cue = PetRelationshipCuePlanner.cue(for: context) else {
      return
    }

    let moment = PersonalityMoment(
      id: cue.id,
      petKind: petKind,
      category: .interaction,
      pose: cue.pose,
      relationshipGesture: cue.gesture,
      line: cue.line
    )
    activePersonalityMoment = moment
    recentPersonalityMomentIDs.append(moment.id)
    recentPersonalityMomentIDs = Array(
      recentPersonalityMomentIDs.suffix(3)
    )
    var updatedMemory = memory
    updatedMemory.recordMoment(moment.id)
    petMemories[petKind] = updatedMemory
    persistBond()
    lastRelationshipCueAt = now

    personalityDismissTask?.cancel()
    personalityDismissTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3.5))
      guard !Task.isCancelled,
        self?.activePersonalityMoment?.id == moment.id
      else { return }
      self?.activePersonalityMoment = nil
    }
  }

  private func recordWorkObservation() {
    sessionState = workTracker.recordObservation(
      previous: sessionState,
      idleSeconds: idleMonitor.idleSeconds()
    )

    let candidate = BreakReminderState(
      activeSeconds: sessionState.activeSeconds,
      lastReminderAt: breakState.lastReminderAt,
      snoozedUntil: breakState.snoozedUntil
    )
    let policy = currentReminderPolicy()

    if breakRitualPhase == .idle,
      policy.shouldRemind(state: candidate),
      PetQuietModePolicy.allows(
        .reminder,
        isQuietModeEnabled: isQuietModeEnabled
      )
    {
      beginBreakReminderRitual()
    }

    breakState = candidate
    refreshAutonomyState()
  }

  private func currentReminderPolicy() -> BreakReminderPolicy {
    BreakReminderPolicy(reminderInterval: reminderMinutes * 60, snoozeInterval: 10 * 60)
  }

  func beginBreakReminderRitual() {
    guard breakRitualPhase == .idle,
      canBeginBreakReminderRitual
    else { return }

    cancelRootMotion()
    clearPersonalityMoment()
    isStatusVisible = false
    isReminderVisible = false
    breakRitualPhase = .stretching

    reminderPresentationTask?.cancel()
    let stretchDuration = reminderStretchDuration
    reminderPresentationTask = Task { [weak self] in
      do {
        try await Task.sleep(for: stretchDuration)
      } catch {
        return
      }
      guard !Task.isCancelled,
        let self,
        self.breakRitualPhase == .stretching,
        self.canBeginBreakReminderRitual
      else { return }

      self.breakRitualPhase = .prompting
      self.isReminderVisible = true
      self.breakState = self.currentReminderPolicy().markReminderShown(
        state: self.breakState
      )
      if self.postsReminderNotifications {
        self.notifications.showBreakReminder()
      }
      self.reminderPresentationTask = nil
    }
  }

  private var canBeginBreakReminderRitual: Bool {
    isPetWindowVisible
      && !isQuietModeEnabled
      && !isSleeping
      && wakeRitualPhase == nil
      && !isDancing
      && !isScratching
      && !isNuzzling
      && treatJourneyFrame == nil
      && activeToyKind == nil
  }

  private func cancelBreakReminderRitual() {
    reminderPresentationTask?.cancel()
    reminderPresentationTask = nil
    breakRitualPhase = .idle
    isReminderVisible = false
  }

  private func loadPersistedState() {
    if let raw = defaults.string(forKey: StoreKey.petKind), let kind = PetKind(rawValue: raw) {
      petKind = kind
    }
    let savedMinutes = defaults.double(forKey: StoreKey.reminderMinutes)
    if savedMinutes >= 20, savedMinutes <= 90 {
      reminderMinutes = savedMinutes
    }
    if let data = defaults.data(forKey: StoreKey.memories),
      let saved = try? JSONDecoder().decode(
        PetMemoryCollection.self,
        from: data
      )
    {
      petMemories = saved
    } else if let data = defaults.data(forKey: StoreKey.bond),
      let saved = try? JSONDecoder().decode(PetBond.self, from: data)
    {
      var memory = petMemories[petKind]
      memory.updateBond(saved)
      petMemories[petKind] = memory
    }
    loadCurrentMemory()
    isQuietModeEnabled = defaults.bool(forKey: StoreKey.quietMode)
    isSoundEnabled = defaults.bool(forKey: StoreKey.soundEnabled)
  }

  private func persistBond() {
    guard !isRunningDiagnosticInteractions else { return }
    var memory = petMemories[petKind]
    memory.updateBond(bond)
    memory.markSeen(at: Date(), mood: mood)
    petMemories[petKind] = memory

    if let data = try? JSONEncoder().encode(petMemories) {
      defaults.set(data, forKey: StoreKey.memories)
    }
    if let data = try? JSONEncoder().encode(bond) {
      defaults.set(data, forKey: StoreKey.bond)
    }
  }

  func persistSession() {
    persistBond()
  }

  func setLearnedName(_ name: String) {
    var memory = petMemories[petKind]
    memory.setLearnedName(name)
    petMemories[petKind] = memory
    learnedName = memory.learnedName ?? ""
    persistBond()
  }

  private func loadCurrentMemory() {
    let memory = petMemories[petKind]
    bond = memory.bond
    learnedName = memory.learnedName ?? ""
    recentPersonalityMomentIDs = Array(
      memory.recentMomentIDs.suffix(3)
    )
  }

  private func recordMemoryInteraction(
    _ interaction: PetInteractionPreference,
    at date: Date = Date()
  ) {
    var memory = petMemories[petKind]
    memory.recordInteraction(interaction, at: date)
    petMemories[petKind] = memory
  }

  @discardableResult
  private func showGreeting(_ greeting: PetGreeting) -> Bool {
    guard !isQuietModeEnabled else { return false }
    let ritual = PetGreetingRitualPlanner.ritual(
      for: PetGreetingRitualContext(
        greeting: greeting,
        petKind: petKind,
        displayName: petDisplayName,
        familiarity: petMemories[petKind].familiarity
      )
    )

    cancelGreetingRitual()
    personalityDismissTask?.cancel()
    playInteractionFeedback(.greeting)

    guard ritual.presentation == .personalityMoment,
      let pose = ritual.pose
    else {
      activePersonalityMoment = nil
      showInteractionCallout(ritual.line)
      return false
    }

    interactionCalloutTask?.cancel()
    interactionCallout = nil
    isStatusVisible = false
    let moment = PersonalityMoment(
      id: "greeting.\(petKind.rawValue).\(greeting.ritualID)",
      petKind: petKind,
      category: .interaction,
      pose: pose,
      line: ritual.line
    )
    activePersonalityMoment = moment
    if ritual.playsAffectionPulse {
      affectionPulse += 1
    }

    if !ritual.heartPulseDelays.isEmpty {
      greetingTask = Task { [weak self] in
        var previousDelay: TimeInterval = 0
        for delay in ritual.heartPulseDelays {
          do {
            try await Task.sleep(
              for: .seconds(delay - previousDelay)
            )
          } catch {
            return
          }
          guard !Task.isCancelled,
            self?.activePersonalityMoment?.id == moment.id
          else {
            return
          }
          self?.heartBurst += 1
          previousDelay = delay
        }
        self?.greetingTask = nil
      }
    }

    personalityDismissTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(ritual.duration))
      } catch {
        return
      }
      guard !Task.isCancelled,
        self?.activePersonalityMoment?.id == moment.id
      else { return }
      self?.activePersonalityMoment = nil
      self?.cancelGreetingRitual()
    }
    return true
  }

  private func cancelGreetingRitual() {
    greetingTask?.cancel()
    greetingTask = nil
  }

  private func playInteractionFeedback(_ cue: PetSoundCue) {
    guard isSoundEnabled, !isQuietModeEnabled else { return }
    soundPlayer.play(PetSoundDesign.profile(for: petKind, cue: cue))
    if PetHapticDesign.performsFeedback(for: cue) {
      hapticPlayer.perform()
    }
  }

  private func noteInteraction(at date: Date = Date()) {
    cancelWakeRitual()
    cancelGreetingRitual()
    cancelRootMotion()
    cancelBreakReminderRitual()
    lastInteractionAt = date
    refreshAutonomyState(now: date)
  }

  private func scheduleRootMotionIfNeeded() {
    guard rootMotionRequest == nil,
      isPetWindowVisible,
      !isQuietModeEnabled,
      autonomyState.dominantDrive == .explore,
      !isSleeping,
      wakeRitualPhase == nil,
      !isDancing,
      !isScratching,
      !isNuzzling,
      breakRitualPhase == .idle,
      !isStatusVisible,
      activeToyKind == nil,
      treatJourneyFrame == nil,
      activePersonalityMoment == nil
    else { return }

    rootMotionFrame = nil
    rootMotionRequest = PetRootMotionRequest(
      desiredDistance: Double.random(in: 80...140),
      preferredDirection: Bool.random() ? .left : .right
    )
  }

  func cancelRootMotion() {
    rootMotionRequest = nil
    rootMotionFrame = nil
  }

  private func refreshAutonomyState(now: Date = Date()) {
    let hour = Calendar.current.component(.hour, from: now)
    let memory = petMemories[petKind]
    autonomyState = PetAutonomyDirector.state(
      pet: petKind,
      hourOfDay: hour,
      secondsSinceInteraction: max(
        0,
        now.timeIntervalSince(lastInteractionAt)
      ),
      workProgress: workProgress,
      mood: mood,
      bondProgress: bondProgress,
      familiarity: memory.familiarity,
      preferredInteraction: memory.preferredInteraction,
      rhythmAffinity: memory.rhythmAffinity(atHour: hour)
    )
  }

  private func revealStatusBriefly() {
    guard
      PetQuietModePolicy.allows(
        .status,
        isQuietModeEnabled: isQuietModeEnabled
      )
    else { return }
    clearPersonalityMoment()
    statusRevealToken += 1
    let token = statusRevealToken
    isStatusVisible = true

    Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard let self else { return }
      if self.statusRevealToken == token, !self.isRefreshingWeather {
        self.isStatusVisible = false
      }
    }
  }
}

extension PetGreeting {
  fileprivate var ritualID: String {
    switch self {
    case .firstMeeting:
      "first-meeting"
    case .returningSoon:
      "returning-soon"
    case .welcomeBack:
      "welcome-back"
    case .longTimeNoSee:
      "long-time-no-see"
    }
  }
}
