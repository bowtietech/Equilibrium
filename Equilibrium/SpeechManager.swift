import Foundation
import Speech
import AVFoundation
import SwiftUI

// MARK: - SpeechManager
//
// Wraps SFSpeechRecognizer + AVAudioEngine for real-time transcription.
// Works on both iOS and watchOS (platform-conditional session setup).

@MainActor
final class SpeechManager: NSObject, ObservableObject {

    @Published var isListening     = false
    @Published var liveTranscript  = ""
    @Published var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer:        SFSpeechRecognizer?
    private var audioEngine        = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?

    /// Called with the final transcript when recording ends naturally (isFinal).
    var onFinalTranscript: ((String) -> Void)?

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: .current)
        recognizer?.delegate = self
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Authorization

    func requestPermissions() async {
        authStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { cont.resume(returning: status) }
            }
        }
        #if !os(watchOS)
        await AVAudioApplication.requestRecordPermission()
        #endif
    }

    // MARK: - Recording

    func startRecording() async {
        if authStatus != .authorized { await requestPermissions() }
        guard authStatus == .authorized else { return }
        guard let recognizer, recognizer.isAvailable else { return }

        if audioEngine.isRunning { stopRecording() }

        liveTranscript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            #if os(watchOS)
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
            #else
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let req = recognitionRequest else { return }
            req.shouldReportPartialResults = true
            req.taskHint = .dictation

            recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    Task { @MainActor in self.liveTranscript = text }
                    if result.isFinal {
                        Task { @MainActor in
                            self.onFinalTranscript?(text)
                            self.stopRecording()
                        }
                    }
                }
                if let error {
                    let nsErr = error as NSError
                    // 203 = "no speech detected" — not a real error, just silence
                    if nsErr.domain != "kAFAssistantErrorDomain" || nsErr.code != 203 {
                        Task { @MainActor in self.stopRecording() }
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
                self?.recognitionRequest?.append(buf)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

        } catch {
            stopRecording()
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false,
             options: .notifyOthersOnDeactivation)
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                                       availabilityDidChange available: Bool) {}
}
