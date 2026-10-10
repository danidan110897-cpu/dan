import SwiftUI
import SwiftData

/// Searchable exercise list. With `onPick` it works as a multi-select picker, without it as a plain library.
struct ExerciseBrowser: View {
    var onPick: (([Exercise]) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var all: [Exercise]
    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @State private var chosen: Set<String> = []
    @State private var showCreate = false
    @State private var detail: Exercise?

    init(onPick: (([Exercise]) -> Void)? = nil) {
        self.onPick = onPick
    }

    private var isPicker: Bool { onPick != nil }

    private var filtered: [Exercise] {
        all.filter { ex in
            (muscle == nil || ex.muscle == muscle) &&
            (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("Tutti", selected: muscle == nil) { muscle = nil }
                        ForEach(MuscleGroup.allCases) { m in
                            chip(m.label, selected: muscle == m) { muscle = (muscle == m ? nil : m) }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(filtered) { ex in
                    HStack(spacing: 0) {
                    Button { tap(ex) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: ex.muscle.symbol).frame(width: 28).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).foregroundStyle(.white)
                                Text("\(ex.muscle.label) · \(ex.equipment.label)")
                                    .font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            if isPicker {
                                Image(systemName: chosen.contains(ex.key) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(chosen.contains(ex.key) ? Theme.accent : Theme.secondaryText)
                                    .symbolEffect(.bounce, value: chosen.contains(ex.key))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    if isPicker {
                        Button { detail = ex } label: { Image(systemName: "info.circle").padding(.leading, 12) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.secondaryText)
                            .accessibilityLabel("Come si esegue \(ex.name)")
                    }
                    }
                    .swipeActions {
                        if ex.isCustom {
                            Button("Elimina", role: .destructive) { context.delete(ex) }
                        }
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isPicker ? "Aggiungi esercizi" : "Libreria")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Cerca esercizio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuovo", systemImage: "plus") { showCreate = true }
            }
            if isPicker {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi (\(chosen.count))") {
                        onPick?(all.filter { chosen.contains($0.key) })
                        dismiss()
                    }
                    .disabled(chosen.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCreate) { CustomExerciseForm() }
        .sheet(item: $detail) { ex in NavigationStack { ExerciseDetailView(exercise: ex) } }
        .animation(Motion.snappy, value: filtered.count)
    }

    private func tap(_ ex: Exercise) {
        guard isPicker else { detail = ex; return }
        if chosen.contains(ex.key) { chosen.remove(ex.key) } else { chosen.insert(ex.key) }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Theme.accent : Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(selected ? .black : .white)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct CustomExerciseForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome esercizio", text: $name)
                Picker("Muscolo", selection: $muscle) {
                    ForEach(MuscleGroup.allCases) { Text($0.label).tag($0) }
                }
                Picker("Attrezzo", selection: $equipment) {
                    ForEach(Equipment.allCases) { Text($0.label).tag($0) }
                }
            }
            .navigationTitle("Nuovo esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        context.insert(Exercise(key: "custom_\(UUID().uuidString)", name: trimmed,
                                                muscle: muscle, equipment: equipment, isCustom: true))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
