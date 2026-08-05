import SwiftUI

struct PetInteractionCallout: View {
  let text: String
  @Environment(\.colorSchemeContrast) private var systemContrast
  @Environment(\.petAccessibilityContrastOverride) private var contrastOverride

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .heavy, design: .rounded))
      .multilineTextAlignment(.center)
      .foregroundStyle(contrastStyle.isIncreased ? Color.primary : Color.pink)
      .lineLimit(2)
      .minimumScaleFactor(0.88)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: 106)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .petContrastSurface(
        cornerRadius: 999,
        borderOpacity: 0.38,
        shadowOpacity: 0.08,
        shadowRadius: 4,
        shadowY: 2
      )
      .allowsHitTesting(false)
      .accessibilityLabel(text)
  }

  private var contrastStyle: PetAccessibilityContrastStyle {
    PetAccessibilityContrastStyle.resolve(
      systemContrast: systemContrast,
      override: contrastOverride
    )
  }
}
