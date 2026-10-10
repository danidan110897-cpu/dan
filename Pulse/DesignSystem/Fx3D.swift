import SwiftUI
import CoreMotion
import RealityKit
import Observation

/// Device-motion tilt (relative to how the phone is held when the view appears), used for the parallax card effect.
@MainActor @Observable
final class TiltModel {
    var roll = 0.0
    var pitch = 0.0
    private let manager = CMMotionManager()
    private var base: (roll: Double, pitch: Double)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let a = motion?.attitude else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.base == nil { self.base = (a.roll, a.pitch) }
                let b = self.base ?? (0, 0)
                self.roll = max(-0.6, min(0.6, a.roll - b.roll))
                self.pitch = max(-0.6, min(0.6, a.pitch - b.pitch))
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        base = nil
    }
}

private struct Tilt3D: ViewModifier {
    @State private var tilt = TiltModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let r = reduceMotion ? 0 : tilt.roll
        let p = reduceMotion ? 0 : tilt.pitch
        content
            .rotation3DEffect(.degrees(p * 22), axis: (1, 0, 0), perspective: 0.5)
            .rotation3DEffect(.degrees(r * 22), axis: (0, 1, 0), perspective: 0.5)
            .shadow(color: Theme.accent.opacity(0.28), radius: 20, x: r * 30, y: -p * 30)
            .animation(.interactiveSpring, value: tilt.roll)
            .onAppear { tilt.start() }
            .onDisappear { tilt.stop() }
    }
}

extension View {
    /// Card that leans with the phone, like a hologram.
    func tilt3D() -> some View { modifier(Tilt3D()) }
}

/// Digit flip: the old number folds away on a horizontal axis while the new one unfolds.
struct FlipEffect: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0), perspective: 0.6)
            .opacity(abs(angle) > 80 ? 0 : 1)
    }
}

extension AnyTransition {
    static var flip3D: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: FlipEffect(angle: -90), identity: FlipEffect(angle: 0)),
            removal: .modifier(active: FlipEffect(angle: 90), identity: FlipEffect(angle: 0))
        )
    }
}

/// A real 3D gold medal (RealityKit) that spins on its own and can be dragged with a finger.
struct MedalView: View {
    @State private var extra = 0.0
    @State private var base = 0.0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let spin = (t.truncatingRemainder(dividingBy: 7) / 7) * 2 * .pi
            if #available(iOS 18.0, *) {
                MedalScene(angle: Float(spin + extra))
            } else {
                // iOS 17 fallback: a flat medal that turns in 3D.
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.3), Color(red: 0.75, green: 0.5, blue: 0.1)], startPoint: .top, endPoint: .bottom))
                    Circle().fill(Theme.accent).padding(26)
                    Image(systemName: "checkmark").font(.system(size: 60, weight: .heavy)).foregroundStyle(.black)
                }
                .frame(width: 150, height: 150)
                .rotation3DEffect(.radians(spin + extra), axis: (0, 1, 0), perspective: 0.5)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { extra = base + Double($0.translation.width) / 90 }
                .onEnded { _ in base = extra }
        )
        .accessibilityLabel("Medaglia")
    }
}

@available(iOS 18.0, *)
private struct MedalScene: View {
    let angle: Float
    @State private var root = Entity()

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            var gold = PhysicallyBasedMaterial()
            gold.baseColor = .init(tint: UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1))
            gold.metallic = 0.7
            gold.roughness = 0.3
            gold.emissiveColor = .init(color: UIColor(red: 0.55, green: 0.38, blue: 0.05, alpha: 1))
            gold.emissiveIntensity = 0.6

            var lime = PhysicallyBasedMaterial()
            lime.baseColor = .init(tint: UIColor(red: 0.78, green: 1.0, blue: 0.25, alpha: 1))
            lime.metallic = 0.3
            lime.roughness = 0.4
            lime.emissiveColor = .init(color: UIColor(red: 0.4, green: 0.55, blue: 0.1, alpha: 1))
            lime.emissiveIntensity = 0.8

            let face = Transform(rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.1, radius: 0.5), materials: [gold])
            disc.transform = face
            let inner = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 0.36), materials: [lime])
            inner.transform = face
            let core = ModelEntity(mesh: .generateSphere(radius: 0.17), materials: [gold])
            core.position = [0, 0, 0.07]
            core.scale = [1, 1, 0.5]
            root.addChild(disc)
            root.addChild(inner)
            root.addChild(core)
            content.add(root)

            let camera = PerspectiveCamera()
            camera.position = [0, 0, 2.2]
            content.add(camera)

            let light = DirectionalLight()
            light.light.intensity = 4000
            light.look(at: .zero, from: [1, 1.2, 2], relativeTo: nil)
            content.add(light)
        } update: { _ in
            root.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
        }
    }
}
