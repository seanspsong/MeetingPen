import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var transcribedText = ""
    @Published var transcribedSentences: [String] = []
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var currentLocale: String = "en-US"
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale))
        speechRecognizer?.delegate = self
        // Request authorization early to avoid first-run failures
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.authorizationStatus = authStatus
                print("🎙️ Speech recognition authorization: \(authStatus.rawValue)")
            }
        }
    }
    
    func configureLanguage(_ locale: String) {
        guard locale != currentLocale else { return }
        
        // Stop any existing transcription
        if isTranscribing {
            stopTranscribing()
        }
        
        currentLocale = locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        speechRecognizer?.delegate = self
        
        print("🎙️ Speech recognizer configured for locale: \(locale)")
    }
    
    func startTranscribing() {
        // Check authorization status first
        guard authorizationStatus == .authorized else {
            print("❌ Speech recognition not authorized: \(authorizationStatus.rawValue)")
            if authorizationStatus == .notDetermined {
                requestAuthorization()
            }
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        // Stop any existing task
        stopTranscribing()
        
        // Add a small delay to ensure audio session is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performTranscription()
        }
    }
    
    private func performTranscription() {
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
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        let newText = result.bestTranscription.formattedString
                        self?.transcribedText = newText
                        self?.parseSentences(from: newText)
                        print("🎙️ Transcribed: \(newText)")
                    }
                    
                    if error != nil || result?.isFinal == true {
                        print("🎙️ Recognition task completed")
                        if error != nil {
                            print("❌ Recognition error: \(error!.localizedDescription)")
                        }
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
        transcribedSentences = []
    }
    
    private func parseSentences(from text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Simply use the full text as the current content, replacing everything
        // This prevents duplicates and confusion from partial sentence parsing
        
        // Split into natural sentence boundaries
        let sentences = trimmedText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 5 } // Filter very short fragments
        
        // Clear and rebuild the sentences array to avoid duplicates
        let newSentences = sentences.filter { sentence in
            // Only include sentences that are meaningful
            return sentence.count > 5 && sentence.split(separator: " ").count > 2
        }
        
        // Only update if we have new content
        if newSentences != transcribedSentences {
            transcribedSentences = newSentences
        }
        
        // Handle ongoing incomplete sentence
        if !trimmedText.hasSuffix(".") && !trimmedText.hasSuffix("!") && !trimmedText.hasSuffix("?") {
            let incompleteSentence = trimmedText.components(separatedBy: CharacterSet(charactersIn: ".!?")).last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if !incompleteSentence.isEmpty && incompleteSentence.count > 5 {
                // Add or update the incomplete sentence
                if transcribedSentences.isEmpty || !transcribedSentences.contains(incompleteSentence) {
                    transcribedSentences.append(incompleteSentence)
                } else {
                    // Update the last sentence if it's similar but longer
                    if let lastIndex = transcribedSentences.lastIndex(where: { incompleteSentence.hasPrefix($0) || $0.hasPrefix(incompleteSentence) }) {
                        transcribedSentences[lastIndex] = incompleteSentence
                    }
                }
            }
        }
        
        print("🎙️ Sentences: \(transcribedSentences.count)")
    }
    
    // Save transcription to meeting
    func saveTranscription(to meetingStore: MeetingStore, meetingId: UUID) {
        guard !transcribedText.isEmpty else { return }
        
        if let meeting = meetingStore.meetings.first(where: { $0.id == meetingId }) {
            // Save the sentence-by-sentence breakdown as the transcript
            let formattedTranscript = transcribedSentences.enumerated()
                .map { "[\($0.offset + 1)] \($0.element)" }
                .joined(separator: "\n")
            
            var updatedMeeting = meeting
            updatedMeeting.transcriptData.fullText = formattedTranscript.isEmpty ? transcribedText : formattedTranscript
            
            // Use updateMeeting to ensure persistence
            meetingStore.updateMeeting(updatedMeeting)
            
            print("💾 Saved transcription to meeting: \(transcribedSentences.count) sentences")
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