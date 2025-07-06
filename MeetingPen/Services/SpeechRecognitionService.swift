import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var transcribedText = ""
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        // Don't request authorization immediately to avoid crashes
        // It will be requested when transcription starts
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.authorizationStatus = authStatus
                print("🎙️ Speech recognition authorization: \(authStatus.rawValue)")
            }
        }
    }
    
    func startTranscribing() {
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }
        
        guard authorizationStatus == .authorized else {
            print("❌ Speech recognition not authorized")
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        // Stop any existing task
        stopTranscribing()
        
        // Configure audio session for recording (compatible with existing recording)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Failed to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.transcribedText = result.bestTranscription.formattedString
                        print("🎙️ Transcribed: \(result.bestTranscription.formattedString)")
                    }
                    
                    if error != nil || result?.isFinal == true {
                        print("🎙️ Recognition task completed")
                        self?.stopTranscribing()
                    }
                }
            }
            
            isTranscribing = true
            print("🎙️ Started live transcription")
            
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            stopTranscribing()
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isTranscribing = false
        print("🎙️ Stopped live transcription")
    }
    
    func clearTranscription() {
        transcribedText = ""
    }
    
    // Save transcription to meeting
    func saveTranscription(to meetingStore: MeetingStore, meetingId: UUID) {
        guard !transcribedText.isEmpty else { return }
        
        if let meetingIndex = meetingStore.meetings.firstIndex(where: { $0.id == meetingId }) {
            meetingStore.meetings[meetingIndex].transcript = transcribedText
            print("💾 Saved transcription to meeting: \(transcribedText.prefix(50))...")
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("🎙️ Speech recognizer availability changed: \(available)")
        
        if !available {
            DispatchQueue.main.async {
                self.stopTranscribing()
            }
        }
    }
} 