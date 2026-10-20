import SwiftUI

/// One pull as a notebook card:
///
/// ```
///  #3  Day 18 · 24 Sep                     Sour −
///  ┌ D → Y      TIME      TEMP   ┐
///  │ 20.0→48.5  27.0s     94.0°C │
///  │ GRIND      PB        FLOW   │
///  └ 0.5@1100   3/5       Choked ┘
///  Juicy Peach · Honey
///  → Go finer (-0.7)
/// ```
struct ShotRowView: View {
    let shot: ShotLog
    var number: Int?
    var showsBeanName = false

    private struct Metric: Identifiable {
        let label: String
        let value: String
        var sub: String?
        var tint: Color?
        var id: String { label }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headline
            metricsWell
            if let equipment = shot.equipment {
                Label(
                    equipment.fullLine(for: shot.brewMethod, dripper: shot.dripper),
                    systemImage: shot.brewMethod == .pourOver ? "mug" : "espressomachine"
                )
                .font(.mono(.caption2))
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            notesLine
            if let tweak = shot.actionableNextTweak, !tweak.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                    Text(tweak)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.tint)
            }
        }
        .padding(16)
        .paperCard()
        .accessibilityElement(children: .combine)
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number.map { "#\($0)" } ?? "•")
                .font(.mono(.title3, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Day \(shot.restDaysAtBrew)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("· \(shot.timestamp, format: .dateTime.day().month(.abbreviated))")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                    if shot.brewMethod == .pourOver {
                        BrewMethodBadge(method: .pourOver, dripper: shot.dripper)
                    }
                }
                if showsBeanName, let bean = shot.bean {
                    Text(bean.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            BalanceChip(balance: shot.tasteBalance)
                .fixedSize()
        }
    }

    private var metrics: [Metric] {
        let grindValue = "\(max(0, shot.grindSetting).fixed())\(shot.grinderRPM.map { "@\($0)" } ?? "")"
        let grindSub: String? = shot.grinderZeroOffset == 0
            ? nil
            : "0pt \(shot.grinderZeroOffset > 0 ? "+" : "")\(shot.grinderZeroOffset)"
        let flowTint: Color? = shot.flowQuality.isIssue ? shot.flowQuality.tint : nil

        switch shot.brewMethod {
        case .espresso:
            return [
                Metric(label: "D → Y", value: "\(shot.dose.fixed())→\(shot.yield.fixed())", sub: ShotFormatter.ratio(shot.ratio)),
                Metric(label: "Time", value: "\(shot.totalTime.fixed())s", sub: "FP \(shot.fullPressureTime.fixed())s"),
                Metric(label: "Temp", value: ShotFormatter.temperature(shot.brewTemperature)),
                Metric(label: "Grind", value: grindValue, sub: grindSub),
                Metric(label: "PB", value: "\(shot.preBrewPulse.trimmed)/\(shot.preBrewPause.trimmed)", sub: shot.feedMethod.shortLabel),
                Metric(label: "Flow", value: shot.flowQuality.label(for: .espresso), tint: flowTint),
            ]
        case .pourOver:
            return [
                Metric(label: "Water", value: "\(shot.dose.fixed()):\(shot.yield.fixed(0))", sub: ShotFormatter.ratio(shot.ratio, method: .pourOver)),
                Metric(label: "Drawdown", value: ShotFormatter.drawdown(shot.totalTime), sub: "Bloom \(shot.bloomWater.fixed(0))g/\(shot.preBrewPause.fixed(0))s"),
                Metric(label: "Temp", value: ShotFormatter.temperature(shot.brewTemperature)),
                Metric(label: "Grind", value: grindValue, sub: grindSub),
                Metric(label: "Pours", value: "\(shot.pourCount)p", sub: shot.agitation.shortLabel),
                Metric(label: "Bed", value: shot.flowQuality.label(for: .pourOver), tint: flowTint),
            ]
        }
    }

    private var metricsWell: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .topLeading), count: 3),
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkSecondary)
                    Text(metric.value)
                        .font(.mono(.subheadline, weight: .medium))
                        .foregroundStyle(metric.tint ?? Palette.ink)
                    if let sub = metric.sub {
                        Text(sub)
                            .font(.mono(.caption2))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .padding(12)
        .background(Palette.inset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var notesLine: some View {
        let notes = shot.flavorNotes.joined(separator: " · ")
        if !notes.isEmpty {
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Page header mirroring the paper log: bean, roast date, rest, basket/dripper, grinder.
struct NotebookHeader: View {
    let bean: CoffeeBean
    let equipment: EquipmentProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ESPRESSO & POUR OVER LOG")
                    .font(.caption2.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(Palette.inkSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(bean.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    if !bean.roaster.isEmpty {
                        Text("(\(bean.roaster))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    field("Roasted", value: bean.roastDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))
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
            .font(.footnote)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    private func field(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(Palette.inkSecondary)
            Text(value)
                .font(.mono(.footnote))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
