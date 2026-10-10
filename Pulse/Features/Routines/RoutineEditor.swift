import SwiftUI
import SwiftData

struct RoutineEditor: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var context
    @State private var showPicker = false

    var body: some View {
        List {
            Section {
                TextField("Nome routine", text: $routine.name)
                Stepper("Recupero: \(routine.restSeconds) s", value: $routine.restSeconds, in: 15...300, step: 15)
            }
            .listRowBackground(Theme.card)

            Section {
                weekdayChips
            } header: {
                Text("Giorni della settimana")
            } footer: {
                Text("Nei giorni scelti la routine compare in automatico in Allenamenti e puoi ricevere il promemoria.")
            }
            .listRowBackground(Theme.card)

            Section {
                ForEach(routine.sortedItems) { item in
                    ItemRow(item: item, canLinkToPrevious: canLink(item)) { toggleSuperset(item) }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button { showPicker = true } label: {
                    Label("Aggiungi esercizi", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Esercizi")
            } footer: {
                if !routine.items.isEmpty { Text("Tocca Modifica per riordinare trascinando.") }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ExerciseBrowser(onPick: add)
            }
        }
    }

    private var weekdayChips: some View {
        let order = [2, 3, 4, 5, 6, 7, 1]   // Monday first
        let letters = ["L", "M", "M", "G", "V", "S", "D"]
        return HStack(spacing: 6) {
            ForEach(Array(order.enumerated()), id: \.offset) { i, weekday in
                let on = routine.weekdays.contains(weekday)
                Button {
                    withAnimation(Motion.snappy) {
                        if on { routine.weekdays.removeAll { $0 == weekday } } else { routine.weekdays.append(weekday) }
                    }
                } label: {
                    Text(letters[i]).font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(on ? Theme.accent : Color.white.opacity(0.08), in: Circle())
                        .foregroundStyle(on ? .black : .white)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: routine.weekdays)
    }

    private func add(_ exercises: [Exercise]) {
        var order = routine.items.count
        for ex in exercises {
            routine.items.append(RoutineItem(order: order, exercise: ex))
            order += 1
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var arr = routine.sortedItems
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, item) in arr.enumerated() { item.order = i }
    }

    private func delete(at offsets: IndexSet) {
        let arr = routine.sortedItems
        offsets.map { arr[$0] }.forEach(context.delete)
        for (i, item) in routine.sortedItems.enumerated() { item.order = i }
    }

    private func canLink(_ item: RoutineItem) -> Bool { item.order > 0 }

    private func toggleSuperset(_ item: RoutineItem) {
        let arr = routine.sortedItems
        guard let idx = arr.firstIndex(where: { $0 === item }), idx > 0 else { return }
        let prev = arr[idx - 1]
        if item.supersetGroup != 0 && item.supersetGroup == prev.supersetGroup {
            item.supersetGroup = 0
            if !arr.contains(where: { $0 !== prev && $0.supersetGroup == prev.supersetGroup }) { prev.supersetGroup = 0 }
        } else {
            if prev.supersetGroup == 0 {
                prev.supersetGroup = (arr.map(\.supersetGroup).max() ?? 0) + 1
            }
            item.supersetGroup = prev.supersetGroup
        }
    }
}

private struct ItemRow: View {
    @Bindable var item: RoutineItem
    let canLinkToPrevious: Bool
    let onToggleSuperset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.exercise?.name ?? "Esercizio").font(.headline)
                if item.supersetGroup != 0 {
                    Text("SUPERSET").font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.recover.opacity(0.2), in: Capsule())
                        .foregroundStyle(Theme.recover)
                }
                Spacer()
                if canLinkToPrevious {
                    Button(action: onToggleSuperset) {
                        Image(systemName: item.supersetGroup != 0 ? "link.circle.fill" : "link.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Superset con l'esercizio precedente")
                }
            }
            Text(item.exercise?.muscle.label ?? "").font(.caption).foregroundStyle(Theme.secondaryText)
            Stepper("\(item.sets) serie", value: $item.sets, in: 1...10)
            Stepper("\(item.reps) ripetizioni", value: $item.reps, in: 1...50)
            HStack {
                Text("Peso iniziale (kg)").font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
                TextField("0", value: $item.weight, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
            }
            TextField("Nota (opzionale)", text: $item.note).font(.footnote)
        }
        .padding(.vertical, 4)
    }
}
