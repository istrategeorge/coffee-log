import Foundation
import SwiftData

/// A bag / batch of coffee being dialed in.
@Model
final class CoffeeBean {
    var name: String = ""
    var roaster: String = ""
    var variety: String = ""
    var process: String = ""
    var roastDate: Date = Date.now
    var isFrozen: Bool = false
    var freezeDate: Date?
    /// Whole days spent in the freezer across completed freeze → thaw cycles.
    /// Subtracted from elapsed days so rest only counts time at room temperature.
    var frozenDaysBanked: Int = 0
    /// Starting weight of this bag in grams (e.g. 250g).
    var bagWeightGrams: Double = 250.0
    /// Sequential bag number when re-buying the same coffee (Bag #1, Bag #2, etc.).
    var bagNumber: Int = 1
    /// The bean shown on the dashboard. Exactly one bean should be active at a time.
    var isActive: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ShotLog.bean)
    var shots: [ShotLog] = []

    init(
        name: String,
        roaster: String,
        variety: String,
        process: String,
        roastDate: Date,
        bagWeightGrams: Double = 250.0,
        bagNumber: Int = 1,
        isFrozen: Bool = false,
        freezeDate: Date? = nil,
        isActive: Bool = false
    ) {
        self.name = name
        self.roaster = roaster
        self.variety = variety
        self.process = process
        self.roastDate = roastDate
        self.bagWeightGrams = max(0, bagWeightGrams)
        self.bagNumber = max(1, bagNumber)
        self.isFrozen = isFrozen
        self.freezeDate = isFrozen ? (freezeDate ?? .now) : nil
        self.isActive = isActive
        self.createdAt = .now
    }
}

// MARK: - Rest tracking

extension CoffeeBean {
    /// Rest days as of right now (live badge value).
    var restDays: Int { restDays(on: .now) }

    /// Rest days on a given brew date. Calculation is paused while the bean is frozen
    /// and excludes any days banked from previous freezer cycles.
    func restDays(on date: Date = .now, calendar: Calendar = .current) -> Int {
        Self.restDays(
            roastDate: roastDate,
            isFrozen: isFrozen,
            freezeDate: freezeDate,
            frozenDaysBanked: frozenDaysBanked,
            on: date,
            calendar: calendar
        )
    }

    /// Pure rest-day calculation (unit-testable without a model context).
    static func restDays(
        roastDate: Date,
        isFrozen: Bool,
        freezeDate: Date?,
        frozenDaysBanked: Int,
        on date: Date,
        calendar: Calendar = .current
    ) -> Int {
        var end = date
        if isFrozen, let freezeDate, freezeDate < end {
            end = freezeDate
        }
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: roastDate),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
        return max(0, elapsed - frozenDaysBanked)
    }

    /// Moves the batch into the freezer, pausing the rest counter.
    func freeze(on date: Date = .now) {
        guard !isFrozen else { return }
        isFrozen = true
        freezeDate = date
    }

    /// Returns the batch to room temperature, banking the frozen days so rest resumes
    /// from where it paused.
    func thaw(on date: Date = .now, calendar: Calendar = .current) {
        guard isFrozen else { return }
        if let freezeDate {
            let frozenDays = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: freezeDate),
                to: calendar.startOfDay(for: date)
            ).day ?? 0
            frozenDaysBanked += max(0, frozenDays)
        }
        isFrozen = false
        freezeDate = nil
    }
}

// MARK: - Bag Inventory & Search

extension CoffeeBean {
    static let processPresets: [String] = [
        "Washed", "Natural", "Honey", "Anaerobic", "Thermal Shock Washed", "Carbonic Maceration",
    ]

    static let bagWeightPresets: [Double] = [100, 125, 150, 200, 250, 500, 1000]

    /// Shots ordered newest first.
    var shotsNewestFirst: [ShotLog] {
        shots.sorted { $0.timestamp > $1.timestamp }
    }

    var latestShot: ShotLog? {
        shots.max { $0.timestamp < $1.timestamp }
    }

    func latestShot(for method: BrewMethod) -> ShotLog? {
        shots
            .filter { $0.brewMethod == method }
            .max { $0.timestamp < $1.timestamp }
    }

    /// Total grams of coffee dosed from this bag across all logged pulls.
    var usedGrams: Double {
        shots.reduce(0) { $0 + $1.dose }
    }

    /// Estimated grams remaining in this bag.
    var remainingGrams: Double {
        max(0, bagWeightGrams - usedGrams)
    }

    /// Fraction of the bag remaining (0.0 ... 1.0).
    var remainingFraction: Double {
        guard bagWeightGrams > 0 else { return 0 }
        return min(1, max(0, remainingGrams / bagWeightGrams))
    }

    /// The user's typical dose for this coffee: latest shot's dose on this bag, or `fallback` (e.g. from a previous bag of the same coffee, or 20.0g).
    func usualDose(fallback: Double = 20.0) -> Double {
        if let latestDose = latestShot?.dose, latestDose > 0 {
            return latestDose
        }
        return fallback > 0 ? fallback : 20.0
    }

    /// How many whole pulls are left in this bag based on `usualDose(fallback:)`.
    func estimatedShotsRemaining(fallbackDose: Double = 20.0) -> Int {
        let dose = usualDose(fallback: fallbackDose)
        guard dose > 0 else { return 0 }
        return max(0, Int((remainingGrams / dose).rounded(.down)))
    }

    /// Whether another `CoffeeBean` represents the same coffee (name + roaster).
    func isSameCoffee(as other: CoffeeBean) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(other.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            && roaster.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(other.roaster.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// Case-insensitive search across name, roaster, variety, and process.
    func matchesSearch(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return name.localizedStandardContains(trimmed)
            || roaster.localizedStandardContains(trimmed)
            || variety.localizedStandardContains(trimmed)
            || process.localizedStandardContains(trimmed)
    }
}
