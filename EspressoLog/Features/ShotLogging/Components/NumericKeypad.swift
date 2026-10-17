import SwiftUI

/// Compact in-app numeric keypad. Avoids the system keyboard so input stays one-handed,
/// predictable, and never covers the tiles being edited.
struct NumericKeypad: View {
    let field: NumericField
    var method: BrewMethod = .espresso
    var onKey: (KeypadKey) -> Void
    var onNudge: (Int) -> Void
    var onNext: () -> Void
    var onDone: () -> Void

    private let keyHeight: CGFloat = 46
    private let spacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(field.label(for: method).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                nudgeButton(-1)
                nudgeButton(1)
                Button("Done", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .padding(.leading, 4)
            }

            HStack(alignment: .top, spacing: spacing) {
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    GridRow { key(.digit(1)); key(.digit(2)); key(.digit(3)) }
                    GridRow { key(.digit(4)); key(.digit(5)); key(.digit(6)) }
                    GridRow { key(.digit(7)); key(.digit(8)); key(.digit(9)) }
                    GridRow {
                        key(.decimal).disabled(field.fractionDigits == 0)
                        key(.digit(0))
                        key(.delete)
                    }
                }

                Button(action: onNext) {
                    VStack(spacing: 4) {
                        Image(systemName: field.next == nil ? "checkmark" : "arrow.right")
                        Text(field.next?.label(for: method) ?? "Done")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .buttonStyle(KeypadButtonStyle(prominent: true))
                .frame(width: 76)
            }
            .frame(height: keyHeight * 4 + spacing * 3)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func key(_ key: KeypadKey) -> some View {
        Button { onKey(key) } label: {
            switch key {
            case .digit(let digit): Text("\(digit)")
            case .decimal: Text(ShotLoggingViewModel.decimalSeparator)
            case .delete: Image(systemName: "delete.left")
            }
        }
        .buttonStyle(KeypadButtonStyle())
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    private func nudgeButton(_ direction: Int) -> some View {
        let step = field.nudgeStep(for: method)
        let text = step < 1 ? step.fixed() : step.trimmed
        return Button { onNudge(direction) } label: {
            Text("\(direction < 0 ? "−" : "+")\(text)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func accessibilityLabel(for key: KeypadKey) -> String {
        switch key {
        case .digit(let digit): "\(digit)"
        case .decimal: "Decimal point"
        case .delete: "Delete"
        }
    }
}

struct KeypadButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title2, design: .rounded, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
