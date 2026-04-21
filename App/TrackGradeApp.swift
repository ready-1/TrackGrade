import SwiftUI
import SwiftData

@main
struct TrackGradeApp: App {
    private let modelContainer: ModelContainer

    init() {
        let launchConfiguration = TrackGradeLaunchConfiguration.current
        TrackGradeLaunchConfiguration.prepareProcessForLaunch(launchConfiguration)

        do {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: launchConfiguration.usesUITestFixture
            )
            modelContainer = try ModelContainer(
                for: StoredColorBoxDevice.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create the TrackGrade model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
