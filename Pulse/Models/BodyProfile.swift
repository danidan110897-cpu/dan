import Foundation
import Observation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "Uomo" : "Donna" }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, high, extreme
    var id: String { rawValue }
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        case .extreme: 1.9
        }
    }
    var label: String {
        switch self {
        case .sedentary: "Sedentario"
        case .light: "Leggero (1-3 allenamenti)"
        case .moderate: "Moderato (3-5 allenamenti)"
        case .high: "Alto (6-7 allenamenti)"
        case .extreme: "Estremo (lavoro fisico + sport)"
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case cut, maintain, bulk
    var id: String { rawValue }
    /// Fraction of maintenance calories added or removed.
    var adjustment: Double {
        switch self {
        case .cut: -0.15
        case .maintain: 0
        case .bulk: 0.10
        }
    }
    var label: String {
        switch self {
        case .cut: "Dimagrire"
        case .maintain: "Mantenere"
        case .bulk: "Mettere massa"
        }
    }
}

enum BodyType: String, Codable, CaseIterable, Identifiable {
    case ectomorph, mesomorph, endomorph
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ectomorph: "Ectomorfo (magro, fatica a salire)"
        case .mesomorph: "Mesomorfo (atletico)"
        case .endomorph: "Endomorfo (tende ad accumulare)"
        }
    }
    /// Informal hint only: it does not change any calculation.
    var tip: String {
        switch self {
        case .ectomorph: "Di solito serve mangiare con regolarità per salire: non saltare i pasti."
        case .mesomorph: "Di solito rispondi bene a volume e carichi crescenti."
        case .endomorph: "Di solito aiutano passi giornalieri e proteine alte per restare sazio."
        }
    }
}

struct BodyProfile: Codable, Equatable {
    var sex: Sex = .male
    var age = 28
    var heightCm = 178.0
    var weightKg = 75.0
    var waistCm: Double?
    var neckCm: Double?
    var hipCm: Double?
    var activity: ActivityLevel = .moderate
    var goal: Goal = .maintain
    var bodyType: BodyType = .mesomorph
}

struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var kg: Double
}

/// Pure calculations from a profile. All values are estimates, not medical advice.
struct BodyAnalysis {
    let p: BodyProfile

    private var heightM: Double { p.heightCm / 100 }

    var bmi: Double { p.weightKg / (heightM * heightM) }

    var bmiCategory: String {
        switch bmi {
        case ..<18.5: "Sottopeso"
        case ..<25: "Normopeso"
        case ..<30: "Sovrappeso"
        default: "Obesità"
        }
    }

    /// Mifflin-St Jeor.
    var bmr: Double {
        10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age) + (p.sex == .male ? 5 : -161)
    }

    var tdee: Double { bmr * p.activity.factor }
    var targetCalories: Double { tdee * (1 + p.goal.adjustment) }

    /// US Navy circumference method when measurements allow it, otherwise Deurenberg from BMI.
    var bodyFat: (percent: Double, method: String) {
        if let waist = p.waistCm, let neck = p.neckCm {
            if p.sex == .male, waist > neck {
                let v = 495 / (1.0324 - 0.19077 * log10(waist - neck) + 0.15456 * log10(p.heightCm)) - 450
                return (clamp(v), "Misure (metodo US Navy)")
            }
            if p.sex == .female, let hip = p.hipCm, waist + hip > neck {
                let v = 495 / (1.29579 - 0.35004 * log10(waist + hip - neck) + 0.22100 * log10(p.heightCm)) - 450
                return (clamp(v), "Misure (metodo US Navy)")
            }
        }
        let v = 1.20 * bmi + 0.23 * Double(p.age) - 10.8 * (p.sex == .male ? 1 : 0) - 5.4
        return (clamp(v), "Stima da BMI (meno precisa)")
    }

    var fatMassKg: Double { p.weightKg * bodyFat.percent / 100 }
    var leanMassKg: Double { p.weightKg - fatMassKg }

    var bodyFatLabel: String {
        let f = bodyFat.percent
        let limits: [Double] = p.sex == .male ? [6, 14, 18, 25] : [14, 21, 25, 32]
        switch f {
        case ..<limits[0]: return "Essenziale"
        case ..<limits[1]: return "Atletico"
        case ..<limits[2]: return "Fitness"
        case ..<limits[3]: return "Nella media"
        default: return "Alto"
        }
    }

    var idealWeightRange: ClosedRange<Double> { (18.5 * heightM * heightM)...(24.9 * heightM * heightM) }

    var proteinG: Double { p.weightKg * (p.goal == .cut ? 2.2 : 1.8) }
    var fatG: Double { max(p.weightKg * 0.9, 40) }
    var carbsG: Double { max((targetCalories - proteinG * 4 - fatG * 9) / 4, 0) }
    var waterLiters: Double { p.weightKg * 0.035 }

    /// Waist-to-height ratio: above 0.5 is commonly flagged as higher risk.
    var waistToHeight: Double? { p.waistCm.map { $0 / p.heightCm } }

    private func clamp(_ v: Double) -> Double { min(max(v, 3), 60) }
}

@MainActor @Observable
final class ProfileStore {
    var profile: BodyProfile { didSet { save() } }
    var weights: [WeightEntry] { didSet { save() } }

    private let key = "pulse.body.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            profile = saved.profile
            weights = saved.weights
        } else {
            profile = BodyProfile()
            weights = []
        }
    }

    var analysis: BodyAnalysis { BodyAnalysis(p: profile) }

    /// One entry per day: logging again the same day replaces it.
    func logWeight(_ kg: Double, on date: Date = .now) {
        weights.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        weights.append(WeightEntry(date: date, kg: kg))
        weights.sort { $0.date < $1.date }
        profile.weightKg = kg
    }

    private struct Saved: Codable {
        var profile: BodyProfile
        var weights: [WeightEntry]
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Saved(profile: profile, weights: weights)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
