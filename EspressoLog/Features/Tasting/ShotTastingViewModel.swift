import Foundation
import SwiftData
import OSLog

/// Edits the "after the cup" half of a saved brew: flow / bed read, balance, flavor notes and the
/// next tweak. Changes stay in the draft until `save(in:)`, so Cancel leaves the brew untouched.
@MainActor
@Observable
final class ShotTastingViewModel {
    private static let logger = Logger(subsystem: "EspressoLog", category: "Tasting")

    let shot: ShotLog
    let flavorSuggestions: [String]

    var flowQuality: FlowQuality
    var tasteBalance: TasteBalance?
    var flavorNotes: [String]
    var nextTweak: String

    init(shot: ShotLog) {
        self.shot = shot
        self.flowQuality = shot.flowQuality
        self.tasteBalance = shot.tasteBalance
        self.flavorNotes = shot.flavorNotes
        self.nextTweak = shot.actionableNextTweak ?? ""
        self.flavorSuggestions = ShotLoggingViewModel.makeFlavorSuggestions(from: shot.bean?.shotsNewestFirst ?? [shot])
    }

    var method: BrewMethod { shot.brewMethod }

    /// The saved brew with the edited tasting applied, for insights and tweak suggestions.
    var draft: ShotSnapshot {
        var snapshot = shot.snapshot
        snapshot.flowQuality = flowQuality
        snapshot.tasteBalance = tasteBalance
        return snapshot
    }

    /// Feed-switch hints only make sense while dialing in the next pull, so they are left out here.
    var insights: [ExtractionInsight] {
        ExtractionInsightsEngine.insights(for: draft, baselineFeed: nil)
            .filter { !$0.rule.isFeedHint }
    }

    var suggestedTweaks: [String] {
        ExtractionInsightsEngine.suggestedTweaks(for: draft)
    }

    private var trimmedTweak: String {
        nextTweak.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasChanges: Bool {
        flowQuality != shot.flowQuality
            || tasteBalance != shot.tasteBalance
            || flavorNotes != shot.flavorNotes
            || trimmedTweak != (shot.actionableNextTweak ?? "")
    }

    var canSave: Bool { tasteBalance != nil && hasChanges }

    // MARK: Flavor & tweak

    func toggleTag(_ tag: String) {
        if let index = flavorNotes.firstIndex(of: tag) {
            flavorNotes.remove(at: index)
        } else {
            flavorNotes.append(tag)
        }
    }

    func addTag(_ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty,
              !flavorNotes.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
        else { return }
        flavorNotes.append(tag)
    }

    func applyTweak(_ tweak: String) {
        let current = nextTweak.trimmingCharacters(in: .whitespaces)
        guard !current.contains(tweak) else { return }
        nextTweak = current.isEmpty ? tweak : "\(current) · \(tweak)"
    }

    // MARK: Persist

    /// Writes the tasting back onto the brew. Returns `false` when there is nothing valid to save.
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard let tasteBalance else { return false }
        shot.flowQuality = flowQuality
        shot.tasteBalance = tasteBalance
        shot.flavorNotes = flavorNotes
        shot.actionableNextTweak = trimmedTweak.isEmpty ? nil : trimmedTweak

        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save tasting: \(error.localizedDescription, privacy: .public)")
        }
        return true
    }
}
