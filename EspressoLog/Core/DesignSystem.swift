import SwiftUI

// MARK: - Semantic tints

extension TasteBalance {
    var tint: Color {
        switch self {
        case .underExtractedSour: .orange
        case .balancedSweet: .green
        case .overExtractedBitter: .brown
        case .astringentDryChalky: .indigo
        }
    }
}

extension FlowQuality {
    var tint: Color {
        switch self {
        case .smoothCone: .green
        case .fastGushing: .orange
        case .chokedDrip: .blue
        case .channelingSquirts: .red
        }
    }
}

extension ExtractionInsight.Kind {
    var tint: Color {
        switch self {
        case .hint: .blue
        case .warning: .orange
        case .positive: .green
        }
    }
}

// MARK: - Surfaces

extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

struct SectionLabel: View {
    private let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Badges

/// Live `Rest: Day XX` badge. Pulses while resting at room temperature; shows a snowflake when frozen.
struct RestBadge: View {
    let days: Int
    let isFrozen: Bool
    var compact = false

    private var tint: Color { isFrozen ? .cyan : .green }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isFrozen ? "snowflake" : "circle.fill")
                .font(.system(size: isFrozen ? 12 : 7, weight: .bold))
                .symbolEffect(.pulse, options: .repeating, isActive: !isFrozen)
            Text(compact ? "Day \(days)" : "Rest: Day \(days)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest day \(days)\(isFrozen ? ", paused in freezer" : "")")
    }
}

/// `⚡ Gushing` · `💧 Choked` · `CH Channeling`. Renders nothing for a smooth cone.
struct FlowBadge: View {
    let flow: FlowQuality

    var body: some View {
        if let badge = flow.badge {
            Text(badge)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(flow.tint)
                .background(flow.tint.opacity(0.15), in: Capsule())
        }
    }
}

/// Notebook rating glyph: `−` / `★` / `+` / `Ast`.
struct BalanceGlyph: View {
    let balance: TasteBalance

    var body: some View {
        Text(balance.glyph)
            .font(.caption.weight(.heavy))
            .frame(minWidth: 22)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(balance.tint, in: Capsule())
            .accessibilityLabel(balance.label)
    }
}

struct InsightCallout: View {
    let insight: ExtractionInsight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(insight.kind.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(insight.kind.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Chips

struct TagChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? tint : Color.primary)
                .background(Capsule().fill(isSelected ? tint.opacity(0.18) : Color(.tertiarySystemFill)))
                .overlay(Capsule().strokeBorder(isSelected ? tint : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapping layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
