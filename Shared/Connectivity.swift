import Foundation
import WatchConnectivity

/// Two-way link between iPhone and Watch. The latest snapshot travels as
/// application context (always delivered, latest wins); set toggles travel as
/// live messages, falling back to a queued transfer when the peer is asleep.
final class Connectivity: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = Connectivity()

    /// Set by each side. Always called on the main queue.
    var onSnapshot: ((WorkoutSnapshot) -> Void)?
    var onToggle: ((SetToggle) -> Void)?
    /// The Watch (or phone) pressed the main button of the guided flow.
    var onAction: (() -> Void)?

    private override init() { super.init() }

    #if os(iOS)
    var hasWatch: Bool {
        WCSession.isSupported() && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }
    #endif

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(snapshot: WorkoutSnapshot) {
        guard WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([WatchKey.snapshot: data])
    }

    func send(toggle: SetToggle) {
        guard WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(toggle) else { return }
        let payload = [WatchKey.toggle: data]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func sendAction() {
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = [WatchKey.action: Date().timeIntervalSince1970]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // A snapshot sent before the peer launched is waiting in receivedApplicationContext.
        handle(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) { handle(context) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    private func handle(_ payload: [String: Any]) {
        let decoder = JSONDecoder()
        if let data = payload[WatchKey.snapshot] as? Data,
           let snapshot = try? decoder.decode(WorkoutSnapshot.self, from: data) {
            DispatchQueue.main.async { self.onSnapshot?(snapshot) }
        }
        if payload[WatchKey.action] != nil {
            DispatchQueue.main.async { self.onAction?() }
        }
        if let data = payload[WatchKey.toggle] as? Data,
           let toggle = try? decoder.decode(SetToggle.self, from: data) {
            DispatchQueue.main.async { self.onToggle?(toggle) }
        }
    }
}
