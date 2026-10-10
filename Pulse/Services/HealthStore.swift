import Foundation
import HealthKit
import Observation

struct Readiness {
    let score: Int
    let label: String
    let reasons: [String]
    let advice: String
}

/// Reads activity, sleep and recovery data from Apple Health and writes food, weight and (without a Watch) workouts back.
@MainActor @Observable
final class HealthStore {
    static let shared = HealthStore()

    private let store = HKHealthStore()
    private let entryKey = "PulseEntryID"

    var steps = 0.0
    var activeKcal = 0.0
    var sleepHours: Double?
    var hrv: Double?
    var hrvBaseline: Double?
    var restingHR: Double?
    var restingHRBaseline: Double?
    var didRefresh = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var syncEnabled: Bool {
        UserDefaults.standard.object(forKey: "healthSync") as? Bool ?? true
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRateVariabilitySDNN),
         HKQuantityType(.restingHeartRate), HKQuantityType(.bodyMass), HKCategoryType(.sleepAnalysis)]
    }

    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein), HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal), HKQuantityType(.bodyMass), HKObjectType.workoutType()]
    }

    func requestAndRefresh() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        await refresh()
    }

    // MARK: Reading

    func refresh() async {
        guard isAvailable else { return }
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let ms = HKUnit.secondUnit(with: .milli)

        steps = await stat(.stepCount, unit: .count(), sum: true, from: startOfDay, to: now) ?? 0
        activeKcal = await stat(.activeEnergyBurned, unit: .kilocalorie(), sum: true, from: startOfDay, to: now) ?? 0

        let day = { (n: Int) in cal.date(byAdding: .day, value: -n, to: now) ?? now }
        hrv = await stat(.heartRateVariabilitySDNN, unit: ms, sum: false, from: day(1), to: now)
        hrvBaseline = await stat(.heartRateVariabilitySDNN, unit: ms, sum: false, from: day(30), to: now)
        restingHR = await stat(.restingHeartRate, unit: bpm, sum: false, from: day(2), to: now)
        restingHRBaseline = await stat(.restingHeartRate, unit: bpm, sum: false, from: day(30), to: now)
        sleepHours = await lastNightSleep(now: now)
        didRefresh = true
    }

    private func stat(_ id: HKQuantityTypeIdentifier, unit: HKUnit, sum: Bool, from: Date, to: Date) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: sum ? .cumulativeSum : .discreteAverage
        )
        let result = try? await descriptor.result(for: store)
        return sum ? result?.sumQuantity()?.doubleValue(for: unit) : result?.averageQuantity()?.doubleValue(for: unit)
    }

    /// Total time asleep between yesterday 18:00 and now, merging overlapping samples from different devices.
    private func lastNightSleep(now: Date) async -> Double? {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now),
              let from = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return nil }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        var total: TimeInterval = 0
        var cursor = Date.distantPast
        for s in samples where asleepValues.contains(s.value) {
            let start = max(s.startDate, cursor)
            if s.endDate > start {
                total += s.endDate.timeIntervalSince(start)
                cursor = s.endDate
            }
        }
        return total > 0 ? total / 3600 : nil
    }

    // MARK: Readiness

    /// Transparent heuristic: HRV vs your 30-day average (40%), sleep vs 8 h (40%), resting heart rate vs your average (20%).
    var readiness: Readiness? {
        var parts: [(weight: Double, score: Double)] = []
        var reasons: [String] = []

        if let hrv, let base = hrvBaseline, base > 0 {
            let ratio = hrv / base
            parts.append((0.4, min(max(50 + (ratio - 1) * 150, 0), 100)))
            let pct = Int(((ratio - 1) * 100).rounded())
            reasons.append(pct >= 0 ? "HRV \(pct)% sopra la tua media" : "HRV \(-pct)% sotto la tua media")
        }
        if let sleepHours {
            parts.append((0.4, min(max(sleepHours / 8 * 100, 0), 100)))
            reasons.append("Sonno \(sleepHours.formatted(.number.precision(.fractionLength(1)))) h")
        }
        if let restingHR, let base = restingHRBaseline {
            parts.append((0.2, min(max(70 - (restingHR - base) * 10, 0), 100)))
            let diff = Int((restingHR - base).rounded())
            if diff != 0 { reasons.append(diff > 0 ? "Battito a riposo +\(diff) bpm" : "Battito a riposo \(diff) bpm") }
        }
        guard !parts.isEmpty, parts.contains(where: { $0.weight >= 0.4 }) else { return nil }
        let total = parts.reduce(0) { $0 + $1.weight }
        let score = Int((parts.reduce(0) { $0 + $1.weight * $1.score } / total).rounded())

        let label: String
        let advice: String
        switch score {
        case 75...:
            label = "Pronto a spingere"
            advice = "Puoi seguire il piano o provare ad aumentare il carico dove sei vicino al massimo."
        case 50..<75:
            label = "Recupero nella norma"
            advice = "Allenati come da programma."
        default:
            label = "Meglio andare piano"
            advice = "Valuta di ridurre il volume di circa il 20% o di fare una seduta più leggera."
        }
        return Readiness(score: score, label: label, reasons: reasons, advice: advice)
    }

    // MARK: Writing

    func saveNutrition(entryID: String, date: Date, kcal: Double, protein: Double, carbs: Double, fat: Double) async {
        guard isAvailable, syncEnabled else { return }
        let meta: [String: Any] = [entryKey: entryID]
        func sample(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) -> HKQuantitySample {
            HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value),
                             start: date, end: date, metadata: meta)
        }
        let samples = [
            sample(.dietaryEnergyConsumed, .kilocalorie(), kcal),
            sample(.dietaryProtein, .gram(), protein),
            sample(.dietaryCarbohydrates, .gram(), carbs),
            sample(.dietaryFatTotal, .gram(), fat),
        ]
        try? await store.save(samples)
    }

    func deleteNutrition(entryID: String) async {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: entryKey, allowedValues: [entryID])
        for id in [HKQuantityTypeIdentifier.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal] {
            _ = try? await store.deleteObjects(of: HKQuantityType(id), predicate: predicate)
        }
    }

    func saveWeight(_ kg: Double, date: Date = .now) async {
        guard isAvailable, syncEnabled else { return }
        let id = "weight-" + date.formatted(.iso8601.year().month().day())
        let type = HKQuantityType(.bodyMass)
        let predicate = HKQuery.predicateForObjects(withMetadataKey: entryKey, allowedValues: [id])
        _ = try? await store.deleteObjects(of: type, predicate: predicate)
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date, metadata: [entryKey: id])
        try? await store.save(sample)
    }

    /// Used only when no Apple Watch is paired; otherwise the Watch records the workout with heart rate.
    func saveWorkout(start: Date, end: Date) async {
        guard isAvailable, syncEnabled, end > start else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {}
    }
}
