import Foundation

/// Turns a sentence like "oggi voglio fare petto e tricipiti, 45 minuti" into a routine for today.
/// Works offline with keyword rules, so it behaves the same with or without any AI engine.
enum VoiceWorkoutBuilder {
    struct Result {
        let name: String
        let muscles: [MuscleGroup]
        let minutes: Int
        let exercises: [GeneratedExercise]
        let notes: [String]
    }

    enum BuildError: LocalizedError {
        case noMuscle
        var errorDescription: String? {
            "Non ho capito quali muscoli allenare. Prova con \"oggi petto e tricipiti\" oppure \"gambe e addome, 45 minuti\"."
        }
    }

    private static let order: [MuscleGroup] = [.chest, .back, .quads, .hamstrings, .glutes, .shoulders, .biceps, .triceps, .calves, .core]

    private static let rules: [(words: [String], muscles: [MuscleGroup])] = [
        (["tutto il corpo", "full body", "total body", "corpo intero", "corpo completo"], [.chest, .back, .quads, .shoulders, .core]),
        (["parte alta", "upper", "busto"], [.chest, .back, .shoulders, .biceps, .triceps]),
        (["parte bassa", "lower"], [.quads, .hamstrings, .glutes, .calves]),
        (["push", "spinta", "spingere"], [.chest, .shoulders, .triceps]),
        (["pull", "tirata", "tirare"], [.back, .biceps]),
        (["gambe", "gamba", "leg day"], [.quads, .hamstrings, .glutes, .calves]),
        (["braccia", "braccio"], [.biceps, .triceps]),
        (["petto", "pettoral", "pettorali"], [.chest]),
        (["schiena", "dorsal", "dorso"], [.back]),
        (["spalle", "spalla", "deltoid"], [.shoulders]),
        (["bicipit", "bicipite"], [.biceps]),
        (["tricipit", "tricipite"], [.triceps]),
        (["quadricip", "quadricipiti"], [.quads]),
        (["femoral"], [.hamstrings]),
        (["gluteo", "glutei", "sedere"], [.glutes]),
        (["polpacc"], [.calves]),
        (["addom", "addominali", "pancia", "core"], [.core]),
    ]

    private static func normalize(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "it"))
    }

    static func minutes(in text: String) -> Int {
        let t = normalize(text)
        if t.contains("mezz'ora") || t.contains("mezzora") || t.contains("mezza ora") { return 30 }
        if t.contains("un'ora e mezza") || t.contains("ora e mezza") { return 90 }
        if t.contains("un'ora") || t.contains("un ora") || t.contains("1 ora") { return 60 }
        if let m = t.range(of: #"(\d{2,3})\s*(min|minuti)"#, options: .regularExpression) {
            let digits = t[m].prefix { $0.isNumber }
            if let n = Int(digits) { return min(max(n, 20), 120) }
        }
        return 60
    }

    static func build(from text: String, library: [LibraryEntry]) throws -> Result {
        let t = normalize(text)
        var wanted = Set<MuscleGroup>()
        for rule in rules where rule.words.contains(where: { t.contains($0) }) {
            wanted.formUnion(rule.muscles)
        }
        let muscles = order.filter { wanted.contains($0) }
        guard !muscles.isEmpty else { throw BuildError.noMuscle }

        var notes: [String] = []
        let minutes = minutes(in: text)

        // Equipment: "a casa", "senza attrezzi" -> bodyweight; "manubri" -> dumbbells; otherwise the whole gym.
        var equipment = Set(Equipment.allCases)
        if ["a casa", "senza attrezzi", "corpo libero"].contains(where: { t.contains($0) }) {
            equipment = [.bodyweight]
            if t.contains("manubri") { equipment.insert(.dumbbell) }
            notes.append("Solo attrezzi che hai a casa.")
        } else if t.contains("manubri") && !t.contains("bilanciere") {
            equipment = [.dumbbell, .bodyweight]
            notes.append("Solo manubri e corpo libero.")
        }

        // Injuries only when there is a pain cue, so "alleno le spalle" never excludes shoulders.
        var request = GenerationRequest()
        request.equipment = equipment
        if ["male", "dolore", "infortun", "fastidio", "mi fa", "problema"].contains(where: { t.contains($0) }) {
            request.injuries = t
            if !PlanValidator.excludedKeys(for: t).isEmpty { notes.append("Ho evitato gli esercizi più a rischio per il problema che hai detto.") }
        }
        let hit = ["alta intensita", "poco volume", "heavy duty", "cedimento", "hit "].contains { t.contains($0) }
        if hit { notes.append("Poco volume e alta intensità: poche serie, portate vicino al cedimento.") }
        let light = ["leggero", "stanco", "scarico", "poco tempo", "senza esagerare"].contains { t.contains($0) }
        if light { notes.append("Versione leggera: una serie in meno.") }

        let priority: [Equipment] = [.barbell, .dumbbell, .machine, .cable, .bodyweight, .kettlebell]
        var pools: [MuscleGroup: [LibraryEntry]] = [:]
        for m in muscles {
            pools[m] = library
                .filter { $0.muscle == m && PlanValidator.allowed($0, request) }
                .sorted { (priority.firstIndex(of: $0.equipment) ?? 9, $0.name) < (priority.firstIndex(of: $1.equipment) ?? 9, $1.name) }
        }
        let available = muscles.filter { !(pools[$0] ?? []).isEmpty }
        guard !available.isEmpty else { throw BuildError.noMuscle }

        // About 7 minutes per exercise (3 sets plus rest).
        let slots = hit ? max(available.count, min(5, available.count + 2)) : max(available.count, min(max(minutes / 7, 3), 10))
        var counts = Dictionary(uniqueKeysWithValues: available.map { ($0, 1) })
        var remaining = slots - available.count
        var i = 0
        while remaining > 0 {
            let m = available[i % available.count]
            if counts[m]! < min(4, pools[m]!.count) { counts[m]! += 1; remaining -= 1 }
            i += 1
            if i > 200 { break }
        }

        var exercises: [GeneratedExercise] = []
        for m in available {
            for (index, entry) in pools[m]!.prefix(counts[m]!).enumerated() {
                let compound = index == 0 && ![.core, .calves, .biceps, .triceps].contains(m)
                var sets = hit ? (index == 0 ? 3 : 2) : (compound && minutes >= 60 ? 4 : 3)
                if light { sets = max(sets - 1, 1) }
                let reps = hit ? 8 : (m == .calves || m == .core ? 15 : compound ? 8 : 12)
                exercises.append(GeneratedExercise(key: entry.key, sets: sets, reps: reps, note: ""))
            }
        }
        let label = available.prefix(3).map(\.label).joined(separator: " + ")
        return Result(name: "Oggi: \(label)", muscles: available, minutes: minutes, exercises: exercises, notes: notes)
    }
}
