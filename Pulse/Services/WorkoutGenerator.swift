import Foundation

// MARK: - Request / result types

enum TrainingGoal: String, CaseIterable, Identifiable, Codable {
    case strength, hypertrophy, fatLoss, general
    var id: String { rawValue }
    var label: String {
        switch self {
        case .strength: "Forza"
        case .hypertrophy: "Massa muscolare"
        case .fatLoss: "Dimagrimento"
        case .general: "Forma generale"
        }
    }
}

enum TrainingLevel: String, CaseIterable, Identifiable, Codable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var label: String {
        switch self {
        case .beginner: "Principiante"
        case .intermediate: "Intermedio"
        case .advanced: "Avanzato"
        }
    }
}

enum TrainingStyle: String, CaseIterable, Identifiable, Codable {
    case standard, highIntensity
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: "Classico"
        case .highIntensity: "Poco volume, alta intensità"
        }
    }
}

struct GenerationRequest {
    var style: TrainingStyle = .standard
    var goal: TrainingGoal = .hypertrophy
    var level: TrainingLevel = .intermediate
    var daysPerWeek = 3
    var minutes = 60
    var equipment: Set<Equipment> = Set(Equipment.allCases)
    var focus = ""
    var injuries = ""
}

struct LibraryEntry: Hashable {
    let key: String
    let name: String
    let muscle: MuscleGroup
    let equipment: Equipment
}

struct GeneratedExercise: Identifiable, Hashable {
    let id = UUID()
    var key: String
    var sets: Int
    var reps: Int
    var note: String
}

struct GeneratedRoutine: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var exercises: [GeneratedExercise]
}

struct GeneratedPlan {
    var routines: [GeneratedRoutine]
    var rationale: String
    var warnings: [String] = []
}

enum GeneratorError: LocalizedError {
    case unavailable(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let m), .badResponse(let m): m
        }
    }
}

protocol WorkoutGenerator {
    func generate(_ request: GenerationRequest, library: [LibraryEntry]) async throws -> GeneratedPlan
}

// MARK: - Safety layer (applies to every engine, including the AI ones)

enum PlanValidator {
    /// Exercise keys to avoid for the injuries described in free text (Italian keywords).
    static func excludedKeys(for injuries: String) -> Set<String> {
        let t = injuries.lowercased()
        var out = Set<String>()
        if t.contains("spall") {
            out.formUnion(["ohp", "db_shoulder_press", "dips", "bench_dip", "incline_bench", "pushup", "lateral_raise", "cable_lateral"])
        }
        if t.contains("schiena") || t.contains("lomb") || t.contains("ernia") {
            out.formUnion(["deadlift", "barbell_row", "rdl", "back_ext", "good_morning", "squat", "front_squat", "kb_swing", "hip_thrust"])
        }
        if t.contains("ginocch") {
            out.formUnion(["lunge", "bulgarian", "leg_ext", "jump_rope", "burpee", "hack_squat", "front_squat", "squat", "goblet"])
        }
        if t.contains("polsi") || t.contains("polso") {
            out.formUnion(["barbell_curl", "pushup", "front_squat", "ab_wheel", "plank"])
        }
        if t.contains("gomit") {
            out.formUnion(["skullcrusher", "close_grip_bench", "preacher_curl", "dips", "bench_dip"])
        }
        return out
    }

    static func allowed(_ e: LibraryEntry, _ r: GenerationRequest) -> Bool {
        (r.equipment.contains(e.equipment) || e.equipment == .bodyweight) && !excludedKeys(for: r.injuries).contains(e.key)
    }

    /// Drops unknown, unavailable or unsafe exercises and clamps volume. Always returns a plan; changes are reported in `warnings`.
    static func validate(_ plan: GeneratedPlan, request: GenerationRequest, library: [LibraryEntry]) -> GeneratedPlan {
        let byKey = Dictionary(uniqueKeysWithValues: library.map { ($0.key, $0) })
        var warnings = plan.warnings
        var routines: [GeneratedRoutine] = []

        for var routine in plan.routines.prefix(request.daysPerWeek) {
            var seen = Set<String>()
            var kept: [GeneratedExercise] = []
            for var ex in routine.exercises {
                guard let entry = byKey[ex.key] else {
                    warnings.append("Scartato «\(ex.key)»: non esiste nella libreria.")
                    continue
                }
                guard allowed(entry, request) else {
                    warnings.append("Scartato «\(entry.name)»: attrezzo non disponibile o sconsigliato per i tuoi infortuni.")
                    continue
                }
                guard seen.insert(ex.key).inserted else { continue }
                var sets = min(max(ex.sets, 1), request.level == .beginner ? 4 : 6)
                var reps = min(max(ex.reps, 1), 30)
                if request.style == .highIntensity {
                    // Few hard sets close to failure: 3 for the first lift, 2 for the rest, 6-10 reps.
                    sets = min(sets, kept.isEmpty ? 3 : 2)
                    reps = min(max(reps, 6), 10)
                }
                if sets != ex.sets || reps != ex.reps { warnings.append("Volume corretto per «\(entry.name)».") }
                ex.sets = sets
                ex.reps = reps
                kept.append(ex)
            }
            let maxExercises = request.style == .highIntensity ? 5 : (request.level == .beginner ? 7 : 10)
            if kept.count > maxExercises { kept = Array(kept.prefix(maxExercises)); warnings.append("Troppi esercizi in «\(routine.name)»: ridotti a \(maxExercises).") }
            let maxSets = request.level == .beginner ? 20 : 30
            var total = 0
            kept = kept.filter { total += $0.sets; return total <= maxSets }
            if kept.count < 2 { warnings.append("«\(routine.name)» ha pochi esercizi: controllala prima di usarla.") }
            routine.exercises = kept
            routines.append(routine)
        }
        var unique: [String] = []
        for w in warnings where !unique.contains(w) { unique.append(w) }
        return GeneratedPlan(routines: routines, rationale: plan.rationale, warnings: unique)
    }
}

// MARK: - Deterministic generator (always available, works offline)

struct RuleBasedGenerator: WorkoutGenerator {
    private struct Slot {
        let muscle: MuscleGroup
        let prefer: [String]
        let compound: Bool
    }

    private static let push: [Slot] = [
        Slot(muscle: .chest, prefer: ["bench_press", "db_bench", "chest_press", "pushup"], compound: true),
        Slot(muscle: .shoulders, prefer: ["ohp", "db_shoulder_press"], compound: true),
        Slot(muscle: .chest, prefer: ["incline_db", "incline_bench", "cable_fly", "pec_deck"], compound: false),
        Slot(muscle: .triceps, prefer: ["pushdown", "skullcrusher", "overhead_ext"], compound: false),
        Slot(muscle: .shoulders, prefer: ["lateral_raise", "cable_lateral"], compound: false),
        Slot(muscle: .triceps, prefer: ["overhead_ext", "pushdown", "bench_dip"], compound: false),
    ]
    private static let pull: [Slot] = [
        Slot(muscle: .back, prefer: ["pullup", "lat_pulldown"], compound: true),
        Slot(muscle: .back, prefer: ["barbell_row", "db_row", "seated_row"], compound: true),
        Slot(muscle: .back, prefer: ["seated_row", "db_row", "lat_pulldown"], compound: false),
        Slot(muscle: .shoulders, prefer: ["rear_delt_fly", "face_pull"], compound: false),
        Slot(muscle: .biceps, prefer: ["barbell_curl", "db_curl", "cable_curl"], compound: false),
        Slot(muscle: .biceps, prefer: ["hammer_curl", "preacher_curl", "db_curl"], compound: false),
    ]
    private static let legs: [Slot] = [
        Slot(muscle: .quads, prefer: ["squat", "leg_press", "goblet", "hack_squat"], compound: true),
        Slot(muscle: .hamstrings, prefer: ["rdl", "db_rdl", "leg_curl"], compound: true),
        Slot(muscle: .quads, prefer: ["leg_press", "lunge", "bulgarian"], compound: false),
        Slot(muscle: .hamstrings, prefer: ["leg_curl", "db_rdl"], compound: false),
        Slot(muscle: .glutes, prefer: ["hip_thrust", "glute_bridge"], compound: false),
        Slot(muscle: .calves, prefer: ["standing_calf", "seated_calf"], compound: false),
        Slot(muscle: .core, prefer: ["plank", "cable_crunch", "crunch"], compound: false),
    ]
    private static let upper: [Slot] = [
        Slot(muscle: .chest, prefer: ["bench_press", "db_bench", "chest_press"], compound: true),
        Slot(muscle: .back, prefer: ["barbell_row", "db_row", "seated_row"], compound: true),
        Slot(muscle: .shoulders, prefer: ["ohp", "db_shoulder_press"], compound: true),
        Slot(muscle: .back, prefer: ["lat_pulldown", "pullup"], compound: false),
        Slot(muscle: .biceps, prefer: ["db_curl", "barbell_curl", "cable_curl"], compound: false),
        Slot(muscle: .triceps, prefer: ["pushdown", "overhead_ext", "skullcrusher"], compound: false),
    ]
    private static let lower: [Slot] = [
        Slot(muscle: .quads, prefer: ["squat", "leg_press", "goblet"], compound: true),
        Slot(muscle: .hamstrings, prefer: ["rdl", "db_rdl", "leg_curl"], compound: true),
        Slot(muscle: .glutes, prefer: ["hip_thrust", "glute_bridge", "lunge"], compound: false),
        Slot(muscle: .quads, prefer: ["lunge", "leg_ext", "bulgarian"], compound: false),
        Slot(muscle: .calves, prefer: ["standing_calf", "seated_calf"], compound: false),
        Slot(muscle: .core, prefer: ["plank", "hanging_leg", "cable_crunch"], compound: false),
    ]
    private static let fullA: [Slot] = [
        Slot(muscle: .quads, prefer: ["squat", "leg_press", "goblet"], compound: true),
        Slot(muscle: .chest, prefer: ["bench_press", "db_bench", "pushup"], compound: true),
        Slot(muscle: .back, prefer: ["barbell_row", "db_row", "seated_row"], compound: true),
        Slot(muscle: .hamstrings, prefer: ["rdl", "db_rdl", "leg_curl"], compound: false),
        Slot(muscle: .shoulders, prefer: ["lateral_raise", "db_shoulder_press"], compound: false),
        Slot(muscle: .core, prefer: ["plank", "crunch"], compound: false),
    ]
    private static let fullB: [Slot] = [
        Slot(muscle: .quads, prefer: ["leg_press", "lunge", "goblet"], compound: true),
        Slot(muscle: .shoulders, prefer: ["ohp", "db_shoulder_press"], compound: true),
        Slot(muscle: .back, prefer: ["lat_pulldown", "pullup", "db_row"], compound: true),
        Slot(muscle: .glutes, prefer: ["hip_thrust", "glute_bridge"], compound: false),
        Slot(muscle: .chest, prefer: ["incline_db", "chest_press", "pushup"], compound: false),
        Slot(muscle: .biceps, prefer: ["db_curl", "hammer_curl"], compound: false),
    ]
    private static let fullC: [Slot] = [
        Slot(muscle: .hamstrings, prefer: ["rdl", "db_rdl", "leg_curl"], compound: true),
        Slot(muscle: .chest, prefer: ["incline_db", "incline_bench", "db_bench"], compound: true),
        Slot(muscle: .back, prefer: ["seated_row", "db_row", "lat_pulldown"], compound: true),
        Slot(muscle: .quads, prefer: ["lunge", "leg_press", "bulgarian"], compound: false),
        Slot(muscle: .triceps, prefer: ["pushdown", "overhead_ext"], compound: false),
        Slot(muscle: .core, prefer: ["cable_crunch", "hanging_leg", "plank"], compound: false),
    ]

    private func split(_ r: GenerationRequest) -> [(String, [Slot])] {
        switch r.daysPerWeek {
        case ...1: return [("Corpo intero", Self.fullA)]
        case 2: return [("Corpo intero A", Self.fullA), ("Corpo intero B", Self.fullB)]
        case 3:
            if r.level == .beginner { return [("Corpo intero A", Self.fullA), ("Corpo intero B", Self.fullB), ("Corpo intero C", Self.fullC)] }
            return [("Push", Self.push), ("Pull", Self.pull), ("Gambe", Self.legs)]
        case 4: return [("Upper A", Self.upper), ("Lower A", Self.lower), ("Upper B", Self.upper), ("Lower B", Self.lower)]
        case 5: return [("Push", Self.push), ("Pull", Self.pull), ("Gambe", Self.legs), ("Upper", Self.upper), ("Lower", Self.lower)]
        default: return [("Push A", Self.push), ("Pull A", Self.pull), ("Gambe A", Self.legs),
                         ("Push B", Self.push), ("Pull B", Self.pull), ("Gambe B", Self.legs)]
        }
    }

    func generate(_ request: GenerationRequest, library: [LibraryEntry]) async throws -> GeneratedPlan {
        let usable = library.filter { PlanValidator.allowed($0, request) }
        let count = min(max(request.minutes / 10, 4), 8)
        var seenTemplates: [String: Int] = [:]
        var routines: [GeneratedRoutine] = []

        for (i, (name, slots)) in split(request).enumerated() {
            let baseName = name.replacingOccurrences(of: " A", with: "").replacingOccurrences(of: " B", with: "")
            let variant = seenTemplates[baseName, default: 0]
            seenTemplates[baseName] = variant + 1

            var used = Set<String>()
            var items: [GeneratedExercise] = []
            for slot in slots.prefix(count) {
                let candidates = slot.prefer.compactMap { k in usable.first { $0.key == k } }.filter { !used.contains($0.key) }
                let entry = candidates.isEmpty
                    ? usable.first { $0.muscle == slot.muscle && !used.contains($0.key) }
                    : candidates[variant % candidates.count]
                guard let entry else { continue }
                used.insert(entry.key)
                let (sets, reps) = volume(slot.compound, request)
                items.append(GeneratedExercise(key: entry.key, sets: sets, reps: reps, note: ""))
            }
            routines.append(GeneratedRoutine(name: "Giorno \(i + 1) · \(name)", exercises: items))
        }

        var rationale = "Schema a \(request.daysPerWeek) giorni per \(request.level.label.lowercased()): "
        rationale += request.goal == .strength
            ? "pochi esercizi multiarticolari con serie pesanti da 4-6 ripetizioni, accessori da 8."
            : request.goal == .hypertrophy
            ? "multiarticolari da 6-10 ripetizioni e accessori da 10-15, ogni muscolo allenato più volte a settimana quando possibile."
            : "ripetizioni più alte (12-15) e recuperi brevi, con esercizi che coinvolgono più muscoli."
        if !request.focus.trimmingCharacters(in: .whitespaces).isEmpty {
            rationale += " Il campo «priorità» viene usato solo dai motori AI."
        }
        return GeneratedPlan(routines: routines, rationale: rationale)
    }

    private func volume(_ compound: Bool, _ r: GenerationRequest) -> (Int, Int) {
        var sets: Int
        var reps: Int
        switch r.goal {
        case .strength: (sets, reps) = compound ? (4, 5) : (3, 8)
        case .hypertrophy: (sets, reps) = compound ? (4, 8) : (3, 12)
        case .fatLoss, .general: (sets, reps) = compound ? (3, 10) : (3, 12)
        }
        if r.level == .beginner { sets = max(2, sets - 1) }
        if r.level == .advanced && compound { sets += 1 }
        return (sets, reps)
    }
}

// MARK: - Shared prompt

enum GeneratorPrompt {
    static let system = """
    Sei un allenatore di forza prudente e concreto. Crei routine di allenamento per una persona adulta in salute.
    Regole:
    - Usa SOLO le chiavi degli esercizi presenti nella libreria che ti viene fornita. Non inventare esercizi.
    - Rispetta attrezzatura disponibile, livello, durata e infortuni indicati.
    - Ordina gli esercizi dal più impegnativo (multiarticolari) agli accessori.
    - Serie tra 2 e 5, ripetizioni tra 3 e 20 (fino a 30 solo per addome o polpacci).
    - Nel campo rationale spiega in 3-5 frasi in italiano perché hai scelto questa struttura.
    - Non dare consigli medici. Se qualcosa richiede un medico, dillo in una frase nel rationale.
    """

    static func user(_ r: GenerationRequest, library: [LibraryEntry]) -> String {
        let lib = library.map { "\($0.key) | \($0.name) | \($0.muscle.label) | \($0.equipment.label)" }.joined(separator: "\n")
        return """
        Richiesta:
        - Obiettivo: \(r.goal.label)
        - Livello: \(r.level.label)
        - Stile: \(r.style == .highIntensity ? "poco volume e alta intensità: 4-5 esercizi per allenamento, 2-3 serie ciascuno, 6-10 ripetizioni, serie portate vicino al cedimento" : "classico")
        - Giorni a settimana: \(r.daysPerWeek) (crea esattamente \(r.daysPerWeek) routine)
        - Durata per allenamento: \(r.minutes) minuti
        - Attrezzatura: \(r.equipment.map(\.label).sorted().joined(separator: ", "))
        - Priorità / note: \(r.focus.isEmpty ? "nessuna" : r.focus)
        - Infortuni o limiti: \(r.injuries.isEmpty ? "nessuno" : r.injuries)

        Libreria (chiave | nome | muscolo | attrezzo):
        \(lib)
        """
    }
}
