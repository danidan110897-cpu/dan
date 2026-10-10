import SwiftData

/// Built-in exercise library. Keys are stable: routines and history refer to them.
enum ExerciseSeed {
    private typealias Row = (key: String, name: String, muscle: MuscleGroup, equipment: Equipment)

    private static let rows: [Row] = [
        // Petto
        ("bench_press", "Panca piana con bilanciere", .chest, .barbell),
        ("incline_bench", "Panca inclinata con bilanciere", .chest, .barbell),
        ("db_bench", "Panca piana con manubri", .chest, .dumbbell),
        ("incline_db", "Panca inclinata con manubri", .chest, .dumbbell),
        ("chest_press", "Chest press", .chest, .machine),
        ("cable_fly", "Croci ai cavi", .chest, .cable),
        ("pec_deck", "Pec deck", .chest, .machine),
        ("pushup", "Flessioni", .chest, .bodyweight),
        ("dips", "Dip alle parallele", .chest, .bodyweight),
        // Schiena
        ("deadlift", "Stacco da terra", .back, .barbell),
        ("pullup", "Trazioni alla sbarra", .back, .bodyweight),
        ("lat_pulldown", "Lat machine", .back, .cable),
        ("barbell_row", "Rematore con bilanciere", .back, .barbell),
        ("db_row", "Rematore con manubrio", .back, .dumbbell),
        ("seated_row", "Pulley basso", .back, .cable),
        ("face_pull", "Face pull", .back, .cable),
        ("back_ext", "Iperestensioni", .back, .bodyweight),
        // Spalle
        ("ohp", "Military press con bilanciere", .shoulders, .barbell),
        ("db_shoulder_press", "Shoulder press con manubri", .shoulders, .dumbbell),
        ("lateral_raise", "Alzate laterali", .shoulders, .dumbbell),
        ("cable_lateral", "Alzate laterali ai cavi", .shoulders, .cable),
        ("rear_delt_fly", "Alzate posteriori", .shoulders, .dumbbell),
        ("shrug", "Scrollate", .shoulders, .dumbbell),
        // Bicipiti
        ("barbell_curl", "Curl con bilanciere", .biceps, .barbell),
        ("db_curl", "Curl con manubri", .biceps, .dumbbell),
        ("hammer_curl", "Hammer curl", .biceps, .dumbbell),
        ("preacher_curl", "Curl alla panca Scott", .biceps, .barbell),
        ("cable_curl", "Curl ai cavi", .biceps, .cable),
        // Tricipiti
        ("pushdown", "Pushdown ai cavi", .triceps, .cable),
        ("skullcrusher", "French press", .triceps, .barbell),
        ("overhead_ext", "Estensioni sopra la testa", .triceps, .dumbbell),
        ("close_grip_bench", "Panca presa stretta", .triceps, .barbell),
        ("bench_dip", "Dip su panca", .triceps, .bodyweight),
        // Quadricipiti
        ("squat", "Squat con bilanciere", .quads, .barbell),
        ("front_squat", "Front squat", .quads, .barbell),
        ("leg_press", "Leg press", .quads, .machine),
        ("leg_ext", "Leg extension", .quads, .machine),
        ("lunge", "Affondi con manubri", .quads, .dumbbell),
        ("bulgarian", "Squat bulgaro", .quads, .dumbbell),
        ("goblet", "Goblet squat", .quads, .kettlebell),
        ("hack_squat", "Hack squat", .quads, .machine),
        // Femorali
        ("rdl", "Stacco rumeno", .hamstrings, .barbell),
        ("db_rdl", "Stacco rumeno con manubri", .hamstrings, .dumbbell),
        ("leg_curl", "Leg curl", .hamstrings, .machine),
        // Glutei
        ("hip_thrust", "Hip thrust", .glutes, .barbell),
        ("glute_bridge", "Ponte glutei", .glutes, .bodyweight),
        ("cable_kickback", "Kickback ai cavi", .glutes, .cable),
        ("abductor", "Abduttori", .glutes, .machine),
        // Polpacci
        ("standing_calf", "Calf in piedi", .calves, .machine),
        ("seated_calf", "Calf da seduto", .calves, .machine),
        // Addome
        ("plank", "Plank", .core, .bodyweight),
        ("crunch", "Crunch", .core, .bodyweight),
        ("hanging_leg", "Sollevamento gambe alla sbarra", .core, .bodyweight),
        ("cable_crunch", "Crunch ai cavi", .core, .cable),
        ("russian_twist", "Russian twist", .core, .bodyweight),
        ("ab_wheel", "Ab wheel", .core, .bodyweight),
        // Corpo intero
        ("kb_swing", "Kettlebell swing", .fullBody, .kettlebell),
        ("burpee", "Burpee", .fullBody, .bodyweight),
        ("farmer_walk", "Farmer walk", .fullBody, .dumbbell),
        // Cardio
        ("treadmill", "Tapis roulant", .cardio, .machine),
        ("bike", "Cyclette", .cardio, .machine),
        ("row_erg", "Vogatore", .cardio, .machine),
        ("jump_rope", "Corda per saltare", .cardio, .bodyweight),
    ]

    static var keys: Set<String> { Set(rows.map(\.key)) }

    /// Inserts any built-in exercise that is not in the store yet (safe to call on every launch).
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = Set(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map(\.key))
        for r in rows where !existing.contains(r.key) {
            context.insert(Exercise(key: r.key, name: r.name, muscle: r.muscle, equipment: r.equipment))
        }
        try? context.save()
    }
}
