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
        case pourOverAgitationStall
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

/// Rule-based dial-in assistant for both Espresso and Pour Over. Pure & stateless — safe to call from any isolation domain.
enum ExtractionInsightsEngine {
    /// Full-pressure phases shorter than this are considered "fast" in espresso.
    static let fastFullPressureThreshold: Double = 18
    /// Rest days under which a light roast is likely still degassing heavily.
    static let youngRoastThreshold = 7

    /// - Parameters:
    ///   - shot: The shot/brew being evaluated (draft or saved).
    ///   - baselineFeed: Feed method of the previous brew / pre-filled template, used to detect a switch.
    static func insights(for shot: ShotSnapshot, baselineFeed: FeedMethod?) -> [ExtractionInsight] {
        switch shot.brewMethod {
        case .espresso:
            return espressoInsights(for: shot, baselineFeed: baselineFeed)
        case .pourOver:
            return pourOverInsights(for: shot, baselineFeed: baselineFeed)
        }
    }

    // MARK: - Espresso Rules

    private static func espressoInsights(for shot: ShotSnapshot, baselineFeed: FeedMethod?) -> [ExtractionInsight] {
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
            case .underExtractedSour: "Channeling bypassed much of the puck, leaving the cup sour — fix WDT & tamp level before going finer."
            case .overExtractedBitter, .astringentDryChalky: "High-velocity channels over-extracted narrow paths — fix WDT & puck prep before going coarser."
            case .balancedSweet, nil: "Fix puck prep before touching grind: thorough WDT, level tamp, seat the puck screen, and check basket headspace."
            }
            results.append(ExtractionInsight(
                rule: .channeling,
                kind: .warning,
                symbol: "sparkles",
                title: "Channeling observed",
                message: balanceTail
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

    // MARK: - Pour Over Rules

    private static func pourOverInsights(for shot: ShotSnapshot, baselineFeed: FeedMethod?) -> [ExtractionInsight] {
        var results: [ExtractionInsight] = []
        let finerStep = max(0, shot.grindSetting - 0.3).fixed()
        let finerBig = max(0, shot.grindSetting - 0.5).fixed()
        let coarserStep = (shot.grindSetting + 0.3).fixed()
        let coarserBig = (shot.grindSetting + 0.5).fixed()
        let moreWater = (shot.yield + 15).fixed(0)
        let lessWater = max(100, shot.yield - 15).fixed(0)
        let drawdownText = ShotFormatter.drawdown(shot.totalTime)

        // 1. Feed method switch on filter grind.
        if let baselineFeed, baselineFeed != shot.feedMethod {
            switch shot.feedMethod {
            case .fastDump:
                results.append(ExtractionInsight(
                    rule: .feedSwitchToDump,
                    kind: .hint,
                    symbol: "hare",
                    title: "Fast dump → more filter fines",
                    message: "Dumping the whole dose generates more fines that can clog filter paper pores. Consider grinding ~0.3–0.5 coarser."
                ))
            case .slowFeed:
                results.append(ExtractionInsight(
                    rule: .feedSwitchToSlow,
                    kind: .hint,
                    symbol: "tortoise",
                    title: "Slow feed → cleaner drawdown",
                    message: "Slow feeding at low RPM (800–900) dramatically cuts fines for faster, sweeter filter drawdowns. You can push ~0.3–0.5 finer."
                ))
            }
        }

        // 2. Stalled bed + high agitation.
        if shot.flowQuality == .chokedDrip && shot.agitation == .heavyWetWDT {
            results.append(ExtractionInsight(
                rule: .pourOverAgitationStall,
                kind: .warning,
                symbol: "tornado",
                title: "Wet WDT clogged the filter paper",
                message: "Heavy bloom agitation suspended fines that settled into the paper filter, stalling drawdown (\(drawdownText)). Switch to Gentle or a single Rao Swirl and grind coarser (→ \(coarserBig))."
            ))
        }

        // 3. Pour Over Drawdown & Bed Quality × Sensory Balance matrix.
        switch (shot.flowQuality, shot.tasteBalance) {
        case (.channelingSquirts, let balance):
            let msg: String = switch balance {
            case .underExtractedSour:
                "Water bypassed through a center crater or down the paper walls, leaving the cup sour and thin. Pour in gentle circles to 60% radius and give a soft Rao swirl after your final pour."
            case .overExtractedBitter, .astringentDryChalky:
                "Uneven bed channeled heavily through the center while leaving high mud walls. Level the slurry with a gentle swirl after bloom and final pour before adjusting grind."
            case .balancedSweet, nil:
                "Crater or high mud walls left in the filter bed. Keep your kettle stream low (~4cm above slurry) and finish with a gentle 2-second spin for an even, flat bed."
            }
            results.append(ExtractionInsight(
                rule: .channeling,
                kind: .warning,
                symbol: "sparkles",
                title: "Uneven bed / cratering",
                message: msg
            ))

        case (.fastGushing, .underExtractedSour), (.fastGushing, nil):
            results.append(ExtractionInsight(
                rule: .gushingSour,
                kind: .hint,
                symbol: "bolt",
                title: "Fast drawdown (\(drawdownText)) & sour",
                message: "Water ran through too quickly with low contact time. Grind finer (→ \(finerBig)), add +1 pour pulse (to \(shot.pourCount + 1) pours), or raise water temp +1–2°C."
            ))

        case (.fastGushing, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .gushingSweet,
                kind: .positive,
                symbol: "bolt.heart",
                title: "Fast drawdown (\(drawdownText)), yet sweet ★",
                message: "High-clarity filter profile! Keep as-is for tea-like aromatics, or nudge finer (→ \(finerStep)) if you want deeper body."
            ))

        case (.fastGushing, .overExtractedBitter), (.fastGushing, .astringentDryChalky):
            results.append(ExtractionInsight(
                rule: .gushingHarsh,
                kind: .warning,
                symbol: "bolt.trianglebadge.exclamationmark",
                title: "Fast drawdown, yet harsh/dry",
                message: "Fast drawdown with astringency points to aggressive kettle height jetting through the bed. Pour lower and gentler, or drop water temp −2°C."
            ))

        case (.chokedDrip, .overExtractedBitter), (.chokedDrip, .astringentDryChalky), (.chokedDrip, nil):
            results.append(ExtractionInsight(
                rule: .chokedHarsh,
                kind: .hint,
                symbol: "drop",
                title: "Stalled drawdown (\(drawdownText)) & astringent",
                message: "Fines migrated and clogged the filter paper. Grind coarser (→ \(coarserBig)), reduce swirling on late pours, or lower grinder RPM to 800."
            ))

        case (.chokedDrip, .underExtractedSour):
            results.append(ExtractionInsight(
                rule: .chokedSour,
                kind: .warning,
                symbol: "drop.triangle",
                title: "Stalled filter bed, yet sour",
                message: "The bottom of the filter clogged while water bypassed through the upper paper walls. Grind coarser (→ \(coarserBig)) so water flows through the coffee bed instead of around it."
            ))

        case (.chokedDrip, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .chokedSweet,
                kind: .hint,
                symbol: "drop.fill",
                title: "Slow drawdown (\(drawdownText)), but sweet",
                message: "Extended contact time gave nice sweetness, though the paper nearly stalled. Nudge ~0.3 coarser (→ \(coarserStep)) for a cleaner finish."
            ))

        case (.smoothCone, .underExtractedSour):
            results.append(ExtractionInsight(
                rule: .smoothSour,
                kind: .hint,
                symbol: "arrow.down.right.circle",
                title: "Flat bed, but sour / weak (−)",
                message: "Bed prep is spot on — you just need higher extraction. Grind finer (→ \(finerStep)), raise water temp +1–2°C, or extend water to \(moreWater)g."
            ))

        case (.smoothCone, .overExtractedBitter):
            results.append(ExtractionInsight(
                rule: .smoothBitter,
                kind: .hint,
                symbol: "arrow.up.right.circle",
                title: "Flat bed, but bitter / heavy (+)",
                message: "Even extraction pushed slightly too far. Grind coarser (→ \(coarserStep)), lower water temp −1–2°C, or shorten water to \(lessWater)g."
            ))

        case (.smoothCone, .astringentDryChalky):
            results.append(ExtractionInsight(
                rule: .astringency,
                kind: .hint,
                symbol: "aqi.medium",
                title: "Flat bed, but dry / astringent",
                message: "Dryness with a flat bed comes from fines or late agitation. Switch to Gentle agitation, use 1 fewer pour pulse, or grind coarser (→ \(coarserStep))."
            ))

        case (.smoothCone, .balancedSweet):
            results.append(ExtractionInsight(
                rule: .dialedIn,
                kind: .positive,
                symbol: "star.fill",
                title: "Filter recipe dialed in ★",
                message: "Flat bed, clean \(drawdownText) drawdown, and sweet balance. Lock this recipe (\(shot.dose.fixed())g : \(shot.yield.fixed(0))g @ G \(shot.grindSetting.fixed()))."
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
                title: "Day \(shot.restDays) — extend bloom to 60s",
                message: "Fresh filter roasts release heavy CO₂ during the bloom. Try a 3× bloom with a 45–60s wait and gentle swirl so gas escapes before main pours."
            ))
        }

        return results
    }

    // MARK: - Suggested Tweaks

    /// One-tap suggestions for the "Next tweak" field, adapted for Espresso or Pour Over.
    static func suggestedTweaks(for shot: ShotSnapshot) -> [String] {
        switch shot.brewMethod {
        case .espresso:
            return espressoSuggestedTweaks(for: shot)
        case .pourOver:
            return pourOverSuggestedTweaks(for: shot)
        }
    }

    private static func espressoSuggestedTweaks(for shot: ShotSnapshot) -> [String] {
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

    private static func pourOverSuggestedTweaks(for shot: ShotSnapshot) -> [String] {
        let finer = max(0, shot.grindSetting - 0.3).fixed()
        let coarser = (shot.grindSetting + 0.3).fixed()
        var tweaks: [String] = []

        switch shot.flowQuality {
        case .fastGushing:
            tweaks.append("Go finer → \(max(0, shot.grindSetting - 0.5).fixed())")
            tweaks.append("Add +1 pour (\(shot.pourCount + 1) pours)")
        case .chokedDrip:
            tweaks.append("Go coarser → \((shot.grindSetting + 0.5).fixed())")
            tweaks.append("Reduce swirl / RPM 800")
        case .channelingSquirts:
            tweaks.append("Gentle center pour + final spin")
        case .smoothCone:
            break
        }

        switch shot.tasteBalance {
        case .underExtractedSour:
            tweaks += ["Go finer → \(finer)", "Temp +1.5°C", "Extend bloom 60s"]
        case .overExtractedBitter:
            tweaks += ["Go coarser → \(coarser)", "Temp −1.5°C", "1 fewer pour"]
        case .astringentDryChalky:
            tweaks += ["Gentle pour (no final swirl)", "Go coarser → \(coarser)", "Slow feed 800 RPM"]
        case .balancedSweet:
            tweaks += ["Lock filter recipe", "Freeze dose vials"]
        case nil:
            break
        }

        var seen = Set<String>()
        return tweaks.filter { seen.insert($0).inserted }
    }
}
