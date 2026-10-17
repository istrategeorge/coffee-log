import Foundation
import SwiftData

/// A single extraction.
///
/// Enums are persisted as raw `String` values (`…Raw`) and exposed through typed computed
/// properties. This keeps the store schema stable and `#Predicate`-friendly.
@Model
final class ShotLog {
    var timestamp: Date = Date.now
    var brewMethodRaw: String = BrewMethod.espresso.rawValue
    /// Grams, 0.1 g precision.
    var dose: Double = 18.0
    /// Espresso yield (g) or Pour Over total water weight (g).
    var yield: Double = 36.0
    /// Seconds, 0.1 s precision (total extraction or drawdown time).
    var totalTime: Double = 28.0
    /// Positive dial reading (0.0 – 16.0, 0.1 step).
    var grindSetting: Double = 0.0
    /// Integer offset of the grinder's relocated 0-point (e.g. -2, -1, 0, +1, +2).
    var grinderZeroOffset: Int = 0
    var grinderRPM: Int?
    var feedMethodRaw: String = FeedMethod.slowFeed.rawValue
    /// Celsius.
    var brewTemperature: Double = 93.0
    /// Seconds pump ON (Espresso).
    var preBrewPulse: Double = 0.0
    /// Seconds WAIT (Espresso pre-brew pause or Pour Over bloom duration).
    var preBrewPause: Double = 0.0
    /// Pour Over dripper used (e.g. "Hario V60 01", "Orea V4").
    var dripper: String?
    /// Pour Over bloom water weight in grams (e.g. 45.0g).
    var bloomWater: Double = 0.0
    /// Pour Over number of pours including bloom (e.g. 3).
    var pourCount: Int = 3
    /// Pour Over agitation method raw string.
    var agitationRaw: String = PourAgitation.moderateSwirl.rawValue
    var flowQualityRaw: String = FlowQuality.smoothCone.rawValue
    var tasteBalanceRaw: String = TasteBalance.balancedSweet.rawValue
    var flavorNotes: [String] = []
    var actionableNextTweak: String?
    /// Snapshot of the bean's rest day at brew time (the "R16" column in the notebook).
    /// Stored because freezer cycles make historic rest impossible to recompute reliably.
    var restDaysAtBrew: Int = 0

    var bean: CoffeeBean?
    var equipment: EquipmentProfile?

    init(
        timestamp: Date = .now,
        brewMethod: BrewMethod = .espresso,
        dose: Double,
        yield yieldGrams: Double,
        totalTime: Double,
        grindSetting: Double,
        grinderZeroOffset: Int = 0,
        grinderRPM: Int? = nil,
        feedMethod: FeedMethod = .slowFeed,
        brewTemperature: Double,
        preBrewPulse: Double = 0,
        preBrewPause: Double = 0,
        dripper: String? = nil,
        bloomWater: Double = 0,
        pourCount: Int = 3,
        agitation: PourAgitation = .moderateSwirl,
        flowQuality: FlowQuality = .smoothCone,
        tasteBalance: TasteBalance,
        flavorNotes: [String] = [],
        actionableNextTweak: String? = nil,
        restDaysAtBrew: Int = 0
    ) {
        self.timestamp = timestamp
        self.brewMethodRaw = brewMethod.rawValue
        self.dose = dose
        self.yield = yieldGrams
        self.totalTime = totalTime
        self.grindSetting = max(0, grindSetting)
        self.grinderZeroOffset = grinderZeroOffset
        self.grinderRPM = grinderRPM
        self.feedMethodRaw = feedMethod.rawValue
        self.brewTemperature = brewTemperature
        self.preBrewPulse = preBrewPulse
        self.preBrewPause = preBrewPause
        self.dripper = dripper
        self.bloomWater = bloomWater
        self.pourCount = max(1, pourCount)
        self.agitationRaw = agitation.rawValue
        self.flowQualityRaw = flowQuality.rawValue
        self.tasteBalanceRaw = tasteBalance.rawValue
        self.flavorNotes = flavorNotes
        self.actionableNextTweak = actionableNextTweak
        self.restDaysAtBrew = restDaysAtBrew
    }
}

// MARK: - Typed accessors & computed values

extension ShotLog {
    var brewMethod: BrewMethod {
        get { BrewMethod(rawValue: brewMethodRaw) ?? .espresso }
        set { brewMethodRaw = newValue.rawValue }
    }

    var agitation: PourAgitation {
        get { PourAgitation(rawValue: agitationRaw) ?? .moderateSwirl }
        set { agitationRaw = newValue.rawValue }
    }

    var feedMethod: FeedMethod {
        get { FeedMethod(rawValue: feedMethodRaw) ?? .slowFeed }
        set { feedMethodRaw = newValue.rawValue }
    }

    var flowQuality: FlowQuality {
        get { FlowQuality(rawValue: flowQualityRaw) ?? .smoothCone }
        set { flowQualityRaw = newValue.rawValue }
    }

    var tasteBalance: TasteBalance {
        get { TasteBalance(rawValue: tasteBalanceRaw) ?? .balancedSweet }
        set { tasteBalanceRaw = newValue.rawValue }
    }

    /// Brew ratio, `yield / dose` (e.g. 2.4 → "1:2.40" or 16.7 → "1:16.7").
    var ratio: Double {
        dose > 0 ? self.yield / dose : 0
    }

    /// Time spent at full pressure: `totalTime - (preBrewPulse + preBrewPause)`.
    var fullPressureTime: Double {
        max(0, totalTime - (preBrewPulse + preBrewPause))
    }

    /// Sendable value copy used by the insights engine and view models.
    var snapshot: ShotSnapshot {
        ShotSnapshot(
            brewMethod: brewMethod,
            dose: dose,
            yield: self.yield,
            totalTime: totalTime,
            grindSetting: max(0, grindSetting),
            grinderZeroOffset: grinderZeroOffset,
            grinderRPM: grinderRPM,
            feedMethod: feedMethod,
            brewTemperature: brewTemperature,
            preBrewPulse: preBrewPulse,
            preBrewPause: preBrewPause,
            dripper: dripper,
            bloomWater: bloomWater,
            pourCount: pourCount,
            agitation: agitation,
            flowQuality: flowQuality,
            tasteBalance: tasteBalance,
            restDays: restDaysAtBrew
        )
    }

    /// Espresso: `G 0.5 (0pt -1) @1200 | Slow | PB 3/5 | 93.5°C`
    /// Pour Over: `G 6.5 (0pt -1) @800 | 3 Pours · Swirl | Bloom 45g/45s | 93.0°C`
    var notebookLine: String {
        switch brewMethod {
        case .espresso:
            [
                ShotFormatter.grind(grindSetting, zeroOffset: grinderZeroOffset, rpm: grinderRPM),
                feedMethod.shortLabel,
                ShotFormatter.preBrew(pulse: preBrewPulse, pause: preBrewPause),
                ShotFormatter.temperature(brewTemperature),
            ].joined(separator: " | ")
        case .pourOver:
            [
                ShotFormatter.grind(grindSetting, zeroOffset: grinderZeroOffset, rpm: grinderRPM),
                ShotFormatter.pours(count: pourCount, agitation: agitation),
                ShotFormatter.bloom(water: bloomWater, pause: preBrewPause),
                ShotFormatter.temperature(brewTemperature),
            ].joined(separator: " | ")
        }
    }
}
