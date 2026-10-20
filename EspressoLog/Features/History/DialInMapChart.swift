import SwiftUI
import SwiftData
import Charts

/// Dial-in map: every pull of one method plotted by time (x) and brew ratio (y),
/// colored and shaped by taste balance, over a shaded "sweet zone" that spans the sweet pulls.
struct DialInMapChart: View {
    struct Point: Identifiable {
        let id: PersistentIdentifier
        let time: Double
        let ratio: Double
        let balance: TasteBalance
        let number: Int?
    }

    let method: BrewMethod
    let points: [Point]

    /// Pull numbers are drawn next to each point only while they stay readable.
    private let maxLabeledPoints = 12

    init(method: BrewMethod, shots: [ShotLog], numbers: [PersistentIdentifier: Int]) {
        self.method = method
        self.points = shots
            .filter { $0.brewMethod == method }
            .map {
                Point(
                    id: $0.persistentModelID,
                    time: $0.totalTime,
                    ratio: $0.ratio,
                    balance: $0.tasteBalance,
                    number: numbers[$0.persistentModelID]
                )
            }
    }

    private struct Zone {
        let time: ClosedRange<Double>
        let ratio: ClosedRange<Double>
    }

    /// Bounding box of the sweet pulls, padded so a single sweet pull still reads as a zone.
    private var sweetZone: Zone? {
        let sweet = points.filter { $0.balance == .balancedSweet }
        guard let minTime = sweet.map(\.time).min(),
              let maxTime = sweet.map(\.time).max(),
              let minRatio = sweet.map(\.ratio).min(),
              let maxRatio = sweet.map(\.ratio).max() else { return nil }
        let timePad: Double = method == .pourOver ? 10 : 1
        let ratioPad: Double = method == .pourOver ? 0.3 : 0.05
        return Zone(
            time: (minTime - timePad)...(maxTime + timePad),
            ratio: (minRatio - ratioPad)...(maxRatio + ratioPad)
        )
    }

    private var balancesPresent: [TasteBalance] {
        TasteBalance.allCases.filter { balance in points.contains { $0.balance == balance } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dial-in map")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("Ratio vs \(method == .pourOver ? "drawdown" : "time") · \(method.label)")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }

            chart
                .frame(height: 190)

            legend
        }
        .padding(16)
        .paperCard()
    }

    private var chart: some View {
        Chart {
            if let zone = sweetZone {
                RectangleMark(
                    xStart: .value("Time", zone.time.lowerBound),
                    xEnd: .value("Time", zone.time.upperBound),
                    yStart: .value("Ratio", zone.ratio.lowerBound),
                    yEnd: .value("Ratio", zone.ratio.upperBound)
                )
                .foregroundStyle(Palette.sweet.opacity(0.14))
                .cornerRadius(8)
                .annotation(position: .overlay, alignment: .topLeading) {
                    Text("SWEET ZONE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.sweet)
                        .padding(4)
                }
                .accessibilityHidden(true)
            }

            ForEach(points) { point in
                PointMark(
                    x: .value("Time", point.time),
                    y: .value("Ratio", point.ratio)
                )
                .foregroundStyle(point.balance.tint)
                .symbol(point.balance.chartSymbol)
                .symbolSize(90)
                .annotation(position: .topTrailing, spacing: 2) {
                    if points.count <= maxLabeledPoints, let number = point.number {
                        Text("\(number)")
                            .font(.mono(.caption2, weight: .semibold))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .accessibilityLabel(point.number.map { "Pull \($0)" } ?? "Pull")
                .accessibilityValue("\(timeLabel(point.time)), ratio 1 to \(point.ratio.fixed(2)), \(point.balance.segmentLabel)")
            }
        }
        .chartXScale(domain: .automatic(includesZero: false))
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(timeLabel(seconds))
                            .font(.mono(.caption2))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let ratio = value.as(Double.self) {
                        Text("1:\(ratio.fixed(method == .pourOver ? 0 : 1))")
                            .font(.mono(.caption2))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(balancesPresent) { balance in
                HStack(spacing: 5) {
                    Image(systemName: balance.legendSymbolName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(balance.tint)
                    Text(balance.segmentLabel)
                        .font(.caption)
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func timeLabel(_ seconds: Double) -> String {
        method == .pourOver ? ShotFormatter.drawdown(seconds) : "\(Int(seconds.rounded()))s"
    }
}

private extension TasteBalance {
    /// Distinct shapes so balance never depends on color alone.
    var chartSymbol: BasicChartSymbolShape {
        switch self {
        case .underExtractedSour: .triangle
        case .balancedSweet: .circle
        case .overExtractedBitter: .square
        case .astringentDryChalky: .diamond
        }
    }

    var legendSymbolName: String {
        switch self {
        case .underExtractedSour: "triangle.fill"
        case .balancedSweet: "circle.fill"
        case .overExtractedBitter: "square.fill"
        case .astringentDryChalky: "diamond.fill"
        }
    }
}
