import Foundation
import SwiftData

/// A single extraction.
///
/// Enums are persisted as raw `String` values (`…Raw`) and exposed through typed computed
/// properties. This keeps the store schema stable and `#Predicate`-friendly.
@Model
final class ShotLog {
    var timestamp: Date = Date.now
    /// Grams, 0.1 g precision.
    var dose: Double = 18.0
    /// Grams, 0.1 g precision.
    var yield: Double = 36.0
    /// Seconds, 0.1 s precision (includes pre-brew).
    var totalTime: Double = 28.0
    /// Positive dial reading (0.0 – 10.0, 0.1 step).
    var grindSetting: Double = 0.0
    /// Integer offset of the grinder's relocated 0-point (e.g. -2, -1, 0, +1, +2).
    var grinderZeroOffset: Int = 0
    var grinderRPM: Int?
    var feedMethodRaw: String = FeedMethod.slowFeed.rawValue
    /// Celsius.
    var brewTemperature: Double = 93.0
    /// Seconds pump ON.
    var preBrewPulse: Double = 0.0
    /// Seconds WAIT.
    var preBrewPause: Double = 0.0
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
        flowQuality: FlowQuality = .smoothCone,
        tasteBalance: TasteBalance,
        flavorNotes: [String] = [],
        actionableNextTweak: String? = nil,
        restDaysAtBrew: Int = 0
    ) {
        self.timestamp = timestamp
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
        self.flowQualityRaw = flowQuality.rawValue
        self.tasteBalanceRaw = tasteBalance.rawValue
        self.flavorNotes = flavorNotes
        self.actionableNextTweak = actionableNextTweak
        self.restDaysAtBrew = restDaysAtBrew
    }
}

// MARK: - Typed accessors & computed values

extension ShotLog {
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

    /// Brew ratio, `yield / dose` (e.g. 2.4 → "1:2.40").
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
            flowQuality: flowQuality,
            tasteBalance: tasteBalance,
            restDays: restDaysAtBrew
        )
    }

    /// `G 0.5 (0pt -1) @1200 | Slow | PB 3/5 | 93.5°C`
    var notebookLine: String {
        [
            ShotFormatter.grind(grindSetting, zeroOffset: grinderZeroOffset, rpm: grinderRPM),
            feedMethod.shortLabel,
            ShotFormatter.preBrew(pulse: preBrewPulse, pause: preBrewPause),
            ShotFormatter.temperature(brewTemperature),
        ].joined(separator: " | ")
    }
}
