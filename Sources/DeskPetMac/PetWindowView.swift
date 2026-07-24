import AppKit
import DeskPetCore
import SwiftUI

private enum SceneMetrics {
    static let windowSize = CGSize(width: 260, height: 290)
    static let weatherSize = CGSize(width: 220, height: 218)
    static let artworkSize = CGSize(width: 190, height: 198)
}

enum VectorPetMotionValues {
    static func pauliStatusPulse(
        time: TimeInterval,
        reduceMotion: Bool
    ) -> Double {
        guard !reduceMotion else { return 1 }
        return 0.78 + abs(sin(time * 3.4)) * 0.22
    }
}

struct PetWindowView: View {
    @ObservedObject var model: PetViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false
    @State private var pointerOffset = CGSize.zero

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 6) {
                Spacer(minLength: 38)
                ZStack {
                    WeatherBackdrop(
                        mood: displayedMood,
                        pointerOffset: pointerOffset,
                        reduceMotion: reduceMotion
                    )
                        .id("weather-background-\(displayedMood.rawValue)")
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    WeatherMidground(
                        mood: displayedMood,
                        pointerOffset: pointerOffset,
                        reduceMotion: reduceMotion
                    )
                        .id("weather-midground-\(displayedMood.rawValue)")
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    PetInteractionFeedback(
                        burst: model.heartBurst,
                        combo: model.comboCount,
                        reduceMotion: reduceMotion
                    )
                    .offset(y: 8)

                    Button {
                        model.pat()
                    } label: {
                        Group {
                            if PetArtworkLoader.hasBaseArtwork(for: model.petKind) {
                                RealisticPetBody(
                                    kind: model.petKind,
                                    mood: displayedMood,
                                    isHovering: hover,
                                    pulse: model.affectionPulse,
                                    comboCount: model.comboCount,
                                    isSleeping: model.isSleeping,
                                    isDancing: model.isDancing,
                                    personalityPose: model.activePersonalityMoment?.pose,
                                    pointerOffset: pointerOffset,
                                    reduceMotion: reduceMotion,
                                    motionPreview: motionPreview
                                )
                            } else {
                                VectorPetBody(
                                    kind: model.petKind,
                                    mood: displayedMood,
                                    isHovering: hover,
                                    pulse: model.affectionPulse,
                                    comboCount: model.comboCount,
                                    isSleeping: model.isSleeping,
                                    isDancing: model.isDancing,
                                    personalityPose: model.activePersonalityMoment?.pose,
                                    pointerOffset: pointerOffset,
                                    reduceMotion: reduceMotion
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(
                        width: SceneMetrics.artworkSize.width,
                        height: SceneMetrics.artworkSize.height
                    )
                    .accessibilityLabel("Pat \(model.petKind.displayName)")
                    .accessibilityValue(
                        model.comboCount >= 2
                            ? "\(model.comboCount) pat combo"
                            : ""
                    )

                    WeatherForeground(
                        mood: displayedMood,
                        pointerOffset: pointerOffset,
                        reduceMotion: reduceMotion
                    )
                        .id("weather-foreground-\(displayedMood.rawValue)")
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(
                    width: SceneMetrics.weatherSize.width,
                    height: SceneMetrics.weatherSize.height
                )
                .animation(
                    .easeInOut(
                        duration: WeatherSceneProfile(mood: displayedMood).transitionDuration
                    ),
                    value: displayedMood
                )

                Spacer(minLength: 6)
            }
            .padding(10)

            ControlStrip(model: model, isVisible: controlsVisible)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            HeartParticleOverlay(
                burst: model.heartBurst,
                combo: model.comboCount,
                reduceMotion: reduceMotion
            )
                .allowsHitTesting(false)
                .offset(y: 92)

            bubbleOverlay
                .padding(.top, 6)
        }
        .frame(
            width: SceneMetrics.windowSize.width,
            height: SceneMetrics.windowSize.height
        )
        .overlay(alignment: .topTrailing) {
            if model.comboCount >= 2 {
                ComboBadge(count: model.comboCount)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(.clear)
        .contextMenu {
            Button("Close DeskPet") {
                NSApp.terminate(nil)
            }
        }
        .onHover { hover = $0 }
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                pointerOffset = normalizedPointerOffset(location)
            case .ended:
                pointerOffset = .zero
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: hover)
        .animation(
            reduceMotion
                ? .linear(duration: 0.08)
                : .interactiveSpring(response: 0.24, dampingFraction: 0.82),
            value: pointerOffset
        )
        .animation(.spring(response: 0.30, dampingFraction: 0.70), value: model.affectionPulse)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: model.comboCount)
        .animation(.easeInOut(duration: 0.3), value: model.isSleeping)
        .animation(.easeInOut(duration: 0.22), value: model.isReminderVisible)
        .animation(
            reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.76),
            value: model.activePersonalityMoment?.id
        )
        .animation(.easeInOut(duration: 0.16), value: controlsVisible)
    }

    private var controlsVisible: Bool {
        hover
            || model.isPetPickerVisible
            || model.isSettingsVisible
    }

    private var displayedMood: PetWeatherMood {
        #if DEBUG
        if let rawValue = ProcessInfo.processInfo.environment["DESKPET_WEATHER_PREVIEW"],
           let preview = PetWeatherMood(rawValue: rawValue) { return preview }
        #endif
        return model.mood
    }

    private var motionPreview: PetMotionEvent? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["DESKPET_MOTION_PREVIEW"] else {
            return nil
        }
        return PetMotionEvent(rawValue: raw)
        #else
        return nil
        #endif
    }

    private func normalizedPointerOffset(_ location: CGPoint) -> CGSize {
        CGSize(
            width: min(1, max(-1, (location.x - 130) / 130)),
            height: min(1, max(-1, (location.y - 145) / 145))
        )
    }

    @ViewBuilder
    private var bubbleOverlay: some View {
        if model.isReminderVisible {
            BreakBubble(model: model)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let moment = model.activePersonalityMoment {
            PersonalityBubble(moment: moment)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity)
                )
        }
    }
}

private struct BreakBubble: View {
    @ObservedObject var model: PetViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("Stretch break")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("Stand, breathe, and reset.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Done") { model.takeBreak() }
                    .buttonStyle(PetActionButtonStyle(tint: .mint))
                Button("10m") { model.snoozeBreak() }
                    .buttonStyle(PetActionButtonStyle(tint: .orange))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        )
    }
}

private struct ControlStrip: View {
    @ObservedObject var model: PetViewModel
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 5) {
            Button {
                model.isPetPickerVisible.toggle()
            } label: {
                Image(systemName: "pawprint.fill")
            }
            .help("Choose Cat, Pauli, or Dog")
            .buttonStyle(PetIconButtonStyle(tint: .pink, isActive: model.isPetPickerVisible))
            .popover(isPresented: $model.isPetPickerVisible, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pet")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Button {
                            model.selectPetKind(.cat)
                        } label: {
                            Label("Cat", systemImage: "sparkle")
                        }
                        .buttonStyle(PetChoiceButtonStyle(isSelected: model.petKind == .cat, tint: .purple))

                        Button {
                            model.selectPetKind(.pauli)
                        } label: {
                            Label("Pauli", systemImage: "sparkles")
                        }
                        .buttonStyle(PetChoiceButtonStyle(isSelected: model.petKind == .pauli, tint: .cyan))

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
                    }
                }
                .padding(14)
            }

            Button {
                model.dance()
            } label: {
                Image(systemName: "music.note")
            }
            .help("Make the pet dance")
            .buttonStyle(PetIconButtonStyle(tint: .purple, isActive: model.isDancing))

            Button {
                model.toggleSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Reminder settings")
            .buttonStyle(PetIconButtonStyle(tint: .orange, isActive: model.isSettingsVisible))
            .popover(isPresented: $model.isSettingsVisible, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stand Reminder")
                        .font(.headline)
                    HStack {
                        Slider(value: $model.reminderMinutes, in: 20...90, step: 5)
                            .frame(width: 160)
                        Text("\(Int(model.reminderMinutes))m")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(16)
                .frame(width: 250)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 5)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

private struct VectorPetBody: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let isHovering: Bool
    let pulse: Int
    let comboCount: Int
    let isSleeping: Bool
    let isDancing: Bool
    let personalityPose: PersonalityPose?
    let pointerOffset: CGSize
    let reduceMotion: Bool

    @State private var isShowingPat = false
    @State private var patTask: Task<Void, Never>?
    @State private var patGeneration = 0
    @State private var patStartedAt: TimeInterval?
    @State private var patCombo = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let weather = weatherMotion(at: t)
            let danceBob = reduceMotion ? 0 : (isDancing ? abs(sin(t * 9.0)) * 8 : 0)
            let idleBob = reduceMotion
                ? 0
                : isSleeping
                    ? sin(t * 1.1) * 1.6
                    : sin(t * (kind == .pauli ? 2.8 : 2.4))
                        * 4
                        * idleAmplitudeMultiplier
            let personalityBob = if reduceMotion {
                0.0
            } else {
                switch personalityPose {
                case .some(.peek): sin(t * 3.2) * 1.4
                case .some(.perk): abs(sin(t * 5.8)) * -3.2
                case .some(.stretch): sin(t * 2.0) * 1.2
                case .some(.proud): sin(t * 3.0) * -1.0
                case .none: 0.0
                }
            }
            let bob = idleBob - danceBob + personalityBob
            let leftEarDrift = reduceMotion ? 0 : sin(t * 3.7) * 2.4
            let rightEarDrift = reduceMotion ? 0 : sin(t * 3.3 + 1.1) * 2.0
            let leftEarPoseAngle = switch personalityPose {
            case .some(.perk): 10.0
            case .some(.stretch): -8.0
            case .some(.peek): 4.0
            case .some(.proud): -3.0
            case .none: 0.0
            }
            let rightEarPoseAngle = switch personalityPose {
            case .some(.perk): -4.0
            case .some(.stretch): 5.0
            case .some(.peek): -7.0
            case .some(.proud): 9.0
            case .none: 0.0
            }
            let tail = reduceMotion
                ? 0
                : sin(t * (isDancing ? 9.0 : 5.0)) * (isDancing ? 14 : 8)
            let eyesClosed = isSleeping || Int(t * 1.2) % 7 == 0
            let scale = isHovering ? 1.035 : 1.0
            let statusPulse = VectorPetMotionValues.pauliStatusPulse(
                time: t,
                reduceMotion: reduceMotion
            )
            let danceTilt = reduceMotion ? 0 : (isDancing ? sin(t * 9.0) * 9 : 0)
            let interactionPose = interactionPose(at: t)
            let personalityTilt = if reduceMotion {
                0.0
            } else {
                switch personalityPose {
                case .some(.peek): -3.5
                case .some(.perk): 2.0
                case .some(.stretch): -1.5
                case .some(.proud): 3.0
                case .none: 0.0
                }
            }

            ZStack {
                switch kind {
                case .pauli:
                    PauliBody(
                        mood: mood,
                        blink: eyesClosed,
                        bob: bob,
                        statusPulse: statusPulse,
                        personalityPose: personalityPose
                    )
                case .cat:
                    VectorCatBody(
                        mood: mood,
                        palette: palette,
                        blink: eyesClosed,
                        bob: bob,
                        tail: tail,
                        leftEarDrift: leftEarDrift,
                        rightEarDrift: rightEarDrift,
                        leftEarPoseAngle: leftEarPoseAngle,
                        rightEarPoseAngle: rightEarPoseAngle,
                        personalityPose: personalityPose
                    )
                case .dog:
                    VectorDogBody(
                        palette: palette,
                        blink: eyesClosed,
                        bob: bob,
                        tail: tail,
                        personalityPose: personalityPose
                    )
                }

                if isSleeping {
                    SleepZ(t: t)
                        .offset(x: kind == .pauli ? 50 : 44, y: -52 + bob)
                        .transition(.opacity)
                }
            }
            .frame(width: 156, height: 158)
            .rotationEffect(
                .degrees(
                    danceTilt
                        + personalityTilt
                        + weather.tilt
                        + interactionPose.tiltDegrees
                )
            )
            .offset(
                x: weather.offset.width + interactionPose.x,
                y: weather.offset.height + interactionPose.y
            )
            .scaleEffect(scale * interactionPose.scale)
        }
        .frame(width: 220, height: 218)
        .onChange(of: pulse) {
            patTask?.cancel()
            patGeneration += 1
            let generation = patGeneration
            patStartedAt = Date().timeIntervalSinceReferenceDate
            patCombo = max(1, comboCount)
            isShowingPat = true
            patTask = Task { @MainActor in
                try? await Task.sleep(
                    for: .seconds(
                        PetAnimationDynamics.patDuration(comboCount: patCombo)
                    )
                )
                guard !Task.isCancelled, generation == patGeneration else { return }
                isShowingPat = false
                patStartedAt = nil
                patTask = nil
            }
        }
        .onDisappear {
            patTask?.cancel()
            patTask = nil
            patGeneration += 1
            isShowingPat = false
            patStartedAt = nil
            patCombo = 1
        }
    }

    private var palette: PetPalette {
        PetPalette(mood: mood)
    }

    private var weatherReaction: PetWeatherReaction {
        WeatherSceneProfile.reaction(for: kind, mood: mood)
    }

    private var allowsWeatherReaction: Bool {
        !reduceMotion
            && !isSleeping
            && !isDancing
            && personalityPose == nil
            && !isHovering
            && !isShowingPat
    }

    private var idleAmplitudeMultiplier: Double {
        guard allowsWeatherReaction else { return 1 }
        switch mood {
        case .cloudy: return 0.68
        case .snowy: return 0.76
        case .sunny, .foggy, .rainy, .stormy, .cozy: return 1
        }
    }

    private func weatherMotion(at time: TimeInterval) -> (tilt: Double, offset: CGSize) {
        guard allowsWeatherReaction else { return (0, .zero) }
        switch weatherReaction {
        case .observe:
            let oscillation = sin(normalizedWeatherPhase(time, period: 9) * .pi * 2)
            return (oscillation * 1.2, CGSize(width: oscillation * 1.1, height: 0))
        case .headLift, .sniff:
            return (0, CGSize(width: 0, height: -1))
        case .shelter:
            return (0, CGSize(width: 0, height: 1.2))
        case .shake:
            let phase = normalizedWeatherPhase(time, period: 16)
            guard phase < 0.08 else { return (0, .zero) }
            let progress = phase / 0.08
            let envelope = sin(progress * .pi)
            let oscillation = sin(progress * .pi * 6) * envelope
            return (oscillation * 2.4, CGSize(width: oscillation * 1.8, height: 0))
        case .startle:
            let phase = normalizedWeatherPhase(time, period: 22)
            guard phase < 0.05 else { return (0, .zero) }
            let envelope = cos((phase / 0.05) * .pi / 2)
            let direction = kind == .cat ? -1.0 : 1.0
            return (direction * envelope * 1.8, CGSize(width: 0, height: -2 * envelope))
        case .none, .settle, .antennaGlow, .visorGlow:
            return (0, .zero)
        }
    }

    private func normalizedWeatherPhase(_ time: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let remainder = time.truncatingRemainder(dividingBy: period)
        let normalized = remainder >= 0 ? remainder : remainder + period
        return normalized / period
    }

    private func interactionPose(at time: TimeInterval) -> PetAnimationPose {
        guard !reduceMotion else { return .neutral }
        if isShowingPat {
            return PetAnimationDynamics.patPose(
                for: kind,
                elapsed: max(0, time - (patStartedAt ?? time)),
                comboCount: patCombo
            )
        }
        if isHovering {
            return PetAnimationDynamics.attentionPose(
                for: kind,
                pointerX: pointerOffset.width,
                pointerY: pointerOffset.height,
                time: time
            )
        }
        return .neutral
    }
}

private struct VectorCatBody: View {
    let mood: PetWeatherMood
    let palette: PetPalette
    let blink: Bool
    let bob: Double
    let tail: Double
    let leftEarDrift: Double
    let rightEarDrift: Double
    let leftEarPoseAngle: Double
    let rightEarPoseAngle: Double
    let personalityPose: PersonalityPose?

    var body: some View {
        ZStack {
            ShadowBlob()
                .offset(y: 62)

            TailShape(wag: tail)
                .fill(palette.tail)
                .frame(width: 58, height: 64)
                .offset(x: 40, y: 22 + bob)
                .rotationEffect(.degrees(tail * 0.25))

            RoundedRectangle(cornerRadius: 54, style: .continuous)
                .fill(palette.body)
                .frame(width: 112, height: 102)
                .overlay(
                    RoundedRectangle(cornerRadius: 54, style: .continuous)
                        .stroke(.white.opacity(0.42), lineWidth: 2)
                )
                .offset(y: 20 + bob)

            CatEarView(color: palette.ear)
                .frame(width: 46, height: 56)
                .rotationEffect(
                    .degrees(-12 + leftEarDrift + leftEarPoseAngle),
                    anchor: .bottom
                )
                .offset(x: -37, y: -31 + bob)

            CatEarView(color: palette.ear)
                .frame(width: 46, height: 56)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(
                    .degrees(11 + rightEarDrift + rightEarPoseAngle),
                    anchor: .bottom
                )
                .offset(x: 37, y: -30 + bob)

            Circle()
                .fill(palette.face)
                .frame(width: 104, height: 94)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.38), lineWidth: 2)
                )
                .offset(y: bob)

            Face(
                eyesClosed: blink,
                mood: mood,
                personalityPose: personalityPose
            )
                .offset(y: bob + 4)
        }
    }
}

private struct VectorDogBody: View {
    let palette: PetPalette
    let blink: Bool
    let bob: Double
    let tail: Double
    let personalityPose: PersonalityPose?

    var body: some View {
        ZStack {
            ShadowBlob()
                .offset(y: 62)

            TailShape(wag: tail * 1.35)
                .fill(palette.tail)
                .frame(width: 58, height: 68)
                .offset(x: 43, y: 18 + bob)
                .rotationEffect(.degrees(tail * 0.34), anchor: .bottom)

            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(palette.body)
                .frame(width: 112, height: 94)
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.38), lineWidth: 2)
                )
                .scaleEffect(bodyScale, anchor: .bottom)
                .offset(y: 26 + bob)

            DogEarShape()
                .fill(palette.ear)
                .frame(width: 43, height: 68)
                .rotationEffect(.degrees(leftEarAngle), anchor: .top)
                .offset(x: -45, y: -17 + bob + leftEarLift)

            DogEarShape()
                .fill(palette.ear)
                .frame(width: 43, height: 68)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(rightEarAngle), anchor: .top)
                .offset(x: 45, y: -17 + bob + rightEarLift)

            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(palette.face)
                .frame(width: 106, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 46, style: .continuous)
                        .stroke(.white.opacity(0.38), lineWidth: 2)
                )
                .rotationEffect(.degrees(headAngle))
                .offset(x: headOffset.width, y: bob + headOffset.height)

            HStack(spacing: 30) {
                Eye(expression: leftEyeExpression)
                Eye(expression: rightEyeExpression)
            }
            .offset(x: headOffset.width, y: bob - 8 + headOffset.height)

            Capsule()
                .fill(palette.body.opacity(0.72))
                .frame(width: 58, height: 35)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color(red: 0.20, green: 0.14, blue: 0.12))
                        .frame(width: 19, height: 12)
                        .offset(y: 3)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color(red: 0.34, green: 0.20, blue: 0.16))
                        .frame(width: mouthWidth, height: 5)
                        .offset(y: -4)
                }
                .rotationEffect(.degrees(headAngle))
                .offset(x: headOffset.width, y: bob + 20 + headOffset.height)
        }
    }

    private var bodyScale: CGSize {
        switch personalityPose {
        case .some(.stretch): CGSize(width: 1.08, height: 0.90)
        case .some(.proud): CGSize(width: 0.98, height: 1.04)
        case .some(.peek), .some(.perk), .none: CGSize(width: 1, height: 1)
        }
    }

    private var headOffset: CGSize {
        switch personalityPose {
        case .some(.peek): CGSize(width: -6, height: 1)
        case .some(.perk): CGSize(width: 0, height: -5)
        case .some(.stretch): CGSize(width: 5, height: 3)
        case .some(.proud): CGSize(width: 0, height: -3)
        case .none: .zero
        }
    }

    private var headAngle: Double {
        switch personalityPose {
        case .some(.peek): -5
        case .some(.perk): 2
        case .some(.stretch): 3
        case .some(.proud): -2
        case .none: 0
        }
    }

    private var leftEarLift: CGFloat {
        switch personalityPose {
        case .some(.perk): -7
        case .some(.proud): -3
        case .some(.peek), .some(.stretch), .none: 0
        }
    }

    private var rightEarLift: CGFloat {
        switch personalityPose {
        case .some(.perk): -7
        case .some(.peek): 3
        case .some(.proud): -3
        case .some(.stretch), .none: 0
        }
    }

    private var leftEarAngle: Double {
        switch personalityPose {
        case .some(.peek): -7
        case .some(.perk): 8
        case .some(.stretch): -13
        case .some(.proud): 4
        case .none: 1
        }
    }

    private var rightEarAngle: Double {
        switch personalityPose {
        case .some(.peek): 12
        case .some(.perk): -8
        case .some(.stretch): 13
        case .some(.proud): -4
        case .none: -1
        }
    }

    private var leftEyeExpression: CatEyeExpression {
        guard !blink else { return .closed }
        return switch personalityPose {
        case .some(.perk): .wide
        case .some(.stretch): .closed
        case .some(.peek), .some(.proud), .none: .open
        }
    }

    private var rightEyeExpression: CatEyeExpression {
        guard !blink else { return .closed }
        return switch personalityPose {
        case .some(.perk): .wide
        case .some(.peek): .squint
        case .some(.stretch): .closed
        case .some(.proud), .none: .open
        }
    }

    private var mouthWidth: CGFloat {
        switch personalityPose {
        case .some(.perk): 24
        case .some(.stretch): 18
        case .some(.peek): 16
        case .some(.proud): 22
        case .none: 20
        }
    }
}

private struct DogEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 2))
        path.addCurve(
            to: CGPoint(x: rect.midX - 2, y: rect.maxY - 2),
            control1: CGPoint(x: rect.minX + 5, y: rect.minY + 10),
            control2: CGPoint(x: rect.minX + 3, y: rect.maxY - 12)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 3, y: rect.minY + 2),
            control1: CGPoint(x: rect.maxX - 2, y: rect.maxY - 4),
            control2: CGPoint(x: rect.maxX + 1, y: rect.midY - 8)
        )
        path.closeSubpath()
        return path
    }
}

private struct Face: View {
    let eyesClosed: Bool
    let mood: PetWeatherMood
    let personalityPose: PersonalityPose?

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 30) {
                Eye(expression: leftEyeExpression)
                Eye(expression: rightEyeExpression)
            }
            ZStack {
                Capsule()
                    .fill(Color(red: 0.28, green: 0.20, blue: 0.22))
                    .frame(width: mouthWidth, height: mouthHeight)
                    .offset(y: 3)
                Circle()
                    .fill(Color(red: 1.0, green: 0.56, blue: 0.64).opacity(cheekOpacity))
                    .frame(width: 11, height: 7)
                    .offset(x: -29)
                Circle()
                    .fill(Color(red: 1.0, green: 0.56, blue: 0.64).opacity(cheekOpacity))
                    .frame(width: 11, height: 7)
                    .offset(x: 29)
            }
        }
    }

    private var leftEyeExpression: CatEyeExpression {
        guard !eyesClosed else { return .closed }
        return switch personalityPose {
        case .some(.perk): .wide
        case .some(.stretch): .closed
        case .some(.peek), .some(.proud), .none: .open
        }
    }

    private var rightEyeExpression: CatEyeExpression {
        guard !eyesClosed else { return .closed }
        return switch personalityPose {
        case .some(.perk): .wide
        case .some(.stretch): .closed
        case .some(.peek), .some(.proud): .squint
        case .none: .open
        }
    }

    private var mouthWidth: CGFloat {
        switch personalityPose {
        case .some(.perk): 15
        case .some(.stretch): 17
        case .some(.peek): 19
        case .some(.proud), .none: mood == .stormy ? 16 : 22
        }
    }

    private var mouthHeight: CGFloat {
        personalityPose == .perk ? 9 : 6
    }

    private var cheekOpacity: Double {
        switch personalityPose {
        case .some(.perk), .some(.proud): 0.72
        case .some(.peek), .some(.stretch), .none: 0.55
        }
    }
}

private enum CatEyeExpression {
    case open
    case wide
    case squint
    case closed
}

private struct Eye: View {
    let expression: CatEyeExpression

    var body: some View {
        Capsule()
            .fill(Color(red: 0.16, green: 0.13, blue: 0.16))
            .frame(width: width, height: height)
            .overlay(alignment: .topTrailing) {
                if expression == .open || expression == .wide {
                    Circle()
                        .fill(.white.opacity(0.92))
                        .frame(width: 4, height: 4)
                        .offset(x: -3, y: 4)
                }
            }
    }

    private var width: CGFloat {
        expression == .squint ? 15 : 13
    }

    private var height: CGFloat {
        switch expression {
        case .open: 18
        case .wide: 21
        case .squint: 4
        case .closed: 3
        }
    }
}

private struct PauliBody: View {
    let mood: PetWeatherMood
    let blink: Bool
    let bob: Double
    let statusPulse: Double
    let personalityPose: PersonalityPose?

    var body: some View {
        let accent = pauliAccent
        let leftPodLift: CGFloat = switch personalityPose {
        case .some(.peek): -3
        case .some(.perk): -5
        case .some(.stretch): 3
        case .some(.proud), .none: 0
        }
        let rightPodLift: CGFloat = switch personalityPose {
        case .some(.peek): 2
        case .some(.perk): -2
        case .some(.stretch): 3
        case .some(.proud): -3
        case .none: 0
        }
        let antennaAngle: Double = switch personalityPose {
        case .some(.peek): -10
        case .some(.perk): 12
        case .some(.stretch): -5
        case .some(.proud): 6
        case .none: 0
        }
        let statusScale: CGFloat = switch personalityPose {
        case .some(.perk): 1.16
        case .some(.proud): 1.10
        case .some(.peek), .some(.stretch), .none: 1
        }

        ZStack {
            ShadowBlob()
                .offset(y: 62)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.18, green: 0.23, blue: 0.28))
                .frame(width: 64, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                )
                .offset(y: 45 + bob)

            PauliSidePod()
                .fill(Color(red: 0.26, green: 0.36, blue: 0.43))
                .frame(width: 30, height: 54)
                .overlay(
                    PauliSidePod()
                        .stroke(accent.opacity(0.55), lineWidth: 2)
                )
                .offset(x: -61, y: 1 + bob + leftPodLift)

            PauliSidePod()
                .fill(Color(red: 0.26, green: 0.36, blue: 0.43))
                .frame(width: 30, height: 54)
                .scaleEffect(x: -1, y: 1)
                .overlay(
                    PauliSidePod()
                        .stroke(accent.opacity(0.55), lineWidth: 2)
                        .scaleEffect(x: -1, y: 1)
                )
                .offset(x: 61, y: 1 + bob + rightPodLift)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.95, blue: 0.96),
                            Color(red: 0.62, green: 0.78, blue: 0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 2)
                )
                .shadow(color: accent.opacity(0.20), radius: 10, y: 5)
                .offset(y: bob)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.035, green: 0.055, blue: 0.070))
                .frame(width: 88, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.82), lineWidth: 1.6)
                )
                .overlay {
                    PauliFace(
                        accent: accent,
                        blink: blink,
                        mood: mood,
                        personalityPose: personalityPose
                    )
                }
                .offset(y: bob + 2)

            Capsule()
                .fill(Color(red: 0.26, green: 0.36, blue: 0.43))
                .frame(width: 7, height: 20)
                .rotationEffect(.degrees(antennaAngle), anchor: .bottom)
                .offset(y: bob - 56)

            Circle()
                .fill(accent.opacity(statusPulse))
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1.4))
                .shadow(color: accent.opacity(0.65), radius: 8)
                .scaleEffect(statusScale)
                .offset(y: bob - 69)

            HStack(spacing: 22) {
                Capsule()
                    .fill(Color(red: 0.13, green: 0.18, blue: 0.22))
                    .frame(width: 15, height: 22)
                Capsule()
                    .fill(Color(red: 0.13, green: 0.18, blue: 0.22))
                    .frame(width: 15, height: 22)
            }
            .offset(y: bob + 66)
        }
    }

    private var pauliAccent: Color {
        switch mood {
        case .sunny: Color(red: 0.98, green: 0.82, blue: 0.28)
        case .cloudy, .foggy: Color(red: 0.66, green: 0.88, blue: 0.95)
        case .rainy: Color(red: 0.26, green: 0.70, blue: 1.00)
        case .snowy: Color(red: 0.86, green: 0.98, blue: 1.00)
        case .stormy: Color(red: 0.90, green: 0.78, blue: 0.24)
        case .cozy: Color(red: 0.54, green: 0.92, blue: 0.86)
        }
    }
}

private struct PauliFace: View {
    let accent: Color
    let blink: Bool
    let mood: PetWeatherMood
    let personalityPose: PersonalityPose?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 21) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent)
                    .frame(width: leftEyeWidth, height: leftEyeHeight)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent)
                    .frame(width: rightEyeWidth, height: rightEyeHeight)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent.opacity(index == 1 && mood == .stormy ? 0.35 : 0.88))
                        .frame(
                            width: personalityPose == .proud && index == 1 ? 12 : 8,
                            height: mood == .stormy ? 4 : 5
                        )
                }
            }

            HStack(spacing: 7) {
                Circle().fill(accent.opacity(0.32)).frame(width: 4, height: 4)
                Circle().fill(accent.opacity(0.55)).frame(width: 4, height: 4)
                Circle().fill(accent.opacity(0.32)).frame(width: 4, height: 4)
            }
        }
    }

    private var leftEyeWidth: CGFloat {
        personalityPose == .stretch && !blink ? 20 : 17
    }

    private var rightEyeWidth: CGFloat {
        personalityPose == .peek && !blink ? 20 : 17
    }

    private var leftEyeHeight: CGFloat {
        guard !blink else { return 3 }
        return switch personalityPose {
        case .some(.perk): 16
        case .some(.stretch): 4
        case .some(.peek), .some(.proud), .none: 13
        }
    }

    private var rightEyeHeight: CGFloat {
        guard !blink else { return 3 }
        return switch personalityPose {
        case .some(.perk): 16
        case .some(.peek), .some(.proud), .some(.stretch): 4
        case .none: 13
        }
    }
}

private struct PauliSidePod: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY + 8))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - 8),
            control1: CGPoint(x: rect.minX + 4, y: rect.minY + 6),
            control2: CGPoint(x: rect.minX + 4, y: rect.maxY - 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 8),
            control1: CGPoint(x: rect.maxX + 2, y: rect.maxY - 6),
            control2: CGPoint(x: rect.maxX + 2, y: rect.minY + 6)
        )
        return path
    }
}

private struct PetIconButtonStyle: ButtonStyle {
    let tint: Color
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isActive ? .white : .primary)
            .frame(width: 29, height: 27)
            .background(
                isActive ? tint.opacity(configuration.isPressed ? 0.62 : 0.82) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? tint.opacity(0.92) : .white.opacity(configuration.isPressed ? 0.38 : 0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.10), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private struct PetActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(configuration.isPressed ? 0.70 : 0.92), in: Capsule())
    }
}

private struct PetChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? tint.opacity(configuration.isPressed ? 0.70 : 0.92) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.95) : .white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct PetPalette {
    let face: Color
    let body: Color
    let ear: Color
    let tail: Color

    init(mood: PetWeatherMood) {
        switch mood {
        case .sunny:
            face = Color(red: 1.00, green: 0.86, blue: 0.50)
            body = Color(red: 1.00, green: 0.68, blue: 0.42)
            ear = Color(red: 1.00, green: 0.58, blue: 0.42)
            tail = Color(red: 0.96, green: 0.50, blue: 0.36)
        case .rainy:
            face = Color(red: 0.60, green: 0.78, blue: 0.98)
            body = Color(red: 0.38, green: 0.58, blue: 0.90)
            ear = Color(red: 0.48, green: 0.67, blue: 0.94)
            tail = Color(red: 0.30, green: 0.44, blue: 0.72)
        case .snowy:
            face = Color(red: 0.94, green: 0.98, blue: 1.00)
            body = Color(red: 0.74, green: 0.88, blue: 0.98)
            ear = Color(red: 0.82, green: 0.93, blue: 1.00)
            tail = Color(red: 0.68, green: 0.82, blue: 0.92)
        case .stormy:
            face = Color(red: 0.76, green: 0.70, blue: 0.92)
            body = Color(red: 0.48, green: 0.42, blue: 0.70)
            ear = Color(red: 0.60, green: 0.52, blue: 0.78)
            tail = Color(red: 0.36, green: 0.31, blue: 0.58)
        case .cloudy, .foggy:
            face = Color(red: 0.84, green: 0.88, blue: 0.90)
            body = Color(red: 0.62, green: 0.70, blue: 0.75)
            ear = Color(red: 0.72, green: 0.78, blue: 0.82)
            tail = Color(red: 0.54, green: 0.62, blue: 0.68)
        case .cozy:
            face = Color(red: 1.00, green: 0.78, blue: 0.84)
            body = Color(red: 0.72, green: 0.56, blue: 0.94)
            ear = Color(red: 0.86, green: 0.64, blue: 0.94)
            tail = Color(red: 0.58, green: 0.46, blue: 0.84)
        }
    }
}

private struct CatEarView: View {
    let color: Color

    var body: some View {
        ZStack {
            CatEarShape()
                .fill(color)
                .overlay(
                    CatEarShape()
                        .stroke(.white.opacity(0.30), lineWidth: 1.4)
                )

            CatEarShape()
                .fill(Color(red: 1.0, green: 0.57, blue: 0.67).opacity(0.48))
                .frame(width: 27, height: 37)
                .offset(x: -1, y: 7)

            Capsule()
                .fill(.white.opacity(0.24))
                .frame(width: 3, height: 25)
                .rotationEffect(.degrees(13))
                .offset(x: -8, y: -5)
        }
    }
}

private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        path.addCurve(
            to: CGPoint(x: rect.midX - 2, y: rect.minY + 2),
            control1: CGPoint(x: rect.minX + 2, y: rect.midY - 5),
            control2: CGPoint(x: rect.midX - 8, y: rect.minY + 3)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 5),
            control1: CGPoint(x: rect.midX + 4, y: rect.minY - 1),
            control2: CGPoint(x: rect.maxX + 1, y: rect.midY + 3)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3),
            control1: CGPoint(x: rect.maxX - 11, y: rect.maxY + 1),
            control2: CGPoint(x: rect.minX + 13, y: rect.maxY + 1)
        )
        path.closeSubpath()
        return path
    }
}

private struct TailShape: Shape {
    let wag: Double

    var animatableData: Double {
        get { wag }
        set {}
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 20))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 10, y: rect.minY + 18),
            control1: CGPoint(x: rect.midX + CGFloat(wag), y: rect.maxY + 8),
            control2: CGPoint(x: rect.maxX + CGFloat(wag), y: rect.midY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX + 6, y: rect.maxY - 4),
            control1: CGPoint(x: rect.maxX - 28, y: rect.minY + 4),
            control2: CGPoint(x: rect.maxX - 26, y: rect.maxY - 6)
        )
        path.closeSubpath()
        return path
    }
}

private struct ShadowBlob: View {
    var body: some View {
        Ellipse()
            .fill(.black.opacity(0.18))
            .frame(width: 130, height: 24)
            .blur(radius: 5)
    }
}

private struct SleepZ: View {
    let t: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = ((t * 0.5 + Double(index) * 0.66).truncatingRemainder(dividingBy: 2)) / 2
                Text("z")
                    .font(.system(size: 11 + CGFloat(index) * 5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .offset(x: CGFloat(phase) * 18, y: -CGFloat(phase) * 34)
                    .opacity(1 - phase)
            }
        }
        .frame(width: 40, height: 50)
    }
}

private struct Heart: Identifiable {
    let id: Int
    let x: CGFloat
    let drift: CGFloat
    let size: CGFloat
    let color: Color
}

private struct HeartParticleOverlay: View {
    let burst: Int
    let combo: Int
    let reduceMotion: Bool
    @State private var hearts: [Heart] = []
    @State private var nextID = 0

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                FloatingHeart(heart: heart, reduceMotion: reduceMotion)
            }
        }
        .onChange(of: burst) { _, _ in spawn() }
    }

    private func spawn() {
        let palette: [Color] = [.pink, .red, Color(red: 1.0, green: 0.45, blue: 0.6), Color(red: 1.0, green: 0.7, blue: 0.4)]
        let count = min(3 + combo, 9)
        var batch: [Heart] = []
        for _ in 0..<count {
            let heart = Heart(
                id: nextID,
                x: CGFloat.random(in: -34...34),
                drift: CGFloat.random(in: -18...18),
                size: CGFloat.random(in: 12...22),
                color: palette.randomElement() ?? .pink
            )
            nextID += 1
            batch.append(heart)
        }
        let ids = Set(batch.map(\.id))
        hearts.append(contentsOf: batch)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            hearts.removeAll { ids.contains($0.id) }
        }
    }
}

private struct FloatingHeart: View {
    let heart: Heart
    let reduceMotion: Bool
    @State private var rise = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: heart.size))
            .foregroundStyle(heart.color)
            .shadow(color: heart.color.opacity(0.5), radius: 4)
            .offset(
                x: reduceMotion ? heart.x : rise ? heart.x + heart.drift : heart.x,
                y: reduceMotion ? -24 : rise ? -96 : -6
            )
            .opacity(rise ? 0 : 0.95)
            .scaleEffect(reduceMotion ? 0.8 : rise ? 1.15 : 0.4)
            .rotationEffect(
                .degrees(reduceMotion ? 0 : Double(heart.drift) * 0.6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 1.2)) {
                    rise = true
                }
            }
    }
}

private struct ComboBadge: View {
    let count: Int

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.42, blue: 0.62), Color(red: 1.0, green: 0.66, blue: 0.36)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .pink.opacity(0.4), radius: 4, y: 1)
            .accessibilityLabel("\(count) pat combo")
    }

    private var label: String {
        switch count {
        case 8...: "×\(count) amazing!"
        case 5...: "×\(count) great!"
        default: "×\(count) combo!"
        }
    }
}
