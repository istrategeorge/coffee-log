import Foundation
import CoreData
import Testing
import SwiftData
@testable import EspressoLog

@Suite("Bag rating, notes & favorites")
@MainActor
struct BagRatingTests {

    private func makeBag(_ name: String, roaster: String = "Meron", bagNumber: Int = 1) -> CoffeeBean {
        CoffeeBean(name: name, roaster: roaster, variety: "Gesha", process: "Washed", roastDate: .now, bagNumber: bagNumber)
    }

    @Test("Ratings are clamped to 1 – 10, notes trimmed, and clearing removes the score")
    func rateAndClear() {
        let bag = makeBag("Finca Deborah")

        bag.rate(14, notes: "  Jasmine, peach. Best on day 21.  ")
        #expect(bag.rating == 10)
        #expect(bag.ratingNotes == "Jasmine, peach. Best on day 21.")
        #expect(bag.ratedAt != nil)

        bag.rate(0, notes: "")
        #expect(bag.rating == 1)

        bag.rate(nil, notes: "Keep the notes")
        #expect(bag.rating == nil)
        #expect(bag.ratedAt == nil)
        #expect(bag.ratingNotes == "Keep the notes")
        #expect(bag.matchesSearch("notes"))
    }

    @Test("Favorite applies to every bag of the same coffee and nothing else")
    func favoriteSpansBags() {
        let first = makeBag("Finca Deborah")
        let second = makeBag("finca deborah ", bagNumber: 2)
        let other = makeBag("Finca Deborah", roaster: "Onyx")

        second.setFavorite(true, across: [first, second, other])
        #expect(first.isFavorite && second.isFavorite)
        #expect(!other.isFavorite)

        first.setFavorite(false, across: [first, second, other])
        #expect(!first.isFavorite && !second.isFavorite)
    }

    @Test("Backups carry ratings; restore fills unrated bags but never overwrites local notes")
    func backupRoundTrip() throws {
        let source = try ModelContainerFactory.make(inMemory: true)
        let bag = makeBag("Finca Deborah")
        source.mainContext.insert(bag)
        bag.rate(9, notes: "Would buy again")
        bag.setFavorite(true, across: [bag])
        try source.mainContext.save()

        let data = try BackupService.exportData(from: source.mainContext)
        let file = try BackupService.decode(data)

        // Into an empty store: everything comes across.
        let fresh = try ModelContainerFactory.make(inMemory: true)
        try BackupService.restore(file, into: fresh.mainContext)
        let restored = try #require(try fresh.mainContext.fetch(FetchDescriptor<CoffeeBean>()).first)
        #expect(restored.rating == 9)
        #expect(restored.ratingNotes == "Would buy again")
        #expect(restored.isFavorite)

        // Over a store where the same bag was re-rated: local wins.
        restored.rate(6, notes: "Faded after week 4")
        try BackupService.restore(file, into: fresh.mainContext)
        #expect(restored.rating == 6)
        #expect(restored.ratingNotes == "Faded after week 4")
    }

    @Test("Backups written before v1.7 (no rating fields) still decode")
    func oldBackupDecodes() throws {
        let json = """
        {"format":1,"app":"Dial-In","appVersion":"1.6","exportedAt":"2026-10-28T09:00:00Z",
         "equipment":[],"shots":[],
         "beans":[{"id":1,"name":"Kenya AA","roaster":"Meron","variety":"SL28","process":"Washed",
                   "roastDate":"2026-10-01T00:00:00Z","isFrozen":false,"frozenDaysBanked":0,
                   "bagWeightGrams":250,"bagNumber":1,"isActive":true,"isFinished":false,
                   "createdAt":"2026-10-02T00:00:00Z"}]}
        """
        let file = try BackupService.decode(Data(json.utf8))
        #expect(file.beans.first?.rating == nil)

        let container = try ModelContainerFactory.make(inMemory: true)
        try BackupService.restore(file, into: container.mainContext)
        let bean = try #require(try container.mainContext.fetch(FetchDescriptor<CoffeeBean>()).first)
        #expect(bean.rating == nil && !bean.isFavorite && bean.ratingNotes.isEmpty)
    }

    // MARK: - Migration

    @Test("The frozen V1 copies hash like the shipped models, and only CoffeeBean changes in V2")
    func frozenSchemaMatches() throws {
        let v1 = try #require(NSManagedObjectModel.makeManagedObjectModel(for: EspressoSchemaV1.models))
        let v2 = try #require(NSManagedObjectModel.makeManagedObjectModel(for: EspressoSchemaV2.models))
        let old = v1.entityVersionHashesByName
        let new = v2.entityVersionHashesByName

        // ShotLog and EquipmentProfile are unchanged since v1.0, so identical hashes prove the frozen
        // copies are faithful (same attributes and relationships).
        #expect(old["ShotLog"] == new["ShotLog"])
        #expect(old["EquipmentProfile"] == new["EquipmentProfile"])
        #expect(old["CoffeeBean"] != new["CoffeeBean"])
    }

    @Test("A store written by v1.6 opens in v1.7 with every bag and brew intact")
    func migratesV1Store() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        do {
            let schema = Schema(versionedSchema: EspressoSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = container.mainContext
            let bean = EspressoSchemaV1.CoffeeBean()
            bean.name = "Kenya AA"
            bean.roaster = "Meron"
            context.insert(bean)
            let shot = EspressoSchemaV1.ShotLog()
            shot.dose = 18.5
            context.insert(shot)
            shot.bean = bean
            try context.save()
        }

        let container = try ModelContainerFactory.make(url: url)
        let beans = try container.mainContext.fetch(FetchDescriptor<CoffeeBean>())
        let bean = try #require(beans.first)
        #expect(beans.count == 1)
        #expect(bean.name == "Kenya AA")
        #expect(bean.shots.map(\.dose) == [18.5])
        #expect(bean.rating == nil)
        #expect(bean.ratingNotes.isEmpty)
        #expect(!bean.isFavorite)
    }
}
