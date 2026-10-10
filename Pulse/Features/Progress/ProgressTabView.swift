import SwiftUI
import Charts

struct ProgressTabView: View {
    private struct Point: Identifiable {
        let id = UUID()
        let week: Int
        let volume: Double
    }

    private let data: [Point] = zip(1...8, [8200, 8900, 8700, 9600, 10100, 9900, 10800, 11500])
        .map { Point(week: $0, volume: $1) }
    @State private var reveal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume settimanale").font(.headline)
                    Text("+40% in 8 settimane").font(.subheadline).foregroundStyle(Theme.accent)
                    Chart(data) { p in
                        AreaMark(x: .value("Settimana", p.week), y: .value("kg", reveal ? p.volume : 0))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.4), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Settimana", p.week), y: .value("kg", reveal ? p.volume : 0))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...12000)
                    .frame(height: 220)
                }
                .padding(20)
                .card()
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Progressi")
            .onAppear { withAnimation(.smooth(duration: 1.0).delay(0.15)) { reveal = true } }
        }
    }
}
