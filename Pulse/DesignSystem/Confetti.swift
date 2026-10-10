import SwiftUI

/// One-shot particle burst, used for personal records.
struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let angle = Double.random(in: 0..<(2 * .pi))
        let distance = CGFloat.random(in: 70...180)
        let size = CGFloat.random(in: 5...10)
        let color = [Theme.accent, Theme.move, Theme.recover, .white].randomElement()!
        let spin = Double.random(in: -360...360)
    }

    @State private var pieces = (0..<28).map { _ in Piece() }
    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(fired ? p.spin : 0))
                    .offset(x: fired ? cos(p.angle) * p.distance : 0,
                            y: fired ? sin(p.angle) * p.distance + 40 : 0)
                    .opacity(fired ? 0 : 1)
                    .scaleEffect(fired ? 0.6 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { fired = true } }
    }
}
