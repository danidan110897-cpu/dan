import SwiftUI
import WidgetKit
import ActivityKit

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestLiveActivity()
    }
}

struct RestLiveActivity: Widget {
    private let lime = Color(red: 0.78, green: 1.0, blue: 0.25)
    private let blue = Color(red: 0.35, green: 0.80, blue: 1.0)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "timer").font(.title).foregroundStyle(blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recupero").font(.headline)
                    Text("\(context.attributes.workoutName) · serie \(context.state.setsDone)/\(context.state.setsTotal)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(lime)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer").font(.title2).foregroundStyle(blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(lime)
                        .frame(width: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Recupero").font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.workoutName) · serie \(context.state.setsDone)/\(context.state.setsTotal)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(blue)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
                    .foregroundStyle(lime)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(blue)
            }
        }
    }
}
