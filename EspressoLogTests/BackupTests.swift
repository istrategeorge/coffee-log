import Foundation
import Testing
import SwiftData
@testable import EspressoLog

@Suite("Backup export & restore")
@MainActor
struct BackupTests {

    /// A store with one gear profile, two bags and three brews (one pour over, one without gear).
    private func makePopulatedStore() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let profile = EquipmentProfile(
            machineName: "Decent DE1",
            grinderName: "Zerno Z1",
            basket: "IMS 18g",
            defaultDripper: "Orea V4",
            isActive: true
        )
        context.insert(profile)

        let roast = Date(timeIntervalSince1970: 1_788_000_000)
        let firstBag = CoffeeBean(name: "Colombia Bourbon Aji", roaster: "Meron", variety: "Bourbon Aji", process: "Washed", roastDate: roast, bagWeightGrams: 250)
        let secondBag = CoffeeBean(name: "Colombia Bourbon Aji", roaster: "Meron", variety: "Bourbon Aji", process: "Washed", roastDate: roast, bagNumber: 2, isActive: true)
        secondBag.freeze(on: roast.addingTimeInterval(86_400 * 20))
        context.insert(firstBag)
        context.insert(secondBag)

        let espresso = ShotLog(
            timestamp: roast.addingTimeInterval(86_400 * 16),
            dose: 20.0, yield: 48.0, totalTime: 28.0, grindSetting: 0.5,
            grinderZeroOffset: -1, grinderRPM: 1200,
            brewTemperature: 93.5, preBrewPulse: 3, preBrewPause: 5,
            flowQuality: .channelingSquirts, tasteBalance: .underExtractedSour,
            flavorNotes: ["Lime", "Tart"], actionableNextTweak: "Go finer (-0.7)",
            restDaysAtBrew: 16
        )
        let pourOver = ShotLog(
            timestamp: roast.addingTimeInterval(86_400 * 17),
            brewMethod: .pourOver,
            dose: 15.0, yield: 250.0, totalTime: 155.0, grindSetting: 6.5,
            brewTemperature: 94.0, preBrewPause: 45, dripper: "Orea V4",
            bloomWater: 45, pourCount: 4, agitation: .gentle,
            tasteBalance: .balancedSweet, restDaysAtBrew: 17
        )
        let noGear = ShotLog(
            timestamp: roast.addingTimeInterval(86_400 * 18),
            dose: 18.0, yield: 40.0, totalTime: 30.0, grindSetting: 1.0,
            brewTemperature: 93.0, tasteBalance: .overExtractedBitter
        )
        for shot in [espresso, pourOver, noGear] { context.insert(shot) }
        espresso.bean = firstBag
        espresso.equipment = profile
        pourOver.bean = secondBag
        pourOver.equipment = profile
        noGear.bean = secondBag

        try context.save()
        return container
    }

    @Test("Export → JSON → restore into a fresh install reproduces bags, brews, gear and links")
    func roundTripIntoFreshInstall() throws {
        let source = try makePopulatedStore()
        let data = try BackupService.exportData(from: source.mainContext)

        let target = try ModelContainerFactory.make(inMemory: true)
        ModelContainerFactory.seedDefaultsIfNeeded(in: target.mainContext)
        let summary = try BackupService.restore(BackupService.decode(data), into: target.mainContext)

        #expect(summary.beansAdded == 2)
        #expect(summary.shotsAdded == 3)
        #expect(summary.equipmentAdded == 1)

        let context = target.mainContext
        let beans = try context.fetch(FetchDescriptor<CoffeeBean>(sortBy: [SortDescriptor(\.bagNumber)]))
        let shots = try context.fetch(FetchDescriptor<ShotLog>(sortBy: [SortDescriptor(\.timestamp)]))
        let profiles = try context.fetch(FetchDescriptor<EquipmentProfile>())
        #expect(beans.count == 2)
        #expect(shots.count == 3)
        #expect(profiles.count == 2) // seeded default + restored profile

        // Active selections follow the backup, since the fresh install had nothing logged.
        #expect(beans.first(where: \.isActive)?.bagNumber == 2)
        #expect(profiles.first(where: \.isActive)?.machineName == "Decent DE1")

        // Freezer state survives.
        #expect(beans[1].isFrozen)
        #expect(beans[1].freezeDate != nil)

        // Field values and relationships survive.
        let espresso = try #require(shots.first)
        #expect(espresso.bean?.bagNumber == 1)
        #expect(espresso.equipment?.machineName == "Decent DE1")
        #expect(espresso.grinderZeroOffset == -1)
        #expect(espresso.grinderRPM == 1200)
        #expect(espresso.flowQuality == .channelingSquirts)
        #expect(espresso.tasteBalance == .underExtractedSour)
        #expect(espresso.flavorNotes == ["Lime", "Tart"])
        #expect(espresso.actionableNextTweak == "Go finer (-0.7)")
        #expect(espresso.restDaysAtBrew == 16)

        let pourOver = shots[1]
        #expect(pourOver.brewMethod == .pourOver)
        #expect(pourOver.dripper == "Orea V4")
        #expect(pourOver.pourCount == 4)
        #expect(pourOver.agitation == .gentle)
        #expect(pourOver.bean?.bagNumber == 2)

        #expect(shots[2].equipment == nil)
        #expect(beans[1].shots.count == 2)
    }

    @Test("Restoring the same backup twice adds nothing the second time")
    func restoreIsIdempotent() throws {
        let source = try makePopulatedStore()
        let file = try BackupService.decode(BackupService.exportData(from: source.mainContext))

        let target = try ModelContainerFactory.make(inMemory: true)
        try BackupService.restore(file, into: target.mainContext)
        let second = try BackupService.restore(file, into: target.mainContext)

        #expect(second.beansAdded == 0)
        #expect(second.shotsAdded == 0)
        #expect(second.equipmentAdded == 0)
        #expect(second.beansSkipped == 2)
        #expect(second.shotsSkipped == 3)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<ShotLog>()) == 3)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<CoffeeBean>()) == 2)
    }

    @Test("Restoring into a store already holding the same data skips every entry")
    func restoreOverOwnData() throws {
        let store = try makePopulatedStore()
        let file = try BackupService.decode(BackupService.exportData(from: store.mainContext))
        let summary = try BackupService.restore(file, into: store.mainContext)

        #expect(summary == BackupService.RestoreSummary(beansSkipped: 2, shotsSkipped: 3, equipmentSkipped: 1))
    }

    @Test("Non-backup files and backups from a newer format are rejected")
    func rejectsUnreadableAndNewerFiles() throws {
        #expect(throws: BackupService.BackupError.self) {
            try BackupService.decode(Data("{\"hello\": 1}".utf8))
        }

        let newer = Data("{\"format\": 99}".utf8)
        do {
            _ = try BackupService.decode(newer)
            Issue.record("Expected a newer-format error")
        } catch BackupService.BackupError.newerFormat(let format) {
            #expect(format == 99)
        }
    }
}
