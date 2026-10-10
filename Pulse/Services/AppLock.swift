import SwiftUI
import LocalAuthentication

/// Optional lock: when enabled, the app asks for Face ID / passcode every time it opens or returns from the background.
@MainActor @Observable
final class AppLock {
    var isLocked = false

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "appLock") }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false   // no passcode set on the phone: nothing to ask
            return
        }
        let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sblocca Pulse")) ?? false
        if ok { withAnimation(Motion.smooth) { isLocked = false } }
    }
}

struct LockOverlay: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 54)).foregroundStyle(Theme.accent)
                    .symbolEffect(.pulse)
                Text("Pulse è bloccata").font(.title2.weight(.bold))
                Button("Sblocca") { Task { await lock.unlock() } }
                    .buttonStyle(.borderedProminent).foregroundStyle(.black)
            }
        }
        .transition(.opacity)
    }
}
