import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestLiveActivity()
    }
}

struct RestLiveActivity: Widget {
    private let lime = Color(red: 0.78, green: 1.0, blue: 0.25)
    private let blue = Color(red: 0.35, green: 0.80, blue: 1.0)

    private func label(_ phase: String) -> String {
        switch phase {
        case "work": "Serie in corso"
        case "ready": "Preparati"
        default: "Recupero"
        }
    }

    private func icon(_ phase: String) -> String {
        switch phase {
        case "work": "figure.strengthtraining.traditional"
        case "ready": "hourglass"
        default: "timer"
        }
    }

    private func tint(_ phase: String) -> Color { phase == "rest" ? blue : lime }

    private func clock(_ state: RestAttributes.ContentState, size: CGFloat) -> some View {
        Text(timerInterval: Date.now...max(state.endDate, Date.now), countsDown: true)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint(state.phase))
            .multilineTextAlignment(.trailing)
    }

    private func doneButton(_ state: RestAttributes.ContentState) -> some View {
        Button(intent: CompleteSetIntent()) {
            Label("Fatto", systemImage: "checkmark")
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(lime, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            let state = context.state
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: icon(state.phase)).font(.title).foregroundStyle(tint(state.phase))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(state.phase)).font(.headline)
                        Text(state.headline.isEmpty ? context.attributes.workoutName : state.headline)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Text("Serie totali \(state.setsDone)/\(state.setsTotal)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    clock(state, size: 34).frame(width: 90, alignment: .trailing)
                }
                if state.phase == "work" { doneButton(state) }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.85))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(state.phase)).font(.title2).foregroundStyle(tint(state.phase))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    clock(state, size: 28).frame(width: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(label(state.phase)).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(state.headline.isEmpty ? context.attributes.workoutName : state.headline)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if state.phase == "work" { doneButton(state) }
                    }
                }
            } compactLeading: {
                Image(systemName: icon(state.phase)).foregroundStyle(tint(state.phase))
            } compactTrailing: {
                clock(state, size: 14).frame(width: 44)
            } minimal: {
                Image(systemName: icon(state.phase)).foregroundStyle(tint(state.phase))
            }
        }
    }
}
