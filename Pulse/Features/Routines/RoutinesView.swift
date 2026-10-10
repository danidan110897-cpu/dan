import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    @AppStorage("trainReminder") private var trainReminder = false
    @State private var active: WorkoutSession?
    @State private var pending: PendingStart?
    @State private var editing: Routine?

    var body: some View {
        NavigationStack {
            List {
                if !routines.isEmpty {
                    Section {
                        WorkoutHub(routines: routines, logs: logs) { routine, lighter in
                            pending = PendingStart(routine: routine, lighter: lighter)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    if routines.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "list.bullet.clipboard").font(.largeTitle).foregroundStyle(Theme.accent)
                            Text("Nessuna routine").font(.headline)
                            Text("Creane una a mano oppure falla creare all'AI.")
                                .font(.footnote).foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(routines) { routine in
                        HStack {
                            Button { editing = routine } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(routine.name).font(.headline).foregroundStyle(.white)
                                    Text("\(routine.items.count) esercizi · circa \(routine.estimatedMinutes) min\(routine.weekdays.isEmpty ? "" : " · " + weekdayText(routine))")
                                        .font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                pending = PendingStart(routine: routine)
                            } label: {
                                Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(routine.items.isEmpty)
                            .accessibilityLabel("Avvia \(routine.name)")
                        }
                        .listRowBackground(Theme.card)
                        .contextMenu {
                            Button("Duplica", systemImage: "plus.square.on.square") { duplicate(routine) }
                        }
                    }
                    .onDelete { offsets in offsets.map { routines[$0] }.forEach(context.delete) }
                } header: {
                    Text("Le tue routine")
                }

                Section {
                    NavigationLink { AIRoutineView { editing = $0 } } label: {
                        Label("Crea con l'AI", systemImage: "sparkles")
                    }
                    NavigationLink { ExerciseBrowser() } label: {
                        Label("Libreria esercizi", systemImage: "books.vertical")
                    }
                    NavigationLink { HistoryView() } label: {
                        Label("Cronologia", systemImage: "clock.arrow.circlepath")
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Allenamenti")
            .toolbar {
                Button("Nuova routine", systemImage: "plus") {
                    let r = Routine(name: "Nuova routine")
                    context.insert(r)
                    editing = r
                }
            }
            .navigationDestination(item: $editing) { RoutineEditor(routine: $0) }
            .navigationDestination(item: $active) { WorkoutSessionView(session: $0) }
        }
        .startFlow(pending: $pending, active: $active)
        .task(id: routines.count) {
            if trainReminder { await Reminders.scheduleTraining(routines: routines) }
        }
    }

    private func weekdayText(_ routine: Routine) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        return routine.weekdays.sorted { (($0 + 5) % 7) < (($1 + 5) % 7) }
            .map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    private func duplicate(_ routine: Routine) {
        let copy = Routine(name: routine.name + " (copia)", restSeconds: routine.restSeconds)
        context.insert(copy)
        for item in routine.sortedItems {
            guard let ex = item.exercise else { continue }
            let c = RoutineItem(order: item.order, exercise: ex, sets: item.sets, reps: item.reps, weight: item.weight)
            c.supersetGroup = item.supersetGroup
            c.note = item.note
            copy.items.append(c)
        }
    }
}
