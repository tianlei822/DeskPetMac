import AppKit
import DeskPetCore
import SwiftUI

struct PetMenuView: View {
    @ObservedObject var model: PetViewModel
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.petAccessibilityContrastOverride) private var contrastOverride

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DeskPet")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(model.petDisplayName) · \(model.bondTitle) · \(model.mood.displayName)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .petSupportingForeground(.secondary)
                }
                Spacer()
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(.pink)
            }

            HStack(spacing: 8) {
                ForEach(PetKind.allCases, id: \.self) { kind in
                    Button {
                        model.selectPetKind(kind)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: symbol(for: kind))
                                .font(.system(size: 18, weight: .semibold))
                            Text(kind.displayName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(
                        model.petKind == kind
                            ? Color.accentColor.opacity(contrast.selectedFillOpacity)
                            : Color.secondary.opacity(contrast.unselectedFillOpacity),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        if contrast.isIncreased {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    model.petKind == kind
                                        ? Color.accentColor
                                        : Color.primary.opacity(0.48),
                                    lineWidth: model.petKind == kind ? 2 : 1
                                )
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if contrast.isIncreased, model.petKind == kind {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .padding(4)
                        }
                    }
                    .accessibilityLabel("Use \(kind.displayName)")
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                TextField(
                    "Pet nickname",
                    text: Binding(
                        get: { model.learnedName },
                        set: { model.setLearnedName($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                if let preferredInteractionSummary = model.preferredInteractionSummary {
                    Text(preferredInteractionSummary)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .petSupportingForeground(.secondary)
                }
            }

            Button {
                model.toggleToy()
            } label: {
                Label(model.toyActionTitle, systemImage: toySymbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.activeToyKind == nil ? .accentColor : .secondary)

            Button {
                model.takeStroll()
            } label: {
                Label(
                    model.rootMotionRequest == nil
                        ? "Take a Stroll"
                        : "Change Route",
                    systemImage: "figure.walk"
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Moves the companion safely across this display")

            HStack(spacing: 8) {
                actionButton("Pat", systemImage: "hand.tap.fill") {
                    model.pat()
                }
                actionButton("Dance", systemImage: "music.note") {
                    model.dance()
                }
                actionButton("Treat", systemImage: "gift.fill") {
                    model.giveTreat()
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Stretch reminder")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(Int(model.reminderMinutes))m")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .petSupportingForeground(.secondary)
                }
                Slider(value: $model.reminderMinutes, in: 20...90, step: 5)
            }

            Toggle(isOn: $model.isQuietModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiet Mode")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("Pause ambient bubbles and reminders")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .petSupportingForeground(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $model.isSoundEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interaction Feedback")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("Sound + trackpad tap · opt-in")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .petSupportingForeground(.secondary)
                }
            }
            .toggleStyle(.switch)

            Divider()

            HStack {
                Button("Refresh Weather") {
                    Task { await model.refreshWeather() }
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .padding(16)
        .frame(width: 280)
    }

    private var contrast: PetAccessibilityContrastStyle {
        PetAccessibilityContrastStyle.resolve(
            systemContrast: systemContrast,
            override: contrastOverride
        )
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
    }

    private func symbol(for kind: PetKind) -> String {
        switch kind {
        case .cat:
            "cat.fill"
        case .pauli:
            "cpu.fill"
        case .dog:
            "dog.fill"
        }
    }

    private var toySymbol: String {
        switch PetToyKind.forPet(model.petKind) {
        case .laser:
            "scope"
        case .energyNode:
            "bolt.hexagon.fill"
        case .ball:
            "circle.fill"
        }
    }
}
