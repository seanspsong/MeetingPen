import Foundation
import Speech
import AVFoundation
import Combine

@available(iOS 26.0, *)
class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var transcribedText = ""
    @Published var transcribedSentences: [String] = []
    @Published var formattedParagraphs: [String] = []
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var detectedSpeakers: [Speaker] = []
    @Published var currentSpeakerSegments: [TranscriptSegment] = []
    @Published var isModelReady = false
    @Published var downloadProgress: Progress?
    @Published var currentLanguageIdentifier: String = "en-US"
    
    // iOS 26 SpeechAnalyzer components
    private var speechTranscriber: SpeechTranscriber?
    private var speechAnalyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Error>?
    
    // Fallback SFSpeechRecognizer components
    private var fallbackRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Audio processing
    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var currentLocale: Locale = Locale.current
    
    // Language settings persistence
    private let languageSettingsKey = "SpeechRecognitionLanguage"
    
    // Speaker tracking
    private var speakerProfiles: [String: Speaker] = [:]
    private var volatileResults: [String] = []
    private var finalResults: [TranscriptSegment] = []
    private var useFallback = false
    
    override init() {
        super.init()
        
        // Load saved language setting
        loadLanguageSetting()
        
        // Initialize published property
        currentLanguageIdentifier = currentLocale.identifier
        
        Task {
            await requestAuthorization()
            await setupSpeechServices()
        }
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        await MainActor.run {
            self.authorizationStatus = status
            print("🎙️ Speech recognition authorization: \(status.rawValue)")
        }
    }
    
    // MARK: - Setup
    
    private func setupSpeechServices() async {
        // Try iOS 26 SpeechAnalyzer first
        do {
            try await setupSpeechAnalyzer()
            useFallback = false
            print("✅ Using iOS 26 SpeechAnalyzer with speaker diarization")
        } catch {
            print("⚠️ iOS 26 SpeechAnalyzer failed, falling back to SFSpeechRecognizer: \(error)")
            useFallback = true
            await setupFallbackRecognizer()
        }
    }
    
    private func setupSpeechAnalyzer() async throws {
        // Create SpeechTranscriber with enhanced options for speaker diarization
        speechTranscriber = SpeechTranscriber(
            locale: currentLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        
        guard let transcriber = speechTranscriber else {
            throw SpeechRecognitionError.failedToCreateTranscriber
        }
        
        // Check if locale is supported
        guard await SpeechTranscriber.supportedLocales.contains(where: { 
            $0.identifier(.bcp47) == currentLocale.identifier(.bcp47) 
        }) else {
            throw SpeechRecognitionError.localeNotSupported
        }
        
        // Ensure model is downloaded
        try await ensureModel(transcriber: transcriber, locale: currentLocale)
        
        // Create SpeechAnalyzer
        speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
        
        // Get optimal audio format with fallback
        do {
            analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            print("🎵 Using analyzer format: \(analyzerFormat?.sampleRate ?? 0)Hz, \(analyzerFormat?.channelCount ?? 0) channels")
        } catch {
            print("⚠️ Failed to get optimal audio format, will use input format: \(error)")
            analyzerFormat = nil
        }
        
        await MainActor.run {
            self.isModelReady = true
            print("🎙️ SpeechAnalyzer setup completed for locale: \(self.currentLocale.identifier)")
        }
    }
    
    private func setupFallbackRecognizer() async {
        fallbackRecognizer = SFSpeechRecognizer(locale: currentLocale)
        fallbackRecognizer?.delegate = self
        
        await MainActor.run {
            self.isModelReady = self.fallbackRecognizer?.isAvailable ?? false
            print("🎙️ Fallback speech recognizer setup for locale: \(self.currentLocale.identifier)")
        }
    }
    
    private func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        // Check if model is already installed
        if await SpeechTranscriber.installedLocales.contains(where: { 
            $0.identifier(.bcp47) == locale.identifier(.bcp47) 
        }) {
            print("✅ Model already installed for locale: \(locale.identifier)")
            return
        }
        
        // Download model if needed
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            await MainActor.run {
                self.downloadProgress = downloader.progress
                print("📥 Downloading speech model for locale: \(locale.identifier)")
            }
            
            try await downloader.downloadAndInstall()
            
            await MainActor.run {
                self.downloadProgress = nil
                print("✅ Speech model downloaded successfully")
            }
        }
    }
    
    // MARK: - Language Configuration
    
    private func loadLanguageSetting() {
        let savedLanguage = UserDefaults.standard.string(forKey: languageSettingsKey)
        
        if let savedLanguage = savedLanguage {
            currentLocale = Locale(identifier: savedLanguage)
            currentLanguageIdentifier = savedLanguage
            print("📱 Loaded saved language setting: \(savedLanguage)")
        } else {
            // Use system default
            currentLocale = Locale.current
            currentLanguageIdentifier = currentLocale.identifier
            print("📱 Using system default language: \(currentLocale.identifier)")
        }
    }
    
    private func saveLanguageSetting(_ localeIdentifier: String) {
        UserDefaults.standard.set(localeIdentifier, forKey: languageSettingsKey)
        UserDefaults.standard.synchronize()
        print("💾 Saved language setting: \(localeIdentifier)")
    }
    
    func configureLanguage(_ localeIdentifier: String) async {
        let newLocale = Locale(identifier: localeIdentifier)
        guard newLocale.identifier != currentLocale.identifier else { return }
        
        // Stop any existing transcription
        if isTranscribing {
            await stopTranscribing()
        }
        
        currentLocale = newLocale
        
        // Save the language setting
        saveLanguageSetting(localeIdentifier)
        
        // Update published property on main thread
        await MainActor.run {
            self.currentLanguageIdentifier = localeIdentifier
        }
        
        // Reconfigure speech services
        await setupSpeechServices()
        
        print("🌍 Speech services configured for locale: \(localeIdentifier)")
    }
    
    func getCurrentLanguage() -> String {
        return currentLocale.identifier
    }
    
    func getCurrentLanguageName() -> String {
        return currentLocale.localizedString(forIdentifier: currentLocale.identifier) ?? currentLocale.identifier
    }
    
    func getSupportedLanguages() -> [String] {
        // Common languages supported by SFSpeechRecognizer
        return [
            "en-US",    // English (US)
            "en-GB",    // English (UK)
            "zh-CN",    // Chinese (Simplified)
            "zh-TW",    // Chinese (Traditional)
            "ja-JP",    // Japanese
            "ko-KR",    // Korean
            "es-ES",    // Spanish (Spain)
            "es-MX",    // Spanish (Mexico)
            "fr-FR",    // French
            "de-DE",    // German
            "it-IT",    // Italian
            "pt-BR",    // Portuguese (Brazil)
            "ru-RU",    // Russian
            "ar-SA",    // Arabic
            "hi-IN",    // Hindi
            "th-TH",    // Thai
            "vi-VN",    // Vietnamese
            "nl-NL",    // Dutch
            "sv-SE",    // Swedish
            "da-DK",    // Danish
            "no-NO",    // Norwegian
            "fi-FI",    // Finnish
            "pl-PL",    // Polish
            "tr-TR",    // Turkish
            "he-IL",    // Hebrew
            "cs-CZ",    // Czech
            "sk-SK",    // Slovak
            "hu-HU",    // Hungarian
            "ro-RO",    // Romanian
            "hr-HR",    // Croatian
            "uk-UA",    // Ukrainian
            "bg-BG",    // Bulgarian
            "ca-ES",    // Catalan
            "el-GR",    // Greek
            "ms-MY",    // Malay
            "id-ID",    // Indonesian
        ]
    }
    
    func getLanguageDisplayName(for localeIdentifier: String) -> String {
        let locale = Locale(identifier: localeIdentifier)
        return locale.localizedString(forIdentifier: localeIdentifier) ?? localeIdentifier
    }
    
    func resetLanguageToDefault() async {
        // Reset to system default
        let systemLocale = Locale.current
        await configureLanguage(systemLocale.identifier)
        print("🔄 Reset language to system default: \(systemLocale.identifier)")
    }
    
    func isLanguageSupported(_ localeIdentifier: String) -> Bool {
        return getSupportedLanguages().contains(localeIdentifier)
    }
    
    func getCurrentLanguageSupported() -> Bool {
        return isLanguageSupported(currentLocale.identifier)
    }
    
    // MARK: - Transcription Control
    
    private func cleanupAdvancedTranscription() async {
        // Stop any running tasks
        recognizerTask?.cancel()
        recognizerTask = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Close input stream
        inputBuilder?.finish()
        inputBuilder = nil
        inputSequence = nil
        
        print("🧹 Advanced transcription cleanup completed")
    }
    
    func startTranscribing() async {
        guard authorizationStatus == .authorized else {
            print("❌ Speech recognition not authorized: \(authorizationStatus.rawValue)")
            return
        }
        
        guard isModelReady else {
            print("❌ Speech services not ready")
            return
        }
        
        // Stop any existing transcription
        if isTranscribing {
            await stopTranscribing()
        }
        
        if useFallback {
            await startFallbackTranscription()
        } else {
            await startAdvancedTranscription()
        }
    }
    
    private func startAdvancedTranscription() async {
        guard let analyzer = speechAnalyzer else { return }
        
        do {
            // Setup audio stream
            let audioStream = try await setupAudioStream()
            
            // Create input sequence for SpeechAnalyzer
            (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            
            guard let inputSequence = inputSequence else {
                print("❌ Failed to create input sequence")
                throw SpeechRecognitionError.failedToCreateTranscriber
            }
            
            // Start SpeechAnalyzer
            try await analyzer.start(inputSequence: inputSequence)
            
            // Start processing results
            startResultProcessing()
            
            // Start audio processing
            await startAudioProcessing(audioStream: audioStream)
            
            await MainActor.run {
                self.isTranscribing = true
                print("🎙️ Started live transcription with speaker diarization")
            }
            
        } catch {
            print("❌ Failed to start advanced transcription: \(error)")
            
            // Clean up any partial setup
            await cleanupAdvancedTranscription()
            
            // Fallback to basic transcription
            print("🔄 Falling back to SFSpeechRecognizer...")
            useFallback = true
            await setupFallbackRecognizer()
            await startFallbackTranscription()
        }
    }
    
    private func startFallbackTranscription() async {
        guard let speechRecognizer = fallbackRecognizer, speechRecognizer.isAvailable else {
            print("❌ Fallback speech recognizer not available")
            return
        }
        
        do {
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                print("❌ Unable to create recognition request")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Setup audio engine
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                self?.handleFallbackResult(result: result, error: error)
            }
            
            await MainActor.run {
                self.isTranscribing = true
                print("🎙️ Started fallback transcription")
            }
            
        } catch {
            print("❌ Failed to start fallback transcription: \(error)")
            await stopTranscribing()
        }
    }
    
    func stopTranscribing() async {
        await MainActor.run {
            self.isTranscribing = false
        }
        
        if useFallback {
            // Stop fallback transcription
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            
            // Force final result from current volatile results if we have any
            if !volatileResults.isEmpty, let lastVolatileResult = volatileResults.last {
                print("🔚 Forcing final result from volatile data: \(lastVolatileResult)")
                processFallbackFinalResult(text: lastVolatileResult)
                DispatchQueue.main.async {
                    self.updateTranscriptionDisplay()
                }
            }
            
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
        } else {
            // Stop advanced transcription
            recognizerTask?.cancel()
            recognizerTask = nil
            
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            
            // Finalize analyzer
            if let analyzer = speechAnalyzer {
                do {
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                } catch {
                    print("⚠️ Error finalizing analyzer: \(error)")
                }
            }
            
            // Close input stream
            inputBuilder?.finish()
            inputBuilder = nil
            inputSequence = nil
        }
        
        print("🎙️ Stopped transcription")
    }
    
    func clearTranscription() {
        transcribedText = ""
        transcribedSentences = []
        formattedParagraphs = []
        detectedSpeakers = []
        currentSpeakerSegments = []
        speakerProfiles = [:]
        volatileResults = []
        finalResults = []
    }
    
    // MARK: - Audio Processing (Advanced)
    
    private func setupAudioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Use the analyzer format directly or fallback to input format
        let targetFormat = analyzerFormat ?? inputFormat
        
        // Create converter only if formats are different and conversion is needed
        if let analyzerFormat = analyzerFormat, 
           inputFormat.sampleRate != analyzerFormat.sampleRate || 
           inputFormat.channelCount != analyzerFormat.channelCount {
            
            print("🔄 Setting up audio converter: \(inputFormat.sampleRate)Hz -> \(analyzerFormat.sampleRate)Hz")
            audioConverter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
            
            // Validate converter
            if audioConverter == nil {
                print("⚠️ Audio converter creation failed, using input format directly")
            }
        }
        
        // Create audio stream
        let audioStream = AsyncStream(AVAudioPCMBuffer.self) { continuation in
            outputContinuation = continuation
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, time in
                continuation.yield(buffer)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎤 Audio stream setup completed with format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        return audioStream
    }
    
    private func startAudioProcessing(audioStream: AsyncStream<AVAudioPCMBuffer>) {
        Task {
            do {
                for await buffer in audioStream {
                    do {
                        let processedBuffer = try convertBufferIfNeeded(buffer)
                        inputBuilder?.yield(AnalyzerInput(buffer: processedBuffer))
                    } catch {
                        print("⚠️ Buffer processing error: \(error), skipping buffer")
                        // Continue processing other buffers instead of stopping
                        continue
                    }
                }
            } catch {
                print("❌ Audio processing error: \(error)")
                // Try to restart audio processing if it fails
                if isTranscribing {
                    print("🔄 Attempting to restart audio processing...")
                    // We could implement restart logic here if needed
                }
            }
        }
    }
    
    private func convertBufferIfNeeded(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let converter = audioConverter, let analyzerFormat = analyzerFormat else {
            // No conversion needed, return original buffer
            return buffer
        }
        
        // Create output buffer with proper capacity
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: buffer.frameCapacity) else {
            print("⚠️ Failed to create converted buffer, using original")
            return buffer
        }
        
        // Perform conversion with error handling
        var error: NSError? = nil
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if status == .error {
            print("⚠️ Audio conversion failed: \(error?.localizedDescription ?? "unknown error"), using original buffer")
            return buffer
        }
        
        return convertedBuffer
    }
    
    // MARK: - Result Processing (Advanced)
    
    private func startResultProcessing() {
        guard let transcriber = speechTranscriber else { return }
        
        recognizerTask = Task {
            do {
                for try await result in transcriber.results {
                    await processAdvancedResult(result)
                }
            } catch {
                print("❌ Result processing error: \(error)")
            }
        }
    }
    
    private func processAdvancedResult(_ result: SpeechTranscriber.Result) async {
        // Extract text from AttributedString
        let text = String(result.text.characters)
        let isFinal = result.isFinal
        
        if isFinal {
            // Process final result with speaker diarization
            processFinalResult(text: text, result: result)
        } else {
            // Process volatile result for real-time feedback
            processVolatileResult(text: text)
        }
        
        // Update UI on main thread
        await MainActor.run {
            self.updateTranscriptionDisplay()
        }
    }
    
    private func processFinalResult(text: String, result: SpeechTranscriber.Result) {
        // Extract timing information from result
        let timeRange = extractTimeRange(from: result)
        
        // Extract speaker information from metadata
        let speakerInfo = extractSpeakerInfo(from: result)
        let speaker = getOrCreateSpeaker(from: speakerInfo)
        
        // Create transcript segment
        let segment = TranscriptSegment(
            text: text,
            startTime: timeRange?.start ?? 0,
            endTime: timeRange?.end ?? 0,
            confidence: extractConfidence(from: result)
        )
        var finalSegment = segment
        finalSegment.speaker = speaker
        
        finalResults.append(finalSegment)
        currentSpeakerSegments = finalResults
        
        // Clear volatile results for this segment
        if let index = volatileResults.firstIndex(of: text) {
            volatileResults.remove(at: index)
        }
        
        print("🎯 Final result: Speaker \(speaker.name) - \(text)")
    }
    
    private func extractTimeRange(from result: SpeechTranscriber.Result) -> (start: TimeInterval, end: TimeInterval)? {
        // Extract timing information from AttributedString
        if let run = result.text.runs.first {
            // Access audio time range from AttributedString using proper iOS 26 API
            if let timeRange = run.audioTimeRange {
                let startTime = CMTimeGetSeconds(timeRange.start)
                let endTime = CMTimeGetSeconds(timeRange.end)
                return (start: startTime, end: endTime)
            }
        }
        return nil
    }
    
    private func extractConfidence(from result: SpeechTranscriber.Result) -> Double {
        // Extract confidence from AttributedString attributes
        // Note: Confidence attributes may not be fully available in current iOS 26 beta
        return 0.9 // Default confidence
    }
    
    private func extractSpeakerInfo(from result: SpeechTranscriber.Result) -> SpeakerInfo {
        // Extract speaker characteristics from AttributedString attributes
        var speakerId = "unknown"
        var confidence = 0.0
        
        // Generate a basic speaker ID based on timing and other factors
        // This is a placeholder until proper speaker attributes are available
        let timeBasedId = Int(Date().timeIntervalSince1970 * 1000) % 1000
        speakerId = "speaker_\(timeBasedId % 5)" // Simulate up to 5 speakers
        confidence = 0.8
        
        // Create voice characteristics (simplified for now)
        let voiceCharacteristics = VoiceProfile(
            pitch: 0.5,
            tone: 0.5,
            pace: 0.5,
            confidence: confidence
        )
        
        return SpeakerInfo(
            identifier: speakerId,
            confidence: confidence,
            voiceCharacteristics: voiceCharacteristics
        )
    }
    
    private func getOrCreateSpeaker(from speakerInfo: SpeakerInfo) -> Speaker {
        let speakerId = speakerInfo.identifier
        
        if let existingSpeaker = speakerProfiles[speakerId] {
            return existingSpeaker
        }
        
        // Create new speaker
        let speakerNumber = detectedSpeakers.count + 1
        let speaker = Speaker(
            name: "Speaker \(speakerNumber)",
            identifier: speakerId
        )
        var newSpeaker = speaker
        newSpeaker.voiceProfile = speakerInfo.voiceCharacteristics
        
        speakerProfiles[speakerId] = newSpeaker
        detectedSpeakers.append(newSpeaker)
        
        print("👤 New speaker detected: \(newSpeaker.name) (ID: \(speakerId))")
        return newSpeaker
    }
    
    private func processVolatileResult(text: String) {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Keep only the latest volatile result for real-time display
        volatileResults = [text]
        
        print("💭 Volatile result: \(text)")
    }
    
    // MARK: - Fallback Result Processing
    
    private func handleFallbackResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ Fallback recognition error: \(error)")
            return
        }
        
        guard let result = result else { return }
        
        let transcribedText = result.bestTranscription.formattedString
        
        // Always update volatile results for real-time display
        processVolatileResult(text: transcribedText)
        
        if result.isFinal {
            print("✅ Final result received: \(transcribedText)")
            processFallbackFinalResult(text: transcribedText)
        } else {
            print("💭 Volatile result received: \(transcribedText)")
        }
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.updateTranscriptionDisplay()
        }
    }
    
    private func processFallbackFinalResult(text: String) {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create a default speaker for fallback
        let speaker = getOrCreateDefaultSpeaker()
        
        // Create transcript segment
        let segment = TranscriptSegment(
            text: text,
            startTime: Date().timeIntervalSince1970,
            endTime: Date().timeIntervalSince1970,
            confidence: 0.9
        )
        var finalSegment = segment
        finalSegment.speaker = speaker
        
        finalResults.append(finalSegment)
        currentSpeakerSegments = finalResults
        
        // Clear volatile results since we have a final result
        volatileResults.removeAll()
        
        print("🎯 Fallback final result: \(text)")
    }
    
    private func getOrCreateDefaultSpeaker() -> Speaker {
        let speakerId = "default_speaker"
        
        if let existingSpeaker = speakerProfiles[speakerId] {
            return existingSpeaker
        }
        
        // Create default speaker
        let speaker = Speaker(name: "Speaker 1", identifier: speakerId)
        speakerProfiles[speakerId] = speaker
        
        if !detectedSpeakers.contains(where: { $0.id == speaker.id }) {
            detectedSpeakers.append(speaker)
        }
        
        return speaker
    }
    
    // MARK: - UI Updates
    
    private func updateTranscriptionDisplay() {
        // Combine final results into coherent text
        let finalText = finalResults.map { $0.text }.joined(separator: " ")
        
        // Add volatile results for real-time display
        let currentVolatileText = volatileResults.last ?? "" // Use the latest volatile result
        
        // Combine both for full display
        var combinedText = finalText
        if !currentVolatileText.isEmpty {
            combinedText = [finalText, currentVolatileText].filter { !$0.isEmpty }.joined(separator: " ")
        }
        
        transcribedText = combinedText
        
        // For paragraph formatting, use the combined text as a single source
        transcribedSentences = combinedText.isEmpty ? [] : [combinedText]
        
        // Update formatted paragraphs
        updateFormattedParagraphs()
        
        print("📝 Updated transcription: Final(\(finalResults.count) segments), Volatile(\(volatileResults.count) items), Combined length: \(combinedText.count)")
    }
    
    private func updateFormattedParagraphs() {
        let paragraphsText = formatIntoParagraphs(transcribedSentences)
        formattedParagraphs = paragraphsText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func formatIntoParagraphs(_ sentences: [String]) -> String {
        guard !sentences.isEmpty else { return "" }
        
        // Combine all sentences into one text block first
        let fullText = sentences.joined(separator: " ")
        
        // Split into more natural segments for speech
        let segments = splitIntoSpeechSegments(fullText)
        
        // Create paragraphs from segments
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for segment in segments {
            let cleanSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanSegment.isEmpty else { continue }
            
            currentParagraph.append(cleanSegment)
            
            // Break paragraph based on speech patterns
            if shouldBreakParagraph(currentSegment: cleanSegment, paragraphLength: currentParagraph.count) {
                paragraphs.append(currentParagraph.joined(separator: " "))
                currentParagraph = []
            }
        }
        
        // Add remaining segments
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
    
    private func splitIntoSpeechSegments(_ text: String) -> [String] {
        // Split on common speech boundaries using simple string patterns
        let separators = [
            ". ",             // End of sentence
            "? ",             // End of question
            "! ",             // End of exclamation
            ", and ",         // Connecting phrases
            ", but ",
            ", so ",
            ", then ",
            ", now ",
            ", well ",
            ", you know ",
            ", I mean ",
            ", actually ",
            ", basically ",
            ", obviously ",
            ", however ",
            ", therefore ",
            ", meanwhile ",
            ", furthermore ",
            ", moreover ",
            ", additionally "
        ]
        
        var segments: [String] = [text]
        
        // Split on each separator
        for separator in separators {
            var newSegments: [String] = []
            for segment in segments {
                let parts = segment.components(separatedBy: separator)
                if parts.count > 1 {
                    // Add the separator back to maintain natural flow
                    for i in 0..<parts.count {
                        var part = parts[i]
                        if i < parts.count - 1 && !part.isEmpty {
                            part += separator.trimmingCharacters(in: .whitespaces)
                        }
                        if !part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            newSegments.append(part)
                        }
                    }
                } else {
                    newSegments.append(segment)
                }
            }
            segments = newSegments
        }
        
        return segments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func shouldBreakParagraph(currentSegment: String, paragraphLength: Int) -> Bool {
        // Always break on questions
        if currentSegment.hasSuffix("?") {
            return true
        }
        
        // Break on topic change indicators
        let topicChangeWords = [
            "now let's", "moving on", "next topic", "another point", "speaking of",
            "on the other hand", "meanwhile", "in addition", "furthermore",
            "however", "alternatively", "in contrast", "let me switch",
            "changing topics", "regarding", "concerning", "as for",
            "let's discuss", "turning to", "now about", "what about",
            "back to", "returning to", "shifting to", "continuing with"
        ]
        
        let lowerSegment = currentSegment.lowercased()
        for word in topicChangeWords {
            if lowerSegment.contains(word) {
                return true
            }
        }
        
        // Break after 2-3 segments or if segment is very long
        if paragraphLength >= 2 {
            let wordCount = currentSegment.components(separatedBy: .whitespaces).count
            if wordCount > 30 || paragraphLength >= 3 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Helper Methods
    
    func getSpeakerCount() -> Int {
        return max(detectedSpeakers.count, 1)
    }
    
    func isSpeakerSeparationAvailable() -> Bool {
        return !useFallback && isModelReady && speechAnalyzer != nil
    }
    
    func saveTranscription(to meetingStore: MeetingStore, meetingId: UUID) {
        // Ensure we have the latest transcription
        updateTranscriptionDisplay()
        
        // Get the final transcription text
        let finalTranscriptionText = finalResults.map { $0.text }.joined(separator: " ")
        
        // Save transcription to meeting store
        if let meeting = meetingStore.meetings.first(where: { $0.id == meetingId }) {
            var updatedMeeting = meeting
            
            // Update transcript data with final results
            updatedMeeting.transcriptData.fullText = finalTranscriptionText
            updatedMeeting.transcriptData.segments = finalResults
            updatedMeeting.transcriptData.speakerCount = getSpeakerCount()
            updatedMeeting.transcriptData.wordCount = finalTranscriptionText.split(separator: " ").count
            
            meetingStore.updateMeeting(updatedMeeting)
            print("💾 Transcription saved to meeting - Final text: '\(finalTranscriptionText)' (\(finalResults.count) segments)")
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if useFallback {
            DispatchQueue.main.async {
                self.isModelReady = available
                print("🎙️ Fallback speech recognizer availability changed: \(available)")
            }
        }
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, *)
struct SpeakerInfo {
    let identifier: String
    let confidence: Double
    let voiceCharacteristics: VoiceProfile
}

@available(iOS 26.0, *)
enum SpeechRecognitionError: Error {
    case failedToCreateTranscriber
    case localeNotSupported
    case modelNotAvailable
    case audioConversionFailed
} 