import SwiftUI
import SwiftData

/// Sample data matching the reference A6 espresso notebook ("Colombia Bourbon Aji · Meron").
@MainActor
enum SampleData {
    static func insertNotebookSample(in context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let roastDate = calendar.date(byAdding: .day, value: -18, to: now) ?? now

        let equipment = EquipmentProfile(
            machineName: "La Marzocco Linea Micra",
            grinderName: "Timemore Sculptor 078s",
            grinderZeroOffset: -1,
            basket: "Normcore 20g High Extraction",
            puckScreen: "1.7mm",
            isActive: true
        )
        context.insert(equipment)
        context.activate(equipment)

        let bean = CoffeeBean(
            name: "Colombia Las Flores",
            roaster: "Meron",
            variety: "Bourbon Aji",
            process: "Thermal Shock Washed",
            roastDate: roastDate,
            isFrozen: false,
            isActive: true
        )
        context.insert(bean)
        context.activate(bean)

        let pull1Date = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let pull1 = ShotLog(
            timestamp: pull1Date,
            dose: 20.0,
            yield: 48.0,
            totalTime: 28.0,
            grindSetting: 0.5,
            grinderZeroOffset: -1,
            grinderRPM: 1200,
            feedMethod: .slowFeed,
            brewTemperature: 93.5,
            preBrewPulse: 3.0,
            preBrewPause: 5.0,
            flowQuality: .smoothCone,
            tasteBalance: .balancedSweet,
            flavorNotes: ["Juicy Peach", "Honey", "Floral"],
            actionableNextTweak: "Freeze Day 22",
            restDaysAtBrew: 16
        )

        let pull2Date = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let pull2 = ShotLog(
            timestamp: pull2Date,
            dose: 20.0,
            yield: 49.2,
            totalTime: 29.0,
            grindSetting: 0.4,
            grinderZeroOffset: -1,
            grinderRPM: 1200,
            feedMethod: .slowFeed,
            brewTemperature: 93.5,
            preBrewPulse: 3.0,
            preBrewPause: 5.0,
            flowQuality: .smoothCone,
            tasteBalance: .balancedSweet,
            flavorNotes: ["Raspberry", "Honey"],
            actionableNextTweak: "Freeze vials Day 24",
            restDaysAtBrew: 17
        )

        let pull3 = ShotLog(
            timestamp: now,
            dose: 20.0,
            yield: 48.5,
            totalTime: 27.0,
            grindSetting: 0.5,
            grinderZeroOffset: -1,
            grinderRPM: 1100,
            feedMethod: .slowFeed,
            brewTemperature: 94.0,
            preBrewPulse: 3.0,
            preBrewPause: 5.0,
            flowQuality: .channelingSquirts,
            tasteBalance: .underExtractedSour,
            flavorNotes: ["Lime"],
            actionableNextTweak: "Go finer (0.3) · Temp+ / RPM-",
            restDaysAtBrew: 18
        )

        for shot in [pull1, pull2, pull3] {
            context.insert(shot)
            shot.bean = bean
            shot.equipment = equipment
        }

        try? context.save()
    }
}

/// Preview modifier that injects an in-memory SwiftData container populated with the notebook sample.
struct SampleDataPreviewModifier: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        SampleData.insertNotebookSample(in: container.mainContext)
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self = .modifier(SampleDataPreviewModifier())
}
