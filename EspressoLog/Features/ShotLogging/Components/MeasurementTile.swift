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
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if isChanged {
                        Circle().fill(.tint).frame(width: 5, height: 5)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text)
                        .font(.system(compact ? .title3 : .title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(text) \(unit)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
