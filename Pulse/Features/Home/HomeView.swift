import SwiftUI

struct HomeView: View {
    @State private var shown = false
    @State private var showWorkout = false
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let days = ["L", "M", "M", "G", "V", "S", "D"]
    private let done: Set<Int> = [0, 1, 3]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header.entrance(0, shown: shown, reduceMotion: reduceMotion)
                    ringsCard.entrance(1, shown: shown, reduceMotion: reduceMotion)
                    streakCard.entrance(2, shown: shown, reduceMotion: reduceMotion)
                    workoutCard.entrance(3, shown: shown, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutSessionView()
                    .navigationTransition(.zoom(sourceID: "workout", in: zoom))
            }
            .onAppear { shown = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Buongiorno, Dan").font(.subheadline).foregroundStyle(Theme.secondaryText)
            Text("Pronto a spingere?").font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var ringsCard: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: 0.82, color: Theme.move, lineWidth: 16)
                ProgressRing(progress: 0.60, color: Theme.train, lineWidth: 16, delay: 0.15)
                    .padding(22)
                ProgressRing(progress: 0.45, color: Theme.recover, lineWidth: 16, delay: 0.3)
                    .padding(44)
            }
            .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 14) {
                stat("Movimento", "412 kcal", Theme.move)
                stat("Allenamento", "27 min", Theme.train)
                stat("Recupero", "78%", Theme.recover)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .card()
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text("12 giorni di fila").font(.headline)
                Spacer()
            }
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text(days[i]).font(.caption2).foregroundStyle(Theme.secondaryText)
                        Circle()
                            .fill(done.contains(i) ? Theme.accent : Color.white.opacity(0.1))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if done.contains(i) {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black)
                                }
                            }
                            .scaleEffect(shown ? 1 : 0.3)
                            .opacity(shown ? 1 : 0)
                            .animation(reduceMotion ? .none : Motion.bouncy.delay(0.5 + Double(i) * 0.05), value: shown)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .card()
    }

    private var workoutCard: some View {
        Button { showWorkout = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("ALLENAMENTO DI OGGI").font(.caption.weight(.semibold)).foregroundStyle(.black.opacity(0.6))
                Text("Push · Petto e tricipiti").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.black)
                HStack {
                    Label("7 esercizi", systemImage: "dumbbell.fill")
                    Label("55 min", systemImage: "clock")
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").font(.title)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.black.opacity(0.75))
                Text("Recupero al 78%: puoi aumentare il carico del 2,5% sulla panca.")
                    .font(.footnote).foregroundStyle(.black.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .matchedTransitionSource(id: "workout", in: zoom)
        .sensoryFeedback(.impact(weight: .medium), trigger: showWorkout)
    }
}

#Preview { HomeView() }
