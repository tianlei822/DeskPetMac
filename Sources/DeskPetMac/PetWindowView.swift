import DeskPetCore
import AppKit
import SwiftUI

struct PetWindowView: View {
    @ObservedObject var model: PetViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .top) {
            WeatherParticles(mood: model.mood)
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Spacer(minLength: 38)
                Button {
                    model.pat()
                } label: {
                    PetBody(
                        kind: model.petKind,
                        mood: model.mood,
                        isHovering: hover,
                        pulse: model.affectionPulse,
                        isSleeping: model.isSleeping,
                        isDancing: model.isDancing,
                        personalityPose: model.activePersonalityMoment?.pose,
                        reduceMotion: reduceMotion
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pat \(model.petKind.displayName)")

                ControlStrip(model: model, isVisible: controlsVisible)
                Spacer(minLength: 6)
            }
            .padding(10)

            HeartParticleOverlay(burst: model.heartBurst, combo: model.comboCount)
                .allowsHitTesting(false)
                .offset(y: 78)

            bubbleOverlay
                .padding(.top, 6)
        }
        .overlay(alignment: .topTrailing) {
            if model.comboCount >= 2 {
                ComboBadge(count: model.comboCount)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(.clear)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: hover)
        .animation(.spring(response: 0.30, dampingFraction: 0.70), value: model.affectionPulse)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: model.comboCount)
        .animation(.easeInOut(duration: 0.3), value: model.isSleeping)
        .animation(.easeInOut(duration: 0.22), value: model.isReminderVisible)
        .animation(.easeInOut(duration: 0.22), value: model.isStatusVisible)
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
            || model.isRefreshingWeather
            || model.isReminderVisible
    }

    @ViewBuilder
    private var bubbleOverlay: some View {
        if model.isReminderVisible {
            BreakBubble(model: model)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if hover
            || model.isStatusVisible
            || model.isRefreshingWeather
            || model.isPetPickerVisible
            || model.isSettingsVisible {
            StatusBubble(model: model)
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

private struct StatusBubble: View {
    @ObservedObject var model: PetViewModel

    var body: some View {
        VStack(spacing: 4) {
            Text("\(model.petKind.displayName) - \(model.mood.petLine)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                Text("\(model.weather.locationName) \(model.weather.temperatureLabel)")
                Text("Focus \(model.activeMinutes)m")
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)

            ProgressView(value: model.workProgress)
                .controlSize(.small)
                .tint(.mint)
                .frame(width: 124)

            BondReadout(model: model)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
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
            .help("Choose cat or Pauli")
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
                    }
                }
                .padding(14)
            }

            Button {
                model.takeBreak()
            } label: {
                Image(systemName: "figure.stand")
            }
            .help("Mark break taken")
            .buttonStyle(PetIconButtonStyle(tint: .mint, isActive: model.workProgress == 0))

            Button {
                model.dance()
            } label: {
                Image(systemName: "music.note")
            }
            .help("Make the pet dance")
            .buttonStyle(PetIconButtonStyle(tint: .purple, isActive: model.isDancing))

            Button {
                Task { await model.refreshWeather() }
            } label: {
                Image(systemName: "cloud.sun")
                    .rotationEffect(.degrees(model.isRefreshingWeather ? 360 : 0))
                    .animation(
                        model.isRefreshingWeather
                            ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                            : .easeOut(duration: 0.18),
                        value: model.isRefreshingWeather
                    )
            }
            .help("Refresh weather")
            .buttonStyle(PetIconButtonStyle(tint: .cyan, isActive: model.isRefreshingWeather))

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

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark")
            }
            .help("Quit DeskPet")
            .buttonStyle(PetIconButtonStyle(tint: .red, isActive: false))
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 5)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

private struct PetBody: View {
    let kind: PetKind
    let mood: PetWeatherMood
    let isHovering: Bool
    let pulse: Int
    let isSleeping: Bool
    let isDancing: Bool
    let personalityPose: PersonalityPose?
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let danceBob = isDancing ? abs(sin(t * 9.0)) * 8 : 0
            let idleBob = isSleeping
                ? sin(t * 1.1) * 1.6
                : sin(t * (kind == .pauli ? 2.8 : 2.4)) * 4
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
            let tail = sin(t * (isDancing ? 9.0 : 5.0)) * (isDancing ? 14 : 8)
            let eyesClosed = isSleeping || Int(t * 1.2) % 7 == 0
            let scale = isHovering ? 1.035 : 1.0
            let statusPulse = 0.78 + abs(sin(t * 3.4)) * 0.22
            let danceTilt = isDancing ? sin(t * 9.0) * 9 : 0
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
                if kind == .pauli {
                    PauliBody(
                        mood: mood,
                        blink: eyesClosed,
                        bob: bob,
                        statusPulse: statusPulse,
                        personalityPose: personalityPose
                    )
                } else {
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
                        eyesClosed: eyesClosed,
                        mood: mood,
                        personalityPose: personalityPose
                    )
                        .offset(y: bob + 4)
                }

                MoodAccessory(mood: mood)
                    .scaleEffect(kind == .pauli ? 0.66 : 0.86)
                    .offset(x: kind == .pauli ? 44 : 0, y: kind == .pauli ? bob - 4 : bob)

                if isSleeping {
                    SleepZ(t: t)
                        .offset(x: kind == .pauli ? 50 : 44, y: -52 + bob)
                        .transition(.opacity)
                }
            }
            .frame(width: 156, height: 158)
            .rotationEffect(.degrees(danceTilt + personalityTilt))
            .scaleEffect(scale + (pulse.isMultiple(of: 2) ? 0 : 0.015))
        }
    }

    private var palette: PetPalette {
        PetPalette(mood: mood)
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

private struct MoodAccessory: View {
    let mood: PetWeatherMood

    var body: some View {
        switch mood {
        case .sunny:
            Circle()
                .fill(Color.yellow.opacity(0.86))
                .frame(width: 26, height: 26)
                .offset(x: 50, y: -52)
        case .cloudy:
            CloudPuff()
                .fill(Color.white.opacity(0.82))
                .frame(width: 58, height: 24)
                .offset(x: 0, y: -61)
        case .foggy:
            VStack(spacing: 5) {
                Capsule().fill(.white.opacity(0.45)).frame(width: 66, height: 4)
                Capsule().fill(.white.opacity(0.36)).frame(width: 48, height: 4)
            }
            .offset(y: -62)
        case .rainy:
            Capsule()
                .fill(Color(red: 0.42, green: 0.68, blue: 0.92))
                .frame(width: 76, height: 26)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(red: 0.30, green: 0.44, blue: 0.70))
                        .frame(width: 6, height: 24)
                        .offset(y: 21)
                }
                .offset(y: -58)
        case .snowy:
            Circle()
                .stroke(Color.white.opacity(0.92), lineWidth: 3)
                .frame(width: 24, height: 24)
                .offset(x: -48, y: -49)
        case .stormy:
            LightningBolt()
                .fill(Color.yellow)
                .frame(width: 28, height: 42)
                .offset(x: 42, y: -48)
        case .cozy:
            Capsule()
                .fill(Color(red: 0.78, green: 0.60, blue: 0.94))
                .frame(width: 74, height: 18)
                .rotationEffect(.degrees(-8))
                .offset(y: -54)
        }
    }
}

private struct WeatherParticles: View {
    let mood: PetWeatherMood

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                switch mood {
                case .rainy:
                    ForEach(0..<12, id: \.self) { index in
                        Capsule()
                            .fill(Color.blue.opacity(0.50))
                            .frame(width: 3, height: 14)
                            .offset(
                                x: CGFloat((index * 29) % 190) - 95,
                                y: CGFloat((Int(t * 72) + index * 23) % 220) - 110
                            )
                    }
                case .snowy:
                    ForEach(0..<14, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(0.76))
                            .frame(width: 5, height: 5)
                            .offset(
                                x: CGFloat((index * 31) % 190) - 95 + CGFloat(sin(t + Double(index))) * 6,
                                y: CGFloat((Int(t * 24) + index * 19) % 210) - 105
                            )
                    }
                case .sunny:
                    Circle()
                        .stroke(Color.yellow.opacity(0.24), lineWidth: 12)
                        .frame(width: 118, height: 118)
                        .scaleEffect(1 + sin(t * 1.5) * 0.04)
                        .offset(y: 20)
                case .stormy:
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.purple.opacity(0.12 + abs(sin(t * 4)) * 0.08))
                        .frame(width: 204, height: 226)
                case .cloudy, .foggy, .cozy:
                    EmptyView()
                }
            }
        }
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

private struct CloudPuff: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX, y: rect.midY - 8, width: 26, height: 18))
        path.addEllipse(in: CGRect(x: rect.minX + 15, y: rect.minY, width: 28, height: 28))
        path.addEllipse(in: CGRect(x: rect.maxX - 26, y: rect.midY - 8, width: 26, height: 18))
        path.addRoundedRect(in: CGRect(x: rect.minX + 8, y: rect.midY - 4, width: rect.width - 16, height: 15), cornerSize: CGSize(width: 8, height: 8))
        return path
    }
}

private struct LightningBolt: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.midY + 2))
        path.addLine(to: CGPoint(x: rect.midX - 2, y: rect.midY + 2))
        path.addLine(to: CGPoint(x: rect.midX - 6, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.midY - 4))
        path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.midY - 4))
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
    @State private var hearts: [Heart] = []
    @State private var nextID = 0

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                FloatingHeart(heart: heart)
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
    @State private var rise = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: heart.size))
            .foregroundStyle(heart.color)
            .shadow(color: heart.color.opacity(0.5), radius: 4)
            .offset(x: rise ? heart.x + heart.drift : heart.x, y: rise ? -96 : -6)
            .opacity(rise ? 0 : 0.95)
            .scaleEffect(rise ? 1.15 : 0.4)
            .rotationEffect(.degrees(Double(heart.drift) * 0.6))
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { rise = true }
            }
    }
}

private struct ComboBadge: View {
    let count: Int

    var body: some View {
        Text("×\(count) combo!")
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
    }
}

private struct BondReadout: View {
    @ObservedObject var model: PetViewModel

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < model.bondHearts ? "heart.fill" : "heart")
                        .font(.system(size: 8))
                        .foregroundStyle(index < model.bondHearts ? .pink : .secondary.opacity(0.5))
                }
                Text(model.bondTitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.bondProgress)
                .controlSize(.small)
                .tint(.pink)
                .frame(width: 124)
        }
    }
}
