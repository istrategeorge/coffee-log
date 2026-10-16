import SwiftUI

/// Tactile grind selector: big readout, ±0.1 steppers (hold to repeat), a snapping
/// ruler wheel (positive values only: 0.0 – 10.0), and an integer 0-point offset control.
struct GrindDial: View {
    @Binding var tenths: Int
    @Binding var zeroOffset: Int
    var range: ClosedRange<Int> = 0...100
    var isChanged = false

    @State private var scrolledTick: Int?
    private let tickWidth: CGFloat = 10

    private var valueText: String { (Double(max(0, tenths)) / 10).fixed() }
    private var offsetText: String { zeroOffset > 0 ? "+\(zeroOffset)" : "\(zeroOffset)" }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel("Grind")
                if isChanged {
                    Circle().fill(.tint).frame(width: 5, height: 5)
                }
                Spacer()
                zeroOffsetControl
            }

            HStack(spacing: 20) {
                stepButton(systemImage: "minus", delta: -1)
                Text(valueText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(tenths)))
                    .frame(minWidth: 120)
                    .accessibilityLabel("Grind setting \(valueText)")
                stepButton(systemImage: "plus", delta: 1)
            }

            ruler
        }
        .padding()
        .cardBackground()
        .sensoryFeedback(.selection, trigger: tenths)
        .sensoryFeedback(.selection, trigger: zeroOffset)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private var zeroOffsetControl: some View {
        HStack(spacing: 6) {
            Text("0-Point Offset")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Button {
                    zeroOffset = max(-10, zeroOffset - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)

                Text(offsetText)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(zeroOffset == 0 ? Color.secondary : Color.accentColor)
                    .frame(minWidth: 26)

                Button {
                    zeroOffset = min(10, zeroOffset + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }

    private var ruler: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(range, id: \.self) { tick in
                        TickMark(tick: tick)
                            .frame(width: tickWidth)
                            .id(tick)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, max(0, (proxy.size.width - tickWidth) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledTick, anchor: .center)
        }
        .frame(height: 48)
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .top) {
            Capsule().fill(.tint).frame(width: 3, height: 30)
        }
        .onAppear { scrolledTick = tenths }
        .onChange(of: scrolledTick) { _, newValue in
            if let newValue, newValue != tenths { tenths = max(0, newValue) }
        }
        .onChange(of: tenths) { _, newValue in
            if scrolledTick != newValue {
                withAnimation(.snappy) { scrolledTick = newValue }
            }
        }
        .accessibilityHidden(true)
    }

    private func stepButton(systemImage: String, delta: Int) -> some View {
        Button { step(delta) } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(delta < 0 && tenths <= range.lowerBound)
        .accessibilityLabel(delta < 0 ? "Finer" : "Coarser")
    }

    private func step(_ delta: Int) {
        tenths = min(max(tenths + delta, max(0, range.lowerBound)), range.upperBound)
    }
}

private struct TickMark: View {
    let tick: Int

    var body: some View {
        let isMajor = tick % 10 == 0
        let isHalf = tick % 5 == 0
        VStack(spacing: 3) {
            Rectangle()
                .fill(isMajor ? Color.primary : Color.secondary.opacity(isHalf ? 0.8 : 0.4))
                .frame(width: isMajor ? 2 : 1, height: isMajor ? 26 : (isHalf ? 18 : 12))
                .frame(height: 26, alignment: .top)
            Text(isMajor ? "\(tick / 10)" : " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
}
