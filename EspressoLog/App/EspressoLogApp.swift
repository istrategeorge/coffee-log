import SwiftUI
import SwiftData

@main
struct EspressoLogApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
        ModelContainerFactory.seedDefaultsIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ActiveBeanDashboardView()
        }
        .modelContainer(container)
    }
}
