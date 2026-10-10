import Foundation
import Speech
import AVFoundation
import Observation

/// Live Italian dictation. Uses on-device recognition when the phone supports it, so the audio stays on the iPhone.
@MainActor @Observable
final class SpeechRecorder {
    var transcript = ""
    var isRecording = false
    var error: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))

    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    func start() async {
        error = nil
        guard await authorize() else {
            error = "Serve il permesso per microfono e riconoscimento vocale (Impostazioni > Pulse)."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "Il riconoscimento vocale italiano non è disponibile ora. Scrivi la richiesta a mano."
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            Self.installTap(on: engine.inputNode, request: request)
            engine.prepare()
            try engine.start()

            transcript = ""
            task = recognizer.recognitionTask(with: request) { [weak self] result, err in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                Task { @MainActor in
                    if let text { self?.transcript = text }
                    if err != nil || final { self?.stop() }
                }
            }
            isRecording = true
        } catch {
            self.error = "Microfono non disponibile: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        guard isRecording || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap callback runs on the audio thread.
    private nonisolated static func installTap(on node: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    private func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
