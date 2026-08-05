import DeskPetCore
import SwiftUI

struct PetTreatView: View {
    let kind: PetKind
    let phase: PetTreatPhase

    var body: some View {
        Text(symbol)
            .font(.system(size: 24))
            .shadow(color: glowColor.opacity(0.45), radius: 5, y: 2)
            .frame(width: 36, height: 36)
            .accessibilityLabel("Treat for \(kind.displayName)")
            .accessibilityValue(phaseLabel)
    }

    private var symbol: String {
        switch kind {
        case .cat:
            "🐟"
        case .pauli:
            "⚡️"
        case .dog:
            "🦴"
        }
    }

    private var glowColor: Color {
        switch kind {
        case .cat:
            .cyan
        case .pauli:
            .yellow
        case .dog:
            .orange
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .tossing:
            "Tossing"
        case .watching:
            "Watching"
        case .approaching:
            "Approaching"
        case .sniffing:
            "Sniffing"
        case .eating:
            "Eating"
        case .satisfied:
            "Satisfied"
        case .completed:
            "Finished"
        }
    }
}
