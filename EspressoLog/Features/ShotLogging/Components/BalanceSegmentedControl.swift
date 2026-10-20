import SwiftUI

/// `Sour (−) | Sweet / Balanced (★) | Bitter (+) | Astringent (Ast)`
struct BalanceSegmentedControl: View {
    @Binding var selection: TasteBalance?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TasteBalance.allCases) { balance in
                let isSelected = selection == balance
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = balance }
                } label: {
                    VStack(spacing: 3) {
                        Text(balance.glyph)
                            .font(.mono(balance == .astringentDryChalky ? .subheadline : .title3, weight: .semibold))
                            .foregroundStyle(isSelected ? Palette.paper : balance.tint)
                            .frame(height: 24)
                        Text(balance.segmentLabel)
                            .font(.caption.weight(isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .background(isSelected ? balance.tint : Palette.card, in: shape)
                    .overlay(shape.strokeBorder(isSelected ? Color.clear : Palette.rule, lineWidth: 1))
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(balance.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
