import SwiftUI

/// Tappable value tile. Tapping selects the field for the keypad.
struct MeasurementTile: View {
    let field: NumericField
    var method: BrewMethod = .espresso
    let text: String
    var caption: String?
    let isActive: Bool
    let isChanged: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        let label = field.label(for: method)
        let unit = field.unit(for: method)
        let shape = RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(isActive ? Palette.accent : Palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if isChanged {
                        Circle().fill(.tint).frame(width: 5, height: 5)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text)
                        .font(.mono(compact ? .title3 : .title2, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.mono(.caption2, weight: .medium))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, 12)
            .background(Palette.card, in: shape)
            .overlay(shape.strokeBorder(isActive ? Palette.accent : Palette.rule, lineWidth: isActive ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(text) \(unit)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
