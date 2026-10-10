import SwiftUI
import SwiftData

struct AIRoutineView: View {
    let onSaved: (Routine) -> Void

    enum Engine: String, CaseIterable, Identifiable {
        case rules = "Regole (offline)"
        case apple = "Apple Intelligence"
        case claude = "Claude"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var request = GenerationRequest()
    @State private var engine: Engine = .rules
    @State private var loading = false
    @State private var error: String?
    @State private var plan: GeneratedPlan?

    private var library: [LibraryEntry] {
        exercises.map { LibraryEntry(key: $0.key, name: $0.name, muscle: $0.muscle, equipment: $0.equipment) }
    }

    var body: some View {
        List {
            Section("Obiettivo") {
                Picker("Obiettivo", selection: $request.goal) {
                    ForEach(TrainingGoal.allCases) { Text($0.label).tag($0) }
                }
                Picker("Livello", selection: $request.level) {
                    ForEach(TrainingLevel.allCases) { Text($0.label).tag($0) }
                }
                Stepper("Giorni a settimana: \(request.daysPerWeek)", value: $request.daysPerWeek, in: 1...6)
                Picker("Durata", selection: $request.minutes) {
                    ForEach([30, 45, 60, 75, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .listRowBackground(Theme.card)

            Section("Attrezzatura disponibile") {
                ForEach(Equipment.allCases) { eq in
                    Toggle(eq.label, isOn: Binding(
                        get: { request.equipment.contains(eq) },
                        set: { on in if on { request.equipment.insert(eq) } else { request.equipment.remove(eq) } }
                    ))
                }
            }
            .listRowBackground(Theme.card)

            Section {
                TextField("Priorità (es. spalle più larghe)", text: $request.focus)
                TextField("Infortuni o limiti (es. dolore alla spalla)", text: $request.injuries)
            } header: {
                Text("Note")
            } footer: {
                Text("Parole come spalla, schiena, ginocchio, polso e gomito escludono gli esercizi più a rischio, con qualsiasi motore.")
            }
            .listRowBackground(Theme.card)

            Section {
                Picker("Motore", selection: $engine) {
                    ForEach(Engine.allCases) { Text($0.rawValue).tag($0) }
                }
                Button {
                    generate()
                } label: {
                    HStack {
                        if loading { ProgressView() } else { Image(systemName: "sparkles") }
                        Text(loading ? "Sto creando…" : "Crea la bozza")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
                .disabled(loading || request.equipment.isEmpty)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(Theme.move)
                }
            } footer: {
                Text(engineHint)
            }
            .listRowBackground(Theme.card)

            if let plan {
                Section("Bozza") {
                    if !plan.rationale.isEmpty {
                        Text(plan.rationale).font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                    ForEach(plan.routines) { routine in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(routine.name).font(.headline)
                            ForEach(routine.exercises) { ex in
                                HStack {
                                    Text(name(of: ex.key)).font(.subheadline)
                                    Spacer()
                                    Text("\(ex.sets) × \(ex.reps)").font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    ForEach(plan.warnings, id: \.self) { w in
                        Label(w, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                    }
                    Text("È una bozza generata automaticamente, non un consiglio medico: controllala e modificala prima di usarla.")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                    Button("Salva \(plan.routines.count) routine", systemImage: "square.and.arrow.down") { save(plan) }
                        .sensoryFeedback(.success, trigger: plan.routines.count)
                }
                .listRowBackground(Theme.card)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Crea con l'AI")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.smooth, value: plan?.routines.count)
    }

    private var engineHint: String {
        switch engine {
        case .rules: "Schemi classici (Push/Pull/Gambe, Upper/Lower, Corpo intero). Non usa AI né internet."
        case .apple: AppleGenerator.isAvailable
            ? "Gira sul telefono: gratis e privato."
            : "Non disponibile su questo iPhone (serve iOS 26 e Apple Intelligence attiva)."
        case .claude: "Usa la tua chiave API di Anthropic (Impostazioni). Costa pochi centesimi a bozza."
        }
    }

    private func makeGenerator() -> any WorkoutGenerator {
        switch engine {
        case .rules: return RuleBasedGenerator()
        case .apple: return AppleGenerator()
        case .claude: return ClaudeGenerator()
        }
    }

    private func name(of key: String) -> String {
        exercises.first { $0.key == key }?.name ?? key
    }

    private func generate() {
        error = nil
        loading = true
        let req = request
        let lib = library
        let generator = makeGenerator()
        Task {
            do {
                let raw = try await generator.generate(req, library: lib)
                let checked = PlanValidator.validate(raw, request: req, library: lib)
                withAnimation(Motion.smooth) { plan = checked }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func save(_ plan: GeneratedPlan) {
        var first: Routine?
        for r in plan.routines {
            let routine = Routine(name: r.name, restSeconds: request.goal == .strength ? 150 : 90)
            context.insert(routine)
            for (i, g) in r.exercises.enumerated() {
                guard let ex = exercises.first(where: { $0.key == g.key }) else { continue }
                let item = RoutineItem(order: i, exercise: ex, sets: g.sets, reps: g.reps)
                item.note = g.note
                routine.items.append(item)
            }
            if first == nil { first = routine }
        }
        try? context.save()
        dismiss()
        if let first { onSaved(first) }
    }
}
