import DeskPetCore
import SwiftUI

struct PersonalityBubble: View {
    let moment: PersonalityMoment
    let layout: PetBubbleLayout

    var body: some View {
        Text(moment.line)
            .font(Font.system(size: 11, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .lineLimit(isSideMounted ? 4 : 2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(
                width: bubbleWidth,
                height: bubbleHeight
            )
            .petContrastSurface(
                cornerRadius: 16,
                borderOpacity: 0.42,
                shadowOpacity: 0.12,
                shadowRadius: 9,
                shadowY: 4
            )
            .overlay(alignment: tailAlignment) {
                SpeechTail()
                    .fill(tailColor)
                    .frame(width: 18, height: 10)
                    .rotationEffect(tailRotation)
                    .offset(
                        x: tailOffset.width,
                        y: tailOffset.height
                    )
            }
            .accessibilityLabel(moment.line)
            .accessibilityAddTraits(.isStaticText)
    }

    private var isSideMounted: Bool {
        layout.tailEdge != .bottom
    }

    private var bubbleWidth: CGFloat {
        CGFloat(layout.bubbleWidth)
    }

    private var bubbleHeight: CGFloat? {
        layout.bubbleHeight.map { CGFloat($0) }
    }

    private var tailAlignment: Alignment {
        switch layout.tailEdge {
        case .bottom:
            .bottom
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }

    private var tailRotation: Angle {
        switch layout.tailEdge {
        case .bottom:
            .zero
        case .leading:
            .degrees(90)
        case .trailing:
            .degrees(-90)
        }
    }

    private var tailOffset: CGSize {
        switch layout.tailEdge {
        case .bottom:
            CGSize(
                width: layout.tailHorizontalOffset,
                height: 8
            )
        case .leading:
            CGSize(
                width: -8,
                height: layout.tailVerticalOffset
            )
        case .trailing:
            CGSize(
                width: 8,
                height: layout.tailVerticalOffset
            )
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
