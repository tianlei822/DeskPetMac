import DeskPetCore
import SwiftUI

struct PetToyView: View {
    let kind: PetToyKind

    var body: some View {
        Group {
            switch kind {
            case .laser:
                ZStack {
                    Circle()
                        .stroke(.red.opacity(0.35), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(.red)
                        .frame(width: 9, height: 9)
                }
                .shadow(color: .red.opacity(0.75), radius: 6)
            case .energyNode:
                Image(systemName: "bolt.hexagon.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.cyan, .blue.opacity(0.65))
                    .shadow(color: .cyan.opacity(0.65), radius: 7)
            case .ball:
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Capsule()
                        .fill(.white.opacity(0.78))
                        .frame(width: 5, height: 22)
                        .rotationEffect(.degrees(36))
                }
                .frame(width: 25, height: 25)
                .shadow(color: .black.opacity(0.22), radius: 4, y: 3)
            }
        }
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        .accessibilityLabel(kind.displayName)
        .accessibilityHint("Drag to play with the pet")
    }
}
