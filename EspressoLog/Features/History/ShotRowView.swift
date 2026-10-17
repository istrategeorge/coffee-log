import SwiftUI

/// A6-notebook-style compact row:
///
/// ```
///  #3  │ 20.0g → 48.5g (27.0s)  1:2.43        ★
/// 24/09│ G -0.5 @1100 | Slow | PB 3/5 | 94.0°C
///  R18 │ 💧 Choked  Juicy Peach · Honey
///      │ ↳ Go finer (-0.7)
/// ```
struct ShotRowView: View {
    let shot: ShotLog
    var number: Int?
    var showsBeanName = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            indexColumn
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 4) {
                headline
                Text(shot.notebookLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let equipment = shot.equipment {
                    Label(
                        equipment.fullLine(for: shot.brewMethod, dripper: shot.dripper),
                        systemImage: shot.brewMethod == .pourOver ? "mug" : "espressomachine"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                notesLine
                if let tweak = shot.actionableNextTweak, !tweak.isEmpty {
                    Label(tweak, systemImage: "arrow.turn.down.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var indexColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number.map { "#\($0)" } ?? "•")
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(shot.timestamp, format: .dateTime.day(.twoDigits).month(.twoDigits))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("R\(shot.restDaysAtBrew)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
        }
        .frame(width: 42, alignment: .leading)
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            BrewMethodBadge(method: shot.brewMethod, dripper: shot.dripper)
            Text(ShotFormatter.headline(dose: shot.dose, yield: shot.yield, time: shot.totalTime, method: shot.brewMethod))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(ShotFormatter.ratio(shot.ratio, method: shot.brewMethod))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            BalanceGlyph(balance: shot.tasteBalance)
        }
    }

    @ViewBuilder
    private var notesLine: some View {
        let notes = shot.flavorNotes.joined(separator: " · ")
        if shot.flowQuality.isIssue || !notes.isEmpty || showsBeanName {
            HStack(spacing: 6) {
                FlowBadge(flow: shot.flowQuality, method: shot.brewMethod)
                if showsBeanName, let bean = shot.bean {
                    Text(bean.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                if !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Page header mirroring the paper log: bean, roast date, rest, basket/dripper, grinder.
struct NotebookHeader: View {
    let bean: CoffeeBean
    let equipment: EquipmentProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ESPRESSO & POUR OVER LOG")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Text("\(bean.name) (\(bean.roaster))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    field("R", value: bean.roastDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))
                    field("Basket", value: equipment?.basket ?? "—")
                }
                GridRow {
                    field("Rest", value: "Day \(bean.restDays)\(bean.isFrozen ? " ❄︎" : "")")
                    field("Grinder", value: equipment?.grinderName ?? "—")
                }
                if let dripper = equipment?.defaultDripper, !dripper.isEmpty {
                    GridRow {
                        field("Bag", value: "\(bean.remainingGrams.fixed(0))g / \(bean.bagWeightGrams.fixed(0))g")
                        field("Dripper", value: dripper)
                    }
                }
            }
            .font(.subheadline)

            Rectangle()
                .fill(.primary)
                .frame(height: 1.5)
        }
        .padding(.vertical, 4)
    }

    private func field(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):").foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).lineLimit(1)
        }
    }
}
