import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(sort: \WorkoutLog.date) private var logs: [WorkoutLog]
    @State private var selectedKey: String?
    @State private var reveal = false

    private struct WeekPoint: Identifiable {
        let id = UUID()
        let week: Date
        let volume: Double
    }

    private struct OneRMPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private struct Best: Identifiable {
        let id = UUID()
        let name: String
        let weight: Double
        let reps: Int
        let oneRM: Double
    }

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private var weeklyVolume: [WeekPoint] {
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<8).reversed().map { back in
            let start = cal.date(byAdding: .day, value: -7 * back, to: thisWeek)!
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            let vol = logs.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.volume }
            return WeekPoint(week: start, volume: reveal ? vol : 0)
        }
    }

    private var exerciseOptions: [(key: String, name: String)] {
        var seen: [String: String] = [:]
        for log in logs { for e in log.entries { seen[e.exerciseKey] = e.exerciseName } }
        return seen.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }

    private var currentKey: String? { selectedKey ?? exerciseOptions.first?.key }

    private var oneRMSeries: [OneRMPoint] {
        guard let key = currentKey else { return [] }
        return logs.compactMap { log in
            let best = log.entries.filter { $0.exerciseKey == key }.flatMap(\.sets).map(\.estimatedOneRM).max()
            return best.map { OneRMPoint(date: log.date, value: reveal ? $0 : 0) }
        }
    }

    private var bests: [Best] {
        var map: [String: Best] = [:]
        for log in logs {
            for e in log.entries {
                for s in e.sets where s.estimatedOneRM > (map[e.exerciseKey]?.oneRM ?? 0) {
                    map[e.exerciseKey] = Best(name: e.exerciseName, weight: s.weight, reps: s.reps, oneRM: s.estimatedOneRM)
                }
            }
        }
        return map.values.sorted { $0.oneRM > $1.oneRM }.prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if logs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 44)).foregroundStyle(Theme.accent)
                            .symbolEffect(.pulse)
                        Text("Qui vedrai i tuoi progressi").font(.headline)
                        Text("Completa il primo allenamento e compariranno volume, record e forza stimata.")
                            .font(.footnote).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    VStack(spacing: 16) {
                        totals
                        volumeCard
                        oneRMCard
                        bestsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Progressi")
            .onAppear { withAnimation(.smooth(duration: 1.0).delay(0.15)) { reveal = true } }
        }
    }

    private var totals: some View {
        HStack {
            total("Allenamenti", "\(logs.count)")
            total("Volume totale", "\(Int(logs.reduce(0) { $0 + $1.volume } / 1000)) t")
            total("Tempo", "\(logs.reduce(0) { $0 + $1.durationSeconds } / 3600) h")
        }
        .padding(16)
        .card()
    }

    private func total(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume settimanale (kg)").font(.headline)
            Chart(weeklyVolume) { p in
                BarMark(x: .value("Settimana", p.week, unit: .weekOfYear), y: .value("kg", p.volume))
                    .foregroundStyle(Theme.accent.gradient)
                    .cornerRadius(6)
            }
            .frame(height: 180)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var oneRMCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Forza stimata (1RM)").font(.headline)
                Spacer()
                Picker("Esercizio", selection: Binding(get: { currentKey ?? "" }, set: { selectedKey = $0 })) {
                    ForEach(exerciseOptions, id: \.key) { Text($0.name).tag($0.key) }
                }
                .pickerStyle(.menu)
            }
            Chart(oneRMSeries) { p in
                LineMark(x: .value("Data", p.date), y: .value("kg", p.value))
                    .foregroundStyle(Theme.move).interpolationMethod(.catmullRom)
                PointMark(x: .value("Data", p.date), y: .value("kg", p.value)).foregroundStyle(Theme.move)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            Text("Stima con la formula di Epley: peso × (1 + ripetizioni / 30).")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .card()
    }

    private var bestsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Record personali").font(.headline)
            ForEach(bests) { b in
                HStack {
                    Text(b.name).font(.subheadline)
                    Spacer()
                    Text("\(formatWeight(b.weight)) kg × \(b.reps)").font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
