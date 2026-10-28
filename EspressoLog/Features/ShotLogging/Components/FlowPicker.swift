import SwiftUI

/// `Smooth | Gushing | Choked | Channel` (or the pour over bed reads), as tinted option tiles.
struct FlowPicker: View {
    let method: BrewMethod
    @Binding var selection: FlowQuality

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FlowQuality.allCases) { flow in
                let isSelected = selection == flow
                Button {
                    withAnimation(.snappy) { selection = flow }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: flow.symbol(for: method))
                            .font(.headline)
                        Text(flow.label(for: method))
                            .font(.caption.weight(isSelected ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .optionTile(isSelected: isSelected, tint: flow.tint)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
