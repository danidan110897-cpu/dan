import SwiftUI
import HealthKit
import WatchKit

/// Lets the iPhone launch the Watch app when a workout starts (HealthKit startWatchApp). The app itself starts the workout session on launch.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {}
}

@main
struct PulseWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    @State private var store = WatchStore()
    @State private var health = HealthWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(store: store, health: health)
                .tint(WatchTheme.accent)
                .onAppear { store.start() }
        }
    }
}

enum WatchTheme {
    static let accent = Color(red: 0.78, green: 1.0, blue: 0.25)
    static let heart = Color(red: 1.0, green: 0.30, blue: 0.40)
    static let rest = Color(red: 0.35, green: 0.80, blue: 1.0)
}
