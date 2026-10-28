import Foundation
import Testing
import SwiftData
@testable import EspressoLog

@Suite("Tasting after the cup")
@MainActor
struct TastingTests {

    private func makeShot(in context: ModelContext) -> ShotLog {
        let bean = CoffeeBean(name: "Ethiopia Guji", roaster: "Meron", variety: "Heirloom", process: "Washed", roastDate: .now)
        context.insert(bean)
        let shot = ShotLog(
            dose: 18.0, yield: 40.0, totalTime: 27.0, grindSetting: 1.0,
            brewTemperature: 93.0,
            flowQuality: .smoothCone, tasteBalance: .balancedSweet,
            flavorNotes: ["Honey"], actionableNextTweak: "Lock recipe",
            restDaysAtBrew: 14
        )
        context.insert(shot)
        shot.bean = bean
        try? context.save()
        return shot
    }

    @Test("Saving writes flow, balance, notes and tweak back to the brew")
    func savesTasting() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let shot = makeShot(in: context)
        let recipe = (shot.dose, shot.yield, shot.totalTime, shot.grindSetting)

        let model = ShotTastingViewModel(shot: shot)
        #expect(!model.hasChanges)
        #expect(!model.canSave)

        model.flowQuality = .channelingSquirts
        model.tasteBalance = .underExtractedSour
        model.toggleTag("Honey")
        model.addTag("  Lime ")
        model.nextTweak = "  Go finer → 0.9 "
        #expect(model.canSave)
        #expect(model.save(in: context))

        let saved = try #require(try context.fetch(FetchDescriptor<ShotLog>()).first)
        #expect(saved.flowQuality == .channelingSquirts)
        #expect(saved.tasteBalance == .underExtractedSour)
        #expect(saved.flavorNotes == ["Lime"])
        #expect(saved.actionableNextTweak == "Go finer → 0.9")
        // The recipe is never touched.
        #expect((saved.dose, saved.yield, saved.totalTime, saved.grindSetting) == recipe)
    }

    @Test("Cancelling leaves the brew unchanged and an empty tweak is cleared")
    func draftIsIsolated() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let shot = makeShot(in: context)

        let abandoned = ShotTastingViewModel(shot: shot)
        abandoned.tasteBalance = .overExtractedBitter
        #expect(shot.tasteBalance == .balancedSweet)

        let model = ShotTastingViewModel(shot: shot)
        model.nextTweak = "   "
        #expect(model.save(in: context))
        #expect(shot.actionableNextTweak == nil)
    }

    @Test("Insights and suggested tweaks follow the edited balance")
    func insightsFollowEdits() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let shot = makeShot(in: container.mainContext)

        let model = ShotTastingViewModel(shot: shot)
        #expect(model.suggestedTweaks.contains("Lock recipe"))

        model.tasteBalance = .underExtractedSour
        #expect(model.suggestedTweaks.contains("Go finer → 0.9"))
        #expect(!model.suggestedTweaks.contains("Lock recipe"))
        #expect(model.insights.allSatisfy { !$0.rule.isFeedHint })
    }
}
