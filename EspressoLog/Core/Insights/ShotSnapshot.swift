import Foundation

/// Immutable, `Sendable` value copy of a shot (saved or draft).
/// Lets pure logic (insights, formatting, tests) run without touching SwiftData.
struct ShotSnapshot: Sendable, Equatable {
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
    var flowQuality: FlowQuality = .smoothCone
    var tasteBalance: TasteBalance? = nil
    var restDays: Int = 0

    var ratio: Double {
        dose > 0 ? self.yield / dose : 0
    }

    var fullPressureTime: Double {
        max(0, totalTime - (preBrewPulse + preBrewPause))
    }
}
