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
                    HomeView().tabItem { Label("Oggi", systemImage: "flame.fill") }.tag(AppTab.today)
                    RoutinesView().tabItem { Label("Allenamenti", systemImage: "dumbbell.fill") }.tag(AppTab.workouts)
                    FoodView().tabItem { Label("Cibo", systemImage: "fork.knife") }.tag(AppTab.food)
                    ProgressTabView().tabItem { Label("Progressi", systemImage: "chart.xyaxis.line") }.tag(AppTab.progress)
                    BodyView().tabItem { Label("Corpo", systemImage: "figure.arms.open") }.tag(AppTab.body)
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
