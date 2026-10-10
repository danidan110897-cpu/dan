import SwiftUI

struct WatchWorkoutView: View {
    let store: WatchStore
    let health: HealthWorkoutManager

    var body: some View {
        NavigationStack {
            Group {
                if store.snapshot == nil {
                    waiting
                } else if store.isFinished {
                    finished
                } else if let cur = store.current {
                    TabView {
                        setPage(cur.exercise, cur.set, cur.index)
                        heartPage
                    }
                    .tabViewStyle(.verticalPage)
                }
            }
            .animation(.snappy, value: store.isFinished)
        }
        .sensoryFeedback(.success, trigger: store.completionTick)
        .task { await health.start() }
    }

    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward").font(.largeTitle).foregroundStyle(WatchTheme.accent)
                .symbolEffect(.pulse)
            Text("Apri un allenamento su iPhone").font(.footnote).multilineTextAlignment(.center)
        }
    }

    private var finished: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(WatchTheme.accent)
                .symbolEffect(.bounce)
            Text("Allenamento finito").font(.headline)
            Button("Salva") { Task { await health.finish() } }.tint(WatchTheme.accent)
        }
    }

    private func setPage(_ ex: WorkoutSnapshot.Exercise, _ set: WorkoutSnapshot.WorkoutSet, _ index: Int) -> some View {
        ZStack {
            VStack(spacing: 6) {
                Text(ex.name).font(.headline).lineLimit(1)
                Text("Serie \(index) di \(ex.sets.count)").font(.caption2).foregroundStyle(.secondary)
                Text("\(set.weight.formatted()) kg × \(set.reps)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                Button { store.complete(ex, set) } label: {
                    Image(systemName: "checkmark").font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.accent)
                .foregroundStyle(.black)
            }
            .opacity(store.restRemaining > 0 ? 0.15 : 1)

            if store.restRemaining > 0 { restOverlay.transition(.scale.combined(with: .opacity)) }
        }
        .animation(.bouncy, value: store.restRemaining > 0)
        .id(set.id)
        .transition(.push(from: .trailing))
    }

    private var restOverlay: some View {
        Button { store.skipRest() } label: {
            ZStack {
                Circle().stroke(WatchTheme.rest.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(store.restRemaining) / CGFloat(max(store.restTotal, 1)))
                    .stroke(WatchTheme.rest, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: store.restRemaining)
                VStack(spacing: 0) {
                    Text("\(store.restRemaining)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: store.restRemaining)
                    Text("tocca per saltare").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
    }

    private var heartPage: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill").font(.title).foregroundStyle(WatchTheme.heart)
                .symbolEffect(.pulse, isActive: health.heartRate > 0)
            Text(health.heartRate > 0 ? "\(Int(health.heartRate))" : "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: health.heartRate)
            Text("BPM").font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(health.activeEnergy)) kcal  ·  \(store.doneCount)/\(store.totalCount) serie")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
