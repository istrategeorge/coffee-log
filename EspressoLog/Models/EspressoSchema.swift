import Foundation
import SwiftData

/// Version 1 of the persistent schema.
///
/// When the models change, freeze copies of the current models inside this enum,
/// add `EspressoSchemaV2`, and append a `MigrationStage` to `EspressoMigrationPlan`.
enum EspressoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [CoffeeBean.self, EquipmentProfile.self, ShotLog.self]
    }
}

enum EspressoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EspressoSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: EspressoSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
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
