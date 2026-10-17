import Foundation

/// Whether a log entry is an espresso pull or a filter pour over brew.
enum BrewMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case espresso
    case pourOver

    var id: String { rawValue }

    var label: String {
        switch self {
        case .espresso: "Espresso"
        case .pourOver: "Pour Over"
        }
    }

    var shortLabel: String {
        switch self {
        case .espresso: "ESP"
        case .pourOver: "PO"
        }
    }

    var symbol: String {
        switch self {
        case .espresso: "cup.and.saucer.fill"
        case .pourOver: "mug.fill"
        }
    }
}

/// Agitation technique applied during a pour over brew.
enum PourAgitation: String, Codable, CaseIterable, Identifiable, Sendable {
    case gentle
    case moderateSwirl
    case heavyWetWDT

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: "Gentle"
        case .moderateSwirl: "Swirl / Spin"
        case .heavyWetWDT: "Wet WDT"
        }
    }

    var shortLabel: String {
        switch self {
        case .gentle: "Gentle"
        case .moderateSwirl: "Swirl"
        case .heavyWetWDT: "Wet WDT"
        }
    }

    var detail: String {
        switch self {
        case .gentle: "Low-agitation center/spiral pour · fast drawdown & clarity"
        case .moderateSwirl: "Rao spin on bloom & final pour · flat bed & even extraction"
        case .heavyWetWDT: "Bloom stir / high agitation · maximizes extraction & body"
        }
    }

    var symbol: String {
        switch self {
        case .gentle: "wind"
        case .moderateSwirl: "tornado"
        case .heavyWetWDT: "wand.and.rays"
        }
    }
}

/// How beans are fed into the grinder. Affects fines production on flat-burr single-dosers.
enum FeedMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case slowFeed
    case fastDump

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slowFeed: "Slow Feed"
        case .fastDump: "Fast Dump"
        }
    }

    /// Notebook-style abbreviation used in compact rows.
    var shortLabel: String {
        switch self {
        case .slowFeed: "Slow"
        case .fastDump: "Dump"
        }
    }

    var detail: String {
        switch self {
        case .slowFeed: "Beans fed gradually · fewer fines"
        case .fastDump: "Full dose dumped at once · more fines"
        }
    }

    var symbol: String {
        switch self {
        case .slowFeed: "tortoise.fill"
        case .fastDump: "hare.fill"
        }
    }
}

/// Visual read of the stream (espresso) or drawdown & coffee bed (pour over).
enum FlowQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case smoothCone
    case fastGushing
    case chokedDrip
    case channelingSquirts

    var id: String { rawValue }

    var label: String {
        label(for: .espresso)
    }

    func label(for method: BrewMethod) -> String {
        switch (method, self) {
        case (.espresso, .smoothCone): "Smooth"
        case (.espresso, .fastGushing): "Gushing"
        case (.espresso, .chokedDrip): "Choked"
        case (.espresso, .channelingSquirts): "Channel"
        case (.pourOver, .smoothCone): "Flat Bed"
        case (.pourOver, .fastGushing): "Fast Draw"
        case (.pourOver, .chokedDrip): "Stalled"
        case (.pourOver, .channelingSquirts): "Crater/Wall"
        }
    }

    /// Badge shown in history rows. `nil` for a healthy flow / flat bed.
    var badge: String? {
        badge(for: .espresso)
    }

    func badge(for method: BrewMethod) -> String? {
        switch (method, self) {
        case (_, .smoothCone): nil
        case (.espresso, .fastGushing): "⚡ Gushing"
        case (.espresso, .chokedDrip): "💧 Choked"
        case (.espresso, .channelingSquirts): "CH Channeling"
        case (.pourOver, .fastGushing): "⚡ Fast Bypass"
        case (.pourOver, .chokedDrip): "💧 Stalled Bed"
        case (.pourOver, .channelingSquirts): "CH Crater/Wall"
        }
    }

    var symbol: String {
        symbol(for: .espresso)
    }

    func symbol(for method: BrewMethod) -> String {
        switch (method, self) {
        case (_, .smoothCone): "checkmark.seal.fill"
        case (_, .fastGushing): "bolt.fill"
        case (.espresso, .chokedDrip): "drop.fill"
        case (.pourOver, .chokedDrip): "hourglass"
        case (.espresso, .channelingSquirts): "sparkles"
        case (.pourOver, .channelingSquirts): "exclamationmark.triangle.fill"
        }
    }

    var isIssue: Bool { self != .smoothCone }
}

/// Sensory balance of the cup.
enum TasteBalance: String, Codable, CaseIterable, Identifiable, Sendable {
    case underExtractedSour
    case balancedSweet
    case overExtractedBitter
    case astringentDryChalky

    var id: String { rawValue }

    /// Notebook glyph: `−` sour, `★` balanced, `+` bitter, `Ast` astringent.
    var glyph: String {
        switch self {
        case .underExtractedSour: "−"
        case .balancedSweet: "★"
        case .overExtractedBitter: "+"
        case .astringentDryChalky: "Ast"
        }
    }

    var segmentLabel: String {
        switch self {
        case .underExtractedSour: "Sour"
        case .balancedSweet: "Sweet"
        case .overExtractedBitter: "Bitter"
        case .astringentDryChalky: "Astringent"
        }
    }

    var label: String {
        switch self {
        case .underExtractedSour: "Sour (−)"
        case .balancedSweet: "Sweet / Balanced (★)"
        case .overExtractedBitter: "Bitter (+)"
        case .astringentDryChalky: "Astringent (Ast)"
        }
    }
}
