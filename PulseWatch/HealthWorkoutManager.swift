import Foundation
import HealthKit
import Observation

/// Runs a real HKWorkoutSession so the Watch keeps sensors on, streams heart
/// rate, and saves the strength workout to Health when finished.
@MainActor @Observable
final class HealthWorkoutManager: NSObject {
    var heartRate = 0.0
    var activeEnergy = 0.0
    var isRunning = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start() async {
        guard !isRunning, HKHealthStore.isHealthDataAvailable() else { return }
        let hr = HKQuantityType(.heartRate)
        let energy = HKQuantityType(.activeEnergyBurned)
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [hr, energy])

            let config = HKWorkoutConfiguration()
            config.activityType = .traditionalStrengthTraining
            config.locationType = .indoor

            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func finish() async {
        guard isRunning else { return }
        session?.end()
        do {
            try await builder?.endCollection(at: Date())
            _ = try await builder?.finishWorkout()
        } catch {}
        isRunning = false
    }
}

extension HealthWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension HealthWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var bpm: Double?
        var kcal: Double?
        for type in collectedTypes {
            guard let q = type as? HKQuantityType, let stats = workoutBuilder.statistics(for: q) else { continue }
            switch q.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                bpm = stats.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
            default: break
            }
        }
        Task { @MainActor in
            if let bpm { self.heartRate = bpm }
            if let kcal { self.activeEnergy = kcal }
        }
    }
}
