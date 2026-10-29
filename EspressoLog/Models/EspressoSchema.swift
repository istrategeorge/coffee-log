/// Version 1 of the persistent schema (v1.0 – v1.6), frozen.
///
/// These copies must keep exactly the stored properties the app shipped with, so SwiftData can
/// recognize existing stores and migrate them. Never edit them; add a new version instead.
enum EspressoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [CoffeeBean.self, EquipmentProfile.self, ShotLog.self]
    }

    @Model
    final class CoffeeBean {
        var name: String = ""
        var roaster: String = ""
        var variety: String = ""
        var process: String = ""
        var roastDate: Date = Date.now
        var isFrozen: Bool = false
        var freezeDate: Date?
        var frozenDaysBanked: Int = 0
        var bagWeightGrams: Double = 250.0
        var bagNumber: Int = 1
        var isActive: Bool = false
        var isFinished: Bool = false
        var finishedDate: Date?
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \ShotLog.bean)
        var shots: [ShotLog] = []

        init() {}
    }

    @Model
    final class EquipmentProfile {
        var machineName: String = ""
        var grinderName: String = ""
        var grinderZeroOffset: Int = 0
        var basket: String = ""
        var puckScreen: String?
        var defaultDripper: String = "Hario V60 01"
        var isActive: Bool = false
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \ShotLog.equipment)
        var shots: [ShotLog] = []

        init() {}
    }

    @Model
    final class ShotLog {
        var timestamp: Date = Date.now
        var brewMethodRaw: String = "espresso"
        var dose: Double = 18.0
        var yield: Double = 36.0
        var totalTime: Double = 28.0
        var grindSetting: Double = 0.0
        var grinderZeroOffset: Int = 0
        var grinderRPM: Int?
        var feedMethodRaw: String = "slowFeed"
        var brewTemperature: Double = 93.0
        var preBrewPulse: Double = 0.0
        var preBrewPause: Double = 0.0
        var dripper: String?
        var bloomWater: Double = 0.0
        var pourCount: Int = 3
        var agitationRaw: String = "moderateSwirl"
        var flowQualityRaw: String = "smoothCone"
        var tasteBalanceRaw: String = "balancedSweet"
        var flavorNotes: [String] = []
        var actionableNextTweak: String?
        var restDaysAtBrew: Int = 0

        var bean: CoffeeBean?
        var equipment: EquipmentProfile?

        init() {}
    }
}

/// Version 2 (v1.7): bag rating, rating notes and favorite on `CoffeeBean`.
///
/// When the models change again, freeze copies of the current models inside this enum (as in V1),
/// add `EspressoSchemaV3`, and append a `MigrationStage` to `EspressoMigrationPlan`.
enum EspressoSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [CoffeeBean.self, EquipmentProfile.self, ShotLog.self]
    }
}

enum EspressoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EspressoSchemaV1.self, EspressoSchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    /// New attributes are optional or defaulted, so existing bags simply start unrated.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: EspressoSchemaV1.self, toVersion: EspressoSchemaV2.self)
}

enum ModelContainerFactory {
    /// - Parameter url: Store location; `nil` uses the default store. Tests pass a temporary file.
    static func make(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: EspressoSchemaV2.self)
        let configuration = if let url {
            ModelConfiguration(schema: schema, url: url)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: EspressoMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Inserts a default, active equipment profile on first launch.
    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<EquipmentProfile>())) ?? 0
        guard count == 0 else { return }
        let profile = EquipmentProfile.makeDefault()
        profile.isActive = true
        context.insert(profile)
        try? context.save()
    }
}

extension ModelContext {
    /// Makes `bean` the single active bean.
    func activate(_ bean: CoffeeBean) {
        let all = (try? fetch(FetchDescriptor<CoffeeBean>())) ?? []
        for candidate in all {
            candidate.isActive = candidate.persistentModelID == bean.persistentModelID
        }
        bean.isActive = true
    }

    /// Makes `profile` the single active equipment profile.
    func activate(_ profile: EquipmentProfile) {
        let all = (try? fetch(FetchDescriptor<EquipmentProfile>())) ?? []
        for candidate in all {
            candidate.isActive = candidate.persistentModelID == profile.persistentModelID
        }
        profile.isActive = true
    }
}
