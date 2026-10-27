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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ActiveBeanDashboardView()
                .tint(Palette.accent)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                AutoBackup.runIfEnabled(context: container.mainContext)
            }
        }
    }
}
