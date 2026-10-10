import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 14
    var delay: Double = 0

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown ? min(progress, 1) : 0)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.6), color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: shown ? 8 : 0)
        }
        .onAppear {
            if reduceMotion { shown = true; return }
            withAnimation(.smooth(duration: 1.1).delay(delay)) { shown = true }
        }
    }
}

#Preview {
    ProgressRing(progress: 0.7, color: Theme.train).frame(width: 120, height: 120).padding().background(Theme.background)
}
