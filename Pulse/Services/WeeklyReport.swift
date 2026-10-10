import Foundation

/// Weekly summary computed only from the user's own data (last 7 days vs the 7 before). No AI involved.
struct WeeklyReport {
    var workouts = 0
    var prevWorkouts = 0
    var volume = 0.0
    var prevVolume = 0.0
    var prCount = 0
    var daysLogged = 0
    var avgKcal: Double?
    var avgProtein: Double?
    var targetKcal = 0.0
    var targetProtein = 0.0
    var weightChange: Double?
    var waistChange: Double?
    var highlights: [String] = []
    var tips: [String] = []

    var volumeChangePercent: Double? {
        prevVolume > 0 ? (volume - prevVolume) / prevVolume * 100 : nil
    }

    static func make(logs: [WorkoutLog], foods: [FoodEntry], weights: [WeightEntry], analysis: BodyAnalysis, now: Date = .now) -> WeeklyReport {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let prevStart = cal.date(byAdding: .day, value: -14, to: now) ?? now

        var r = WeeklyReport()
        r.targetKcal = analysis.targetCalories
        r.targetProtein = analysis.proteinG

        let thisWeek = logs.filter { $0.date >= start && $0.date <= now }
        let lastWeek = logs.filter { $0.date >= prevStart && $0.date < start }
        r.workouts = thisWeek.count
        r.prevWorkouts = lastWeek.count
        r.volume = thisWeek.reduce(0) { $0 + $1.volume }
        r.prevVolume = lastWeek.reduce(0) { $0 + $1.volume }
        r.prCount = thisWeek.flatMap(\.entries).flatMap(\.sets).filter(\.isPR).count

        let week = foods.filter { $0.date >= start && $0.date <= now }
        let days = Set(week.map { cal.startOfDay(for: $0.date) })
        r.daysLogged = days.count
        if !days.isEmpty {
            r.avgKcal = week.reduce(0) { $0 + $1.kcal } / Double(days.count)
            r.avgProtein = week.reduce(0) { $0 + $1.protein } / Double(days.count)
        }

        let sorted = weights.sorted { $0.date < $1.date }
        if let latest = sorted.last(where: { $0.date >= start }), let before = sorted.last(where: { $0.date < start }) {
            r.weightChange = latest.kg - before.kg
        }
        let waists = sorted.filter { $0.waistCm != nil }
        if let latest = waists.last(where: { $0.date >= start }), let before = waists.last(where: { $0.date < start }),
           let a = latest.waistCm, let b = before.waistCm {
            r.waistChange = a - b
        }

        r.buildMessages(goalLabel: analysis.p.goal.label)
        return r
    }

    private mutating func buildMessages(goalLabel: String) {
        if workouts > 0 { highlights.append("\(workouts) allenamenti completati") }
        if prCount > 0 { highlights.append("\(prCount) record personali") }
        if let change = volumeChangePercent, change >= 5 {
            highlights.append("Volume +\(Int(change.rounded()))% rispetto alla settimana scorsa")
        }
        if let w = weightChange, abs(w) >= 0.1 {
            highlights.append("Peso \(w > 0 ? "+" : "")\(String(format: "%.1f", w)) kg")
        }
        if let c = waistChange, abs(c) >= 0.5 {
            highlights.append("Vita \(c > 0 ? "+" : "")\(String(format: "%.1f", c)) cm")
        }

        if workouts == 0 {
            tips.append("Questa settimana non hai registrato allenamenti. Anche una seduta breve conta: scegli la routine più corta e parti da lì.")
        } else if workouts < prevWorkouts {
            tips.append("Hai fatto meno allenamenti della settimana scorsa (\(workouts) contro \(prevWorkouts)). Se è stato un periodo pieno, va bene: prova a bloccare in anticipo i giorni della prossima.")
        }
        if let change = volumeChangePercent, change <= -25, workouts > 0 {
            tips.append("Il volume è sceso di circa il \(Int(abs(change).rounded()))%. Se non era una scarica voluta, controlla recupero e sonno.")
        }
        if daysLogged < 3 {
            tips.append("Hai registrato il cibo solo \(daysLogged) giorni su 7: servono almeno 3-4 giorni per un quadro affidabile.")
        } else {
            if let p = avgProtein, targetProtein > 0, p < targetProtein * 0.85 {
                tips.append("Proteine medie \(Int(p)) g contro un obiettivo di \(Int(targetProtein)) g: prova ad aggiungere una fonte proteica a pranzo o a cena.")
            }
            if let k = avgKcal, targetKcal > 0 {
                if k > targetKcal * 1.15 {
                    tips.append("Calorie medie \(Int(k)) contro un obiettivo di \(Int(targetKcal)) (\(goalLabel.lowercased())): controlla porzioni e condimenti, oppure aggiorna l'obiettivo nel tab Corpo.")
                } else if k < targetKcal * 0.8 {
                    tips.append("Calorie medie \(Int(k)) contro un obiettivo di \(Int(targetKcal)): se non stai mangiando così poco, potresti aver dimenticato di registrare qualche pasto.")
                }
            }
        }
        if let w = weightChange, abs(w) >= 1 {
            tips.append("Il peso può variare di 1-2 kg in pochi giorni per acqua e sale: guarda la media di 2-3 settimane prima di trarre conclusioni.")
        }
    }

    /// Compact JSON of the numbers above, used as context when the user asks for an AI analysis.
    var statsJSON: String {
        var d: [String: Any] = [
            "allenamenti_questa_settimana": workouts,
            "allenamenti_settimana_precedente": prevWorkouts,
            "volume_kg": Int(volume),
            "volume_settimana_precedente_kg": Int(prevVolume),
            "record_personali": prCount,
            "giorni_con_cibo_registrato": daysLogged,
            "obiettivo_kcal": Int(targetKcal),
            "obiettivo_proteine_g": Int(targetProtein),
        ]
        if let avgKcal { d["kcal_medie"] = Int(avgKcal) }
        if let avgProtein { d["proteine_medie_g"] = Int(avgProtein) }
        if let weightChange { d["variazione_peso_kg"] = (weightChange * 10).rounded() / 10 }
        if let waistChange { d["variazione_vita_cm"] = (waistChange * 10).rounded() / 10 }
        let data = try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
