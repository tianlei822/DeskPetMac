import DeskPetCore
import SwiftUI

struct PersonalityBubble: View {
    let moment: PersonalityMoment

    var body: some View {
        Text(moment.line)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(foregroundColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 194)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                SpeechTail()
                    .fill(tailColor)
                    .frame(width: 18, height: 10)
                    .offset(y: 8)
            }
            .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
            .accessibilityLabel(moment.line)
            .accessibilityAddTraits(.isStaticText)
    }

    private var foregroundColor: Color {
        switch moment.petKind {
        case .cat:
            Color(red: 0.31, green: 0.22, blue: 0.25)
        case .pauli:
            Color(red: 0.20, green: 0.31, blue: 0.38)
        case .dog:
            Color(red: 0.48, green: 0.25, blue: 0.08)
        }
    }

    private var tailColor: Color {
        switch moment.petKind {
        case .cat:
            Color(red: 1.00, green: 0.96, blue: 0.90).opacity(0.88)
        case .pauli:
            Color(red: 0.91, green: 0.98, blue: 0.98).opacity(0.88)
        case .dog:
            Color(red: 1.00, green: 0.91, blue: 0.76).opacity(0.88)
        }
    }
}

private struct SpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.midX - 1, y: rect.maxY - 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX + 1, y: rect.maxY - 2)
        )
        path.closeSubpath()
        return path
    }
}
