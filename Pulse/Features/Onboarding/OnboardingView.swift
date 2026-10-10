import SwiftUI

/// First-launch flow: welcome, your data, goal. Finishing it stores the profile and asks for Health access.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var store
    let onFinish: () -> Void

    @State private var page = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                basics(store: $store.profile).tag(1)
                goal(store: $store.profile).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Motion.smooth, value: page)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Color.white.opacity(0.2))
                        .frame(width: i == page ? 24 : 8, height: 8)
                        .animation(Motion.bouncy, value: page)
                }
            }
            .padding(.bottom, 16)

            Button {
                if page < 2 { page += 1 } else { onFinish() }
            } label: {
                Text(page < 2 ? "Continua" : "Inizia")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .sensoryFeedback(.selection, trigger: page)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 80)).foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .none : Motion.bouncy, value: appeared)
            Text("Pulse").font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Allenamenti, cibo e recupero in un posto solo.\nI tuoi dati restano sul tuo telefono.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func basics(store: Binding<BodyProfile>) -> some View {
        VStack(spacing: 16) {
            Text("Parlaci di te").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 40)
            Text("Servono per stimare calorie e composizione corporea.")
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            Form {
                Picker("Sesso", selection: store.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper("Età: \(store.wrappedValue.age)", value: store.age, in: 14...90)
                Stepper("Altezza: \(Int(store.wrappedValue.heightCm)) cm", value: store.heightCm, in: 120...230)
                Stepper("Peso: \(store.wrappedValue.weightKg.formatted(.number.precision(.fractionLength(1)))) kg",
                        value: store.weightKg, in: 35...250, step: 0.5)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func goal(store: Binding<BodyProfile>) -> some View {
        VStack(spacing: 16) {
            Text("Il tuo obiettivo").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 40)
            Form {
                Picker("Obiettivo", selection: store.goal) {
                    ForEach(Goal.allCases) { Text($0.label).tag($0) }
                }
                Picker("Attività", selection: store.activity) {
                    ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                }
                Picker("Corporatura", selection: store.bodyType) {
                    ForEach(BodyType.allCases) { Text($0.label).tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            Text("Potrai cambiare tutto dal tab Corpo. Alla fine ti chiederemo l'accesso a Salute.")
                .font(.footnote).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
