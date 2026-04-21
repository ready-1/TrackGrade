import SwiftUI
import SwiftData

@main
struct TrackGradeApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: StoredColorBoxDevice.self)
        } catch {
            fatalError("Failed to create the TrackGrade model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
