import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]

    var body: some View {
        List {
            if logs.isEmpty {
                Text("Ancora nessun allenamento completato.")
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)
            }
            ForEach(logs) { log in
                NavigationLink { LogDetailView(log: log) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.name).font(.headline)
                        Text("\(log.date.formatted(date: .abbreviated, time: .shortened)) · \(log.durationSeconds / 60) min · \(Int(log.volume)) kg")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { offsets in offsets.map { logs[$0] }.forEach(context.delete) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Cronologia")
    }
}

struct LogDetailView: View {
    let log: WorkoutLog

    var body: some View {
        List {
            ForEach(log.sortedEntries) { entry in
                Section(entry.exerciseName) {
                    ForEach(entry.sortedSets) { set in
                        HStack {
                            Text("Serie \(set.order + 1)").foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text("\(formatWeight(set.weight)) kg × \(set.reps)").fontWeight(.semibold)
                            if set.isPR {
                                Text("PR").font(.caption2.weight(.heavy))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.move, in: Capsule())
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(log.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
