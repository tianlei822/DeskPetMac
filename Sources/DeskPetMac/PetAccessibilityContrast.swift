import SwiftUI

enum PetAccessibilityContrastMode: Equatable, Sendable {
  case standard
  case increased
}

private struct PetAccessibilityContrastOverrideKey: EnvironmentKey {
  static let defaultValue: PetAccessibilityContrastMode? = nil
}

extension EnvironmentValues {
  var petAccessibilityContrastOverride: PetAccessibilityContrastMode? {
    get { self[PetAccessibilityContrastOverrideKey.self] }
    set { self[PetAccessibilityContrastOverrideKey.self] = newValue }
  }
}

struct PetAccessibilityContrastStyle: Equatable, Sendable {
  let isIncreased: Bool
  let surfaceBorderOpacityMultiplier: Double
  let surfaceBorderWidth: Double
  let shadowOpacityMultiplier: Double
  let selectedFillOpacity: Double
  let unselectedFillOpacity: Double
  let usesPrimarySupportingText: Bool
  let usesDarkButtonLabel: Bool

  static func resolve(
    systemContrast: ColorSchemeContrast,
    override: PetAccessibilityContrastMode?
  ) -> PetAccessibilityContrastStyle {
    let isIncreased =
      switch override {
      case .standard:
        false
      case .increased:
        true
      case nil:
        systemContrast == .increased
      }

    return PetAccessibilityContrastStyle(
      isIncreased: isIncreased,
      surfaceBorderOpacityMultiplier: isIncreased ? 1.85 : 1,
      surfaceBorderWidth: isIncreased ? 1.6 : 1,
      shadowOpacityMultiplier: isIncreased ? 1.55 : 1,
      selectedFillOpacity: isIncreased ? 0.28 : 0.16,
      unselectedFillOpacity: isIncreased ? 0.13 : 0.07,
      usesPrimarySupportingText: isIncreased,
      usesDarkButtonLabel: isIncreased
    )
  }
}

enum PetSupportingTextRole {
  case secondary
  case tertiary
}

extension View {
  func petSupportingForeground(
    _ role: PetSupportingTextRole
  ) -> some View {
    modifier(PetSupportingForegroundModifier(role: role))
  }

  func petContrastSurface(
    cornerRadius: CGFloat,
    borderOpacity: Double,
    shadowOpacity: Double = 0,
    shadowRadius: CGFloat = 0,
    shadowY: CGFloat = 0
  ) -> some View {
    modifier(
      PetContrastSurfaceModifier(
        cornerRadius: cornerRadius,
        borderOpacity: borderOpacity,
        shadowOpacity: shadowOpacity,
        shadowRadius: shadowRadius,
        shadowY: shadowY
      ))
  }
}

private struct PetSupportingForegroundModifier: ViewModifier {
  let role: PetSupportingTextRole

  @Environment(\.colorSchemeContrast) private var systemContrast
  @Environment(\.petAccessibilityContrastOverride) private var contrastOverride

  func body(content: Content) -> some View {
    content.foregroundStyle(foregroundStyle)
  }

  private var foregroundStyle: AnyShapeStyle {
    let style = PetAccessibilityContrastStyle.resolve(
      systemContrast: systemContrast,
      override: contrastOverride
    )
    if style.usesPrimarySupportingText {
      return AnyShapeStyle(Color.primary.opacity(role == .secondary ? 0.92 : 0.78))
    }
    return switch role {
    case .secondary:
      AnyShapeStyle(.secondary)
    case .tertiary:
      AnyShapeStyle(.tertiary)
    }
  }
}

private struct PetContrastSurfaceModifier: ViewModifier {
  let cornerRadius: CGFloat
  let borderOpacity: Double
  let shadowOpacity: Double
  let shadowRadius: CGFloat
  let shadowY: CGFloat

  @Environment(\.colorSchemeContrast) private var systemContrast
  @Environment(\.petAccessibilityContrastOverride) private var contrastOverride

  func body(content: Content) -> some View {
    let style = PetAccessibilityContrastStyle.resolve(
      systemContrast: systemContrast,
      override: contrastOverride
    )
    let shape = RoundedRectangle(
      cornerRadius: cornerRadius,
      style: .continuous
    )

    content
      .background(
        style.isIncreased
          ? AnyShapeStyle(.thickMaterial)
          : AnyShapeStyle(.regularMaterial),
        in: shape
      )
      .overlay(
        shape.stroke(
          style.isIncreased
            ? Color.primary.opacity(min(0.82, borderOpacity * style.surfaceBorderOpacityMultiplier))
            : Color.white.opacity(borderOpacity),
          lineWidth: style.surfaceBorderWidth
        )
      )
      .shadow(
        color: .black.opacity(
          shadowOpacity * style.shadowOpacityMultiplier
        ),
        radius: shadowRadius,
        y: shadowY
      )
  }
}
