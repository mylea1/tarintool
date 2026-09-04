import SwiftUI

@main
struct KiloWatchApp: App {
    @StateObject private var workout = WatchWorkoutModel()

    var body: some Scene {
        WindowGroup {
            WorkoutWatchView(model: workout)
        }
  }
}
