import Foundation

/// Weekly planning helpers. Routines carry the weekdays they are scheduled on (Calendar numbering: 1 = Sunday ... 7 = Saturday).
enum TrainingSchedule {
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    /// Spread `count` routines over the week with rest days in between.
    static func defaultWeekdays(count: Int) -> [Int] {
        switch count {
        case ...1: return [4]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 6, 7]
        default: return [2, 3, 4, 5, 6, 7]
        }
    }

    static func routines(on date: Date, from routines: [Routine]) -> [Routine] {
        let weekday = calendar.component(.weekday, from: date)
        return routines.filter { $0.weekdays.contains(weekday) && !$0.items.isEmpty }
    }

    static func log(for routine: Routine, on date: Date, logs: [WorkoutLog]) -> WorkoutLog? {
        logs.first { $0.name == routine.name && calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Monday to Sunday of the week containing `date`.
    static func week(containing date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// The next scheduled session after `date` (looking up to a week ahead).
    static func next(after date: Date, routines: [Routine]) -> (date: Date, routine: Routine)? {
        let today = calendar.startOfDay(for: date)
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let r = Self.routines(on: day, from: routines).first { return (day, r) }
        }
        return nil
    }

    /// A routine that was scheduled yesterday and not done (so it can be offered for today).
    static func missedYesterday(routines: [Routine], logs: [WorkoutLog], now: Date = .now) -> Routine? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        return Self.routines(on: yesterday, from: routines).first { log(for: $0, on: yesterday, logs: logs) == nil }
    }
}
