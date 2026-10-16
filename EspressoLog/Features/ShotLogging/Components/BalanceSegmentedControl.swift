import SwiftUI

/// `Sour (−) | Sweet / Balanced (★) | Bitter (+) | Astringent (Ast)`
struct BalanceSegmentedControl: View {
    @Binding var selection: TasteBalance?
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TasteBalance.allCases) { balance in
                let isSelected = selection == balance
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = balance }
                } label: {
                    VStack(spacing: 2) {
                        Text(balance.glyph)
                            .font(.headline)
                        Text(balance.segmentLabel)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(balance.tint)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(balance.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
