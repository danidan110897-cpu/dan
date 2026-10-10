import SwiftUI
import SwiftData

struct AIRoutineView: View {
    let onSaved: (Routine) -> Void

    enum Engine: String, CaseIterable, Identifiable {
        case auto = "Automatico"
        case rules = "Regole (offline)"
        case apple = "Apple Intelligence"
        case claude = "Claude"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var request = GenerationRequest()
    @State private var engine: Engine = .auto
    @State private var loading = false
    @State private var error: String?
    @State private var plan: GeneratedPlan?
    @State private var info: String?

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
                if let info {
                    Text(info).font(.footnote).foregroundStyle(.orange)
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
        case .auto: "Userà: \(AIEngine.automatic.label). Se l'AI non risponde passa alle regole sul telefono."
        case .rules: "Schemi classici (Push/Pull/Gambe, Upper/Lower, Corpo intero). Non usa AI né internet."
        case .apple: AIEngine.appleStatus.isAvailable
            ? "Gira sul telefono: gratis e privato."
            : "Non disponibile: \(AIEngine.appleStatus.label)."
        case .claude: "Usa la tua chiave API (Impostazioni): quella gratuita di Google Gemini va bene, Anthropic costa pochi centesimi a bozza."
        }
    }

    private func name(of key: String) -> String {
        exercises.first { $0.key == key }?.name ?? key
    }

    private func generate() {
        error = nil
        info = nil
        loading = true
        let req = request
        let lib = library
        let choice: AIEngine.Choice = switch engine {
        case .auto: AIEngine.automatic
        case .rules: .local
        case .apple: .apple
        case .claude: .claude
        }
        let allowFallback = engine == .auto
        Task {
            do {
                let outcome = try await RoutinePlanner.generate(req, library: lib, choice: choice, allowFallback: allowFallback)
                if let reason = outcome.fallbackReason { info = "L'AI non ha risposto (\(reason)): ho usato le regole sul telefono." }
                withAnimation(Motion.smooth) { plan = outcome.plan }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func save(_ plan: GeneratedPlan) {
        let first = RoutinePlanner.save(plan, restSeconds: request.goal == .strength ? 150 : 90, exercises: exercises, context: context)
        dismiss()
        if let first { onSaved(first) }
    }
}
