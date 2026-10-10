import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, workouts, food, progress, body
}

@MainActor @Observable
final class Router {
    var tab: AppTab = .today
}

@main
struct PulseApp: App {
    @State private var router = Router()
    @State private var profile = ProfileStore()
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(router)
                    .environment(profile)
                if lock.isLocked { LockOverlay(lock: lock).zIndex(1) }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .task { lock.lockIfNeeded(); await lock.unlock() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { lock.lockIfNeeded() }
                if phase == .active { Task { await lock.unlock() } }
            }
        }
        .modelContainer(for: [
            Exercise.self, Routine.self, RoutineItem.self,
            WorkoutLog.self, LogEntry.self, LogSet.self,
            FoodItem.self, FoodEntry.self, ProgressPhoto.self,
        ])
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        @Bindable var router = router
        Group {
            if onboarded {
                TabView(selection: $router.tab) {
                    Tab("Oggi", systemImage: "flame.fill", value: AppTab.today) { HomeView() }
                    Tab("Allenamenti", systemImage: "dumbbell.fill", value: AppTab.workouts) { RoutinesView() }
                    Tab("Cibo", systemImage: "fork.knife", value: AppTab.food) { FoodView() }
                    Tab("Progressi", systemImage: "chart.xyaxis.line", value: AppTab.progress) { ProgressTabView() }
                    Tab("Corpo", systemImage: "figure.arms.open", value: AppTab.body) { BodyView() }
                }
                .transition(.opacity)
            } else {
                OnboardingView { withAnimation(Motion.smooth) { onboarded = true } }
                    .transition(.opacity)
            }
        }
        .task { ExerciseSeed.seedIfNeeded(context) }
    }
}
