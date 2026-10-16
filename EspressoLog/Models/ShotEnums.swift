import Foundation

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

/// Visual read of the stream coming off the basket.
enum FlowQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case smoothCone
    case fastGushing
    case chokedDrip
    case channelingSquirts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smoothCone: "Smooth"
        case .fastGushing: "Gushing"
        case .chokedDrip: "Choked"
        case .channelingSquirts: "Channel"
        }
    }

    /// Badge shown in history rows. `nil` for a healthy flow.
    var badge: String? {
        switch self {
        case .smoothCone: nil
        case .fastGushing: "⚡ Gushing"
        case .chokedDrip: "💧 Choked"
        case .channelingSquirts: "CH Channeling"
        }
    }

    var symbol: String {
        switch self {
        case .smoothCone: "checkmark.seal.fill"
        case .fastGushing: "bolt.fill"
        case .chokedDrip: "drop.fill"
        case .channelingSquirts: "sparkles"
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
