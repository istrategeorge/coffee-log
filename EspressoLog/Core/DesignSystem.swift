import SwiftUI

// MARK: - Palette ("ink & paper")

/// Ink-and-paper palette: warm paper ground, near-black ink, and ink-blue for anything
/// you wrote yourself (tweaks, pull numbers) — like the blue pen in the paper log.
/// Every token adapts to dark mode.
enum Palette {
    // Surfaces
    static let paper = Color(light: 0xF4F0E8, dark: 0x15130F)
    static let card = Color(light: 0xFFFCF7, dark: 0x211E1A)
    /// Wells and secondary buttons inside a card.
    static let inset = Color(light: 0xF4F0E8, dark: 0x2A2621)
    /// Round toolbar-style icon buttons.
    static let control = Color(light: 0xE9E3D8, dark: 0x2E2A24)
    static let rule = Color(light: 0xE4DDD1, dark: 0x36312A)
    static let track = Color(light: 0xECE6DB, dark: 0x332E28)

    // Ink
    static let ink = Color(light: 0x1C1A17, dark: 0xF2EDE4)
    static let inkSecondary = Color(light: 0x6A6359, dark: 0xA9A196)
    static let accent = Color(light: 0x2443A6, dark: 0x8FA8F2)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0F1A3D)

    // Semantic
    static let sour = Color(light: 0x8A450C, dark: 0xF0A766)
    static let sweet = Color(light: 0x2B6338, dark: 0x82C793)
    static let bitter = Color(light: 0x5E3A22, dark: 0xD4A27F)
    static let astringent = Color(light: 0x4A3D8C, dark: 0xB2A6F0)
    static let channel = Color(light: 0xB3261E, dark: 0xF2867D)
    static let frost = Color(light: 0x1F6E86, dark: 0x7FCBE0)
    static let pourOver = Color(light: 0x1F6E6A, dark: 0x7CCFC6)
    /// "Would buy again" heart.
    static let favorite = Color(light: 0xB3261E, dark: 0xF2867D)
}

extension BrewMethod {
    var tint: Color {
        switch self {
        case .espresso: Palette.accent
        case .pourOver: Palette.pourOver
        }
    }
}

extension Color {
    /// Light/dark pair from `0xRRGGBB` literals.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Monospaced figures for every measured value (dose, yield, grind, temp), so numbers
    /// line up like ruled notebook columns. Scales with Dynamic Type.
    static func mono(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
}

// MARK: - Semantic tints

extension TasteBalance {
    var tint: Color {
        switch self {
        case .underExtractedSour: Palette.sour
        case .balancedSweet: Palette.sweet
        case .overExtractedBitter: Palette.bitter
        case .astringentDryChalky: Palette.astringent
        }
    }
}

extension FlowQuality {
    var tint: Color {
        switch self {
        case .smoothCone: Palette.sweet
        case .fastGushing: Palette.sour
        case .chokedDrip: Palette.accent
        case .channelingSquirts: Palette.channel
        }
    }
}

extension ExtractionInsight.Kind {
    var tint: Color {
        switch self {
        case .hint: Palette.accent
        case .warning: Palette.sour
        case .positive: Palette.sweet
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

    /// Ink & paper card: warm card fill with a hairline rule.
    func paperCard(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Palette.card, in: shape)
            .overlay(shape.strokeBorder(Palette.rule, lineWidth: 1))
    }

    /// Full-bleed paper screen background (a `ShapeStyle` background ignores safe areas by default).
    func paperBackground() -> some View {
        background(Palette.paper)
    }

    /// Selectable option tile (flow, agitation, pour count): a quiet card when off,
    /// a tinted fill with a bold border when on.
    func optionTile(isSelected: Bool, tint: Color, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return foregroundStyle(isSelected ? tint : Palette.ink)
            .background(isSelected ? tint.opacity(0.14) : Palette.card, in: shape)
            .overlay(shape.strokeBorder(isSelected ? tint : Palette.rule, lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
    }
}

struct SectionLabel: View {
    private let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.0)
            .foregroundStyle(Palette.inkSecondary)
    }
}

/// Buttons on paper: `.prominent` is the ink-blue call to action, `.card` a raised tile,
/// `.inset` a quiet secondary action inside a card.
struct PaperButtonStyle: ButtonStyle {
    enum Kind { case prominent, card, inset }

    var kind: Kind = .inset
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return configuration.label
            .foregroundStyle(kind == .prominent ? Palette.onAccent : Palette.ink)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(kind == .prominent ? Color.clear : Palette.rule, lineWidth: 1))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var fill: Color {
        switch kind {
        case .prominent: Palette.accent
        case .card: Palette.card
        case .inset: Palette.inset
        }
    }
}

// MARK: - Meters

/// Rest-day ring: fills over `windowDays` and shows the day count in the middle.
struct RestRing: View {
    let days: Int
    var isFrozen = false
    var isFinished = false
    /// Days that fill the ring; most specialty roasts are past their peak within a month.
    var windowDays = 30

    private var tint: Color {
        if isFinished { return Palette.inkSecondary }
        return isFrozen ? Palette.frost : Palette.accent
    }

    private var progress: Double {
        min(1, max(0, Double(days) / Double(max(1, windowDays))))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(days)")
                    .font(.mono(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(days)))
                Text(isFinished ? "DONE" : "REST DAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(12)
        }
        .frame(width: 104, height: 104)
        .animation(.snappy, value: days)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest day \(days)\(isFinished ? ", bag finished" : (isFrozen ? ", paused in freezer" : ""))")
    }
}

/// Thin capsule meter, e.g. grams left in the bag.
struct MeterBar: View {
    let fraction: Double
    var tint: Color = Palette.ink

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 8)
        .animation(.snappy, value: fraction)
        .accessibilityHidden(true)
    }
}

// MARK: - Badges

/// Live `Rest: Day XX` badge. Pulses while resting at room temperature; shows a snowflake when frozen, or a seal when finished.
struct RestBadge: View {
    let days: Int
    let isFrozen: Bool
    var isFinished: Bool = false
    var compact = false

    private var tint: Color {
        if isFinished { return Palette.inkSecondary }
        return isFrozen ? Palette.frost : Palette.sweet
    }

    private var iconName: String {
        if isFinished { return "checkmark.seal.fill" }
        return isFrozen ? "snowflake" : "circle.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: (isFrozen || isFinished) ? 12 : 7, weight: .bold))
                .symbolEffect(.pulse, options: .repeating, isActive: !isFrozen && !isFinished)
            Text(compact ? (isFinished ? "Done · R\(days)" : "Day \(days)") : (isFinished ? "Done · Day \(days)" : "Rest: Day \(days)"))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest day \(days)\(isFinished ? ", bag finished" : (isFrozen ? ", paused in freezer" : ""))")
    }
}

/// `⚡ Gushing` · `💧 Choked` · `CH Channeling` (or Pour Over bed equivalents). Renders nothing for a smooth cone / flat bed.
struct FlowBadge: View {
    let flow: FlowQuality
    var method: BrewMethod = .espresso

    var body: some View {
        if let badge = flow.badge(for: method) {
            Text(badge)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(flow.tint)
                .background(flow.tint.opacity(0.15), in: Capsule())
        }
    }
}

/// Compact pill identifying Espresso (`ESP`) vs Pour Over (`PO` / dripper).
struct BrewMethodBadge: View {
    let method: BrewMethod
    var dripper: String?

    private var tint: Color {
        method == .pourOver ? Palette.pourOver : Palette.bitter
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: method.symbol)
                .font(.system(size: 9, weight: .bold))
            Text(method == .pourOver ? (dripper.map { Self.shortDripper($0) } ?? "PO") : "ESP")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
    }

    private static func shortDripper(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PO" }
        if trimmed.localizedStandardContains("V60") { return "V60" }
        if trimmed.localizedStandardContains("Origami") { return "Origami" }
        if trimmed.localizedStandardContains("Orea") { return "Orea" }
        if trimmed.localizedStandardContains("Kalita") { return "Kalita" }
        if trimmed.localizedStandardContains("Switch") { return "Switch" }
        if trimmed.localizedStandardContains("Chemex") { return "Chemex" }
        if trimmed.localizedStandardContains("AeroPress") { return "AeroPress" }
        return String(trimmed.prefix(8))
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
            .foregroundStyle(balance.tint)
            .background(balance.tint.opacity(0.16), in: Capsule())
            .accessibilityLabel(balance.label)
    }
}

/// Worded balance pill for roomier layouts: `Sour −` · `Sweet ★` · `Bitter +` · `Astringent Ast`.
struct BalanceChip: View {
    let balance: TasteBalance

    var body: some View {
        Text(balance == .astringentDryChalky ? balance.segmentLabel : "\(balance.segmentLabel) \(balance.glyph)")
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(balance.tint)
            .background(balance.tint.opacity(0.16), in: Capsule())
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
                    .foregroundStyle(Palette.ink)
                Text(insight.message)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(insight.kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? tint : Palette.ink)
                .background(Capsule().fill(isSelected ? tint.opacity(0.16) : Palette.card))
                .overlay(Capsule().strokeBorder(isSelected ? tint : Palette.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Bag score pill, e.g. `8/10`, with an optional favorite heart. Shows nothing when unrated and not a favorite.
struct RatingBadge: View {
    let rating: Int?
    var isFavorite = false

    var body: some View {
        HStack(spacing: 6) {
            if isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.favorite)
                    .accessibilityLabel("Favorite")
            }
            if let rating {
                (Text("\(rating)").font(.mono(.footnote, weight: .bold))
                    + Text("/10").font(.mono(.caption2)).foregroundStyle(Palette.inkSecondary))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.accent.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Rated \(rating) out of 10")
            }
        }
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
