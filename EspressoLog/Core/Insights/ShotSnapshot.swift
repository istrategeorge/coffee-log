import Foundation

/// Immutable, `Sendable` value copy of a shot (saved or draft).
/// Lets pure logic (insights, formatting, tests) run without touching SwiftData.
struct ShotSnapshot: Sendable, Equatable {
    var brewMethod: BrewMethod = .espresso
    var dose: Double = 18
    var yield: Double = 36
    var totalTime: Double = 28
    var grindSetting: Double = 0
    var grinderZeroOffset: Int = 0
    var grinderRPM: Int? = nil
    var feedMethod: FeedMethod = .slowFeed
    var brewTemperature: Double = 93
    var preBrewPulse: Double = 0
    var preBrewPause: Double = 0
    /// Pour Over brewer (e.g. "Hario V60 01", "Orea V4").
    var dripper: String? = nil
    /// Grams of bloom water for Pour Over (e.g. 45g for 15g dose).
    var bloomWater: Double = 0
    /// Total pour pulses including bloom (e.g. 3 = Bloom + 2 pours).
    var pourCount: Int = 3
    /// Agitation style during pour over.
    var agitation: PourAgitation = .moderateSwirl
    var flowQuality: FlowQuality = .smoothCone
    var tasteBalance: TasteBalance? = nil
    var restDays: Int = 0

    var ratio: Double {
        dose > 0 ? self.yield / dose : 0
    }

    var fullPressureTime: Double {
        max(0, totalTime - (preBrewPulse + preBrewPause))
    }

    var bloomRatio: Double {
        dose > 0 ? bloomWater / dose : 0
    }
}
