import Foundation

struct ExtractionInsight: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case hint
        case warning
        case positive
    }

    enum Rule: String, Sendable, Equatable {
        case feedSwitchToDump
        case feedSwitchToSlow
        case bitterDespiteFastFullPressure
        case channeling
        case gushingSour
        case gushingSweet
        case gushingHarsh
        case chokedSour
        case chokedSweet
        case chokedHarsh
        case smoothSour
        case smoothBitter
        case astringency
        case youngRoast
        case dialedIn

        var isFeedHint: Bool {
            self == .feedSwitchToDump || self == .feedSwitchToSlow
        }
    }

    let rule: Rule
    let kind: Kind
    let symbol: String
    let title: String
    let message: String

    var id: Rule { rule }
}

/// Rule-based dial-in assistant. Pure & stateless — safe to call from any isolation domain.
enum ExtractionInsightsEngine {
    /// Full-pressure phases shorter than this are considered "fast".
    static let fastFullPressureThreshold: Double = 18
    /// Rest days under which a light roast is likely still degassing heavily.
    static let youngRoastThreshold = 7

    /// - Parameters:
    ///   - shot: The shot being evaluated (draft or saved).
    ///   - baselineFeed: Feed method of the previous shot / pre-filled template, used to detect a switch.
    static func insights(for shot: ShotSnapshot, baselineFeed: FeedMethod?) -> [ExtractionInsight] {
        var results: [ExtractionInsight] = []
        let fullPressure = shot.fullPressureTime.fixed()
        let finerOne = max(0, shot.grindSetting - 0.1).fixed()
        let finerTwo = max(0, shot.grindSetting - 0.2).fixed()
        let coarserOne = (shot.grindSetting + 0.1).fixed()
        let coarserTwo = (shot.grindSetting + 0.2).fixed()
        let longerYield = (shot.yield + 2).fixed()
        let shorterYield = max(0, shot.yield - 2).fixed()

        // 1. Feed method switch.
        if let baselineFeed, baselineFeed != shot.feedMethod {
            switch shot.feedMethod {
            case .fastDump:
                results.append(ExtractionInsight(
                    rule: .feedSwitchToDump,
                    kind: .hint,
                    symbol: "hare",
                    title: "Fast dump → more fines",
                    message: "Dumping the whole dose produces more fines than slow feeding, so the same setting will run slower and heavier. Consider grinding ~0.1–0.3 coarser."
                ))
            case .slowFeed:
                results.append(ExtractionInsight(
                    rule: .feedSwitchToSlow,
                    kind: .hint,
                    symbol: "tortoise",
                    title: "Slow feed → fewer fines",
                    message: "Slow feeding reduces fines, so expect faster flow and more clarity. You may need to grind ~0.1–0.3 finer."
                ))
            }
        }

        // 2. Bitter + fast full-pressure phase + slow feed → not classic over-extraction.
        let triggeredFastBitterRule = shot.tasteBalance == .overExtractedBitter
            && shot.fullPressureTime < fastFullPressureThreshold
            && shot.feedMethod == .slowFeed

        if triggeredFastBitterRule {
            results.append(ExtractionInsight(
                rule: .bitterDespiteFastFullPressure,
                kind: .warning,
                symbol: "exclamationmark.triangle",
                title: "Bitter, yet only \(fullPressure)s at full pressure",
                message: "With slow-fed (low-fines) grounds and a short contact time, bitterness points to micro-channeling or too much yield. Check WDT depth, tamp level and puck-screen seating, or try a shorter yield (\(shorterYield)g)."
            ))
        }

        // 3. Flow Quality × Sensory Balance matrix (always gives actionable small advice).
        switch (shot.flowQuality, shot.tasteBalance) {
        case (.channelingSquirts, let balance):
            let balanceTail: String = switch balance {
            case .underExtractedSour: " Channeling bypassed much of the puck, leaving the cup sour — fix WDT & tamp level before going finer."
            case .overExtractedBitter, .astringentDryChalky: " High-velocity channels over-extracted narrow paths — fix WDT & puck prep before going coarser."
            case .balancedSweet, nil: " Fix puck prep before touching grind: thorough WDT, level tamp, seat the puck screen, and check basket headspace."
            }
            results.append(ExtractionInsight(
                rule: .channeling,
                kind: .warning,
                symbol: "sparkles",
                title: "Channeling observed",
                message: balanceTail.trimmingCharacters(in: .whitespaces)
            ))

        case (.fastGushing, .underExtractedSour), (.fastGushing, nil):
            results.append(ExtractionInsight(
                rule: .gushingSour,
                kind: .hint,
                symbol: "bolt",
                title: "Gushing & under-extracted",
                message: "Resistance is too low. Grind finer (→ \(finerTwo)) or increase dose by +0.5g to build puck pressure."
            ))

        case (.fastGushing, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .gushingSweet,
                kind: .positive,
                symbol: "bolt.heart",
                title: "Fast turbo flow, yet sweet",
                message: "High-clarity turbo territory. Keep as-is for juicy clarity, or nudge finer (→ \(finerOne)) if you want more syrupy body."
            ))

        case (.fastGushing, .overExtractedBitter), (.fastGushing, .astringentDryChalky):
            if !triggeredFastBitterRule {
                results.append(ExtractionInsight(
                    rule: .gushingHarsh,
                    kind: .warning,
                    symbol: "bolt.trianglebadge.exclamationmark",
                    title: "Fast gushing, yet harsh/bitter",
                    message: "Rapid flow with bitterness indicates macro-bypass over-extracting narrow channels. Improve WDT & tamp level, or shorten yield to \(shorterYield)g."
                ))
            }

        case (.chokedDrip, .overExtractedBitter), (.chokedDrip, .astringentDryChalky), (.chokedDrip, nil):
            results.append(ExtractionInsight(
                rule: .chokedHarsh,
                kind: .hint,
                symbol: "drop",
                title: "Choked & over-extracted",
                message: "Too much puck resistance. Grind coarser (→ \(coarserTwo)) or lower RPM / shorten yield to \(shorterYield)g."
            ))

        case (.chokedDrip, .underExtractedSour):
            results.append(ExtractionInsight(
                rule: .chokedSour,
                kind: .warning,
                symbol: "drop.triangle",
                title: "Choked flow, yet sour",
                message: "The puck stalled and fractured, under-extracting most of the bed. Grind coarser (→ \(coarserTwo)) so water flows evenly through the puck."
            ))

        case (.chokedDrip, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .chokedSweet,
                kind: .hint,
                symbol: "drop.fill",
                title: "Slow drip, but balanced",
                message: "Long contact time worked well here, though you're close to stalling. Nudge ~0.1 coarser (→ \(coarserOne)) for safer shot-to-shot consistency."
            ))

        case (.smoothCone, .underExtractedSour):
            results.append(ExtractionInsight(
                rule: .smoothSour,
                kind: .hint,
                symbol: "arrow.down.right.circle",
                title: "Smooth cone, but sour (−)",
                message: "Puck prep looks clean — you just need higher extraction. Grind slightly finer (→ \(finerOne)), extend yield to \(longerYield)g, or raise temp +0.5°C."
            ))

        case (.smoothCone, .overExtractedBitter):
            if !triggeredFastBitterRule {
                results.append(ExtractionInsight(
                    rule: .smoothBitter,
                    kind: .hint,
                    symbol: "arrow.up.right.circle",
                    title: "Smooth cone, but bitter (+)",
                    message: "Even flow pushed past the sweet spot. Shorten yield to \(shorterYield)g, grind slightly coarser (→ \(coarserOne)), or drop temp −0.5°C."
                ))
            }

        case (.smoothCone, .astringentDryChalky):
            results.append(ExtractionInsight(
                rule: .astringency,
                kind: .hint,
                symbol: "aqi.medium",
                title: "Smooth flow, but dry / astringent",
                message: "Astringency with a good-looking cone usually comes from micro-fines or a long tail. Try slow-feeding, lowering grinder RPM by 100, or cutting yield at \(shorterYield)g."
            ))

        case (.smoothCone, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .dialedIn,
                kind: .positive,
                symbol: "star.fill",
                title: "Dialed in ★",
                message: "Sweet, balanced and a smooth cone. Lock this recipe (\(shot.dose.fixed())g → \(shot.yield.fixed())g @ G \(shot.grindSetting.fixed()))."
            ))

        case (.smoothCone, nil):
            break
        }

        // 4. Young roast.
        if shot.restDays < youngRoastThreshold {
            results.append(ExtractionInsight(
                rule: .youngRoast,
                kind: .hint,
                symbol: "leaf",
                title: "Day \(shot.restDays) — still degassing",
                message: "Light roasts often peak after 10–21+ days. CO₂ can cause erratic flow; avoid big grind jumps until it settles."
            ))
        }

        return results
    }

    /// One-tap suggestions for the "Next tweak" field.
    static func suggestedTweaks(for shot: ShotSnapshot) -> [String] {
        let finer = max(0, shot.grindSetting - 0.1).fixed()
        let coarser = (shot.grindSetting + 0.1).fixed()
        var tweaks: [String] = []

        switch shot.flowQuality {
        case .fastGushing: tweaks.append("Go finer → \(max(0, shot.grindSetting - 0.2).fixed())")
        case .chokedDrip: tweaks.append("Go coarser → \((shot.grindSetting + 0.2).fixed())")
        case .channelingSquirts: tweaks.append("Better WDT / puck prep")
        case .smoothCone: break
        }

        switch shot.tasteBalance {
        case .underExtractedSour:
            tweaks += ["Go finer → \(finer)", "Temp +0.5°C", "Yield +2g"]
        case .overExtractedBitter:
            tweaks += ["Go coarser → \(coarser)", "Temp −0.5°C", "Yield −2g"]
        case .astringentDryChalky:
            tweaks += ["Better WDT / puck prep", "Go coarser → \(coarser)", "Temp −0.5°C"]
        case .balancedSweet:
            tweaks += ["Lock recipe", "Freeze vials Day \(shot.restDays + 2)"]
        case nil:
            break
        }

        var seen = Set<String>()
        return tweaks.filter { seen.insert($0).inserted }
    }
}
