import SwiftUI

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Oggi", systemImage: "flame.fill") { HomeView() }
            Tab("Progressi", systemImage: "chart.xyaxis.line") { ProgressTabView() }
            Tab("Corpo", systemImage: "figure.arms.open") { BodyView() }
        }
    }
}
