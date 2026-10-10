import Testing
import Foundation
@testable import Pulse

struct BodyAnalysisTests {
    private func profile(sex: Sex = .male, age: Int = 30, height: Double = 180, weight: Double = 80) -> BodyProfile {
        var p = BodyProfile()
        p.sex = sex
        p.age = age
        p.heightCm = height
        p.weightKg = weight
        return p
    }

    @Test func bmiAndBasalMetabolism() {
        let a = BodyAnalysis(p: profile())
        #expect(abs(a.bmi - 24.69) < 0.05)
        #expect(a.bmr == 1780)
    }

    @Test func femaleBasalMetabolismUsesDifferentConstant() {
        let male = BodyAnalysis(p: profile(sex: .male)).bmr
        let female = BodyAnalysis(p: profile(sex: .female)).bmr
        #expect(male - female == 166)
    }

    @Test func navyBodyFatFromMeasurements() {
        var p = profile()
        p.waistCm = 85
        p.neckCm = 38
        let fat = BodyAnalysis(p: p).bodyFat
        #expect(abs(fat.percent - 16.1) < 0.6)
        #expect(fat.method.contains("Navy"))
    }

    @Test func bodyFatFallsBackToBMIEstimate() {
        let fat = BodyAnalysis(p: profile()).bodyFat
        #expect(fat.method.contains("BMI"))
        #expect(fat.percent > 3 && fat.percent < 60)
    }

    @Test func goalChangesTargetCalories() {
        var cut = profile(); cut.goal = .cut
        var bulk = profile(); bulk.goal = .bulk
        #expect(BodyAnalysis(p: cut).targetCalories < BodyAnalysis(p: bulk).targetCalories)
    }

    @Test func macrosNeverNegative() {
        var p = profile(weight: 120); p.goal = .cut
        let a = BodyAnalysis(p: p)
        #expect(a.carbsG >= 0 && a.proteinG > 0 && a.fatG > 0)
    }
}

struct GeneratorTests {
    private let library = ExerciseSeed.libraryEntries

    @Test func validatorDropsUnknownExercisesAndClampsVolume() {
        let request = GenerationRequest()
        let plan = GeneratedPlan(
            routines: [GeneratedRoutine(name: "Test", exercises: [
                GeneratedExercise(key: "does_not_exist", sets: 3, reps: 10, note: ""),
                GeneratedExercise(key: "bench_press", sets: 99, reps: 200, note: ""),
                GeneratedExercise(key: "squat", sets: 3, reps: 8, note: ""),
            ])],
            rationale: ""
        )
        let checked = PlanValidator.validate(plan, request: request, library: library)
        let exercises = checked.routines[0].exercises
        #expect(exercises.map(\.key) == ["bench_press", "squat"])
        #expect(exercises[0].sets <= 6 && exercises[0].reps <= 30)
        #expect(!checked.warnings.isEmpty)
    }

    @Test func validatorRespectsInjuriesAndEquipment() {
        var request = GenerationRequest()
        request.injuries = "dolore alla spalla"
        request.equipment = [.dumbbell]
        let plan = GeneratedPlan(
            routines: [GeneratedRoutine(name: "Test", exercises: [
                GeneratedExercise(key: "ohp", sets: 3, reps: 8, note: ""),
                GeneratedExercise(key: "bench_press", sets: 3, reps: 8, note: ""),
                GeneratedExercise(key: "db_curl", sets: 3, reps: 10, note: ""),
                GeneratedExercise(key: "pushup", sets: 3, reps: 10, note: ""),
            ])],
            rationale: ""
        )
        let kept = PlanValidator.validate(plan, request: request, library: library).routines[0].exercises.map(\.key)
        #expect(kept == ["db_curl"])
    }

    @Test func ruleBasedPlanMatchesDaysAndOnlyUsesSafeLibraryExercises() async throws {
        var request = GenerationRequest()
        request.daysPerWeek = 4
        request.injuries = "male alle ginocchia"
        let plan = try await RuleBasedGenerator().generate(request, library: library)
        #expect(plan.routines.count == 4)
        let keys = Set(library.map(\.key))
        let excluded = PlanValidator.excludedKeys(for: request.injuries)
        for routine in plan.routines {
            #expect(!routine.exercises.isEmpty)
            for ex in routine.exercises {
                #expect(keys.contains(ex.key))
                #expect(!excluded.contains(ex.key))
            }
        }
    }

    @Test func everyDayCountProducesRoutines() async throws {
        for days in 1...6 {
            var request = GenerationRequest()
            request.daysPerWeek = days
            let plan = try await RuleBasedGenerator().generate(request, library: library)
            #expect(plan.routines.count == days)
        }
    }
}

struct FoodTests {
    @Test func portionScaling() {
        let food = FoodResult(key: "t", name: "Riso", kcal100: 350, protein100: 7, carbs100: 78, fat100: 0.6, source: "test")
        let v = food.scaled(200)
        #expect(v.kcal == 700 && v.protein == 14)
    }

    @Test func italianWordsAreTranslatedForUSDA() {
        #expect(FoodAPI.translate("Pollo") == "chicken")
        #expect(FoodAPI.translate("qualcosa di strano") == "qualcosa di strano")
    }
}
