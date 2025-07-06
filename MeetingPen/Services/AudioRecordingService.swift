import Foundation
import AVFoundation
import Combine

class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?
    private var currentMeetingId: UUID?
    
    override init() {
        super.init()
        // Don't setup audio session immediately to avoid crashes
        // It will be set up when recording starts
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Request microphone permission
            if #available(iOS 17.0, *) {
                Task {
                    do {
                        let granted = try await AVAudioApplication.requestRecordPermission()
                        DispatchQueue.main.async {
                            print("🎤 Microphone permission: \(granted ? "Granted" : "Denied")")
                        }
                    } catch {
                        print("❌ Failed to request microphone permission: \(error)")
                    }
                }
            } else {
                audioSession.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        print("🎤 Microphone permission: \(granted ? "Granted" : "Denied")")
                    }
                }
            }
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording(for meetingId: UUID) -> Bool {
        guard !isRecording && !isPlaying else { return false }
        
        // Stop playback if active
        if isPlaying {
            stopPlayback()
        }
        
        // Set up audio session before recording
        setupAudioSession()
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("meeting_\(meetingId.uuidString).m4a")
        currentMeetingId = meetingId
        
        guard let url = recordingURL else { return false }
        
        // Audio recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                recordingDuration = 0
                startRecordingTimers()
                print("🎤 Started recording to: \(url.lastPathComponent)")
                return true
            }
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
        
        return false
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        audioRecorder?.pause()
        isRecording = false
        stopRecordingTimers()
        print("⏸️ Recording paused")
    }
    
    func resumeRecording() {
        guard !isRecording, audioRecorder != nil else { return }
        audioRecorder?.record()
        isRecording = true
        startRecordingTimers()
        print("▶️ Recording resumed")
    }
    
    func stopRecording() -> URL? {
        guard audioRecorder != nil else { return nil }
        
        audioRecorder?.stop()
        isRecording = false
        stopRecordingTimers()
        
        let url = recordingURL
        audioRecorder = nil
        recordingURL = nil
        recordingDuration = 0
        
        print("⏹️ Recording stopped. File saved to: \(url?.lastPathComponent ?? "unknown")")
        return url
    }
    
    // MARK: - Playback Methods
    
    func startPlayback(for meetingId: UUID) -> Bool {
        guard !isPlaying && !isRecording else { return false }
        
        // Stop recording if active
        if isRecording {
            _ = stopRecording()
        }
        
        // Find the audio file for this meeting
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("meeting_\(meetingId.uuidString).m4a")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ No audio file found for meeting: \(meetingId)")
            return false
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            let success = audioPlayer?.play() ?? false
            if success {
                isPlaying = true
                playbackDuration = 0
                totalDuration = audioPlayer?.duration ?? 0
                currentMeetingId = meetingId
                startPlaybackTimer()
                print("▶️ Started playback of: \(audioURL.lastPathComponent)")
                return true
            }
        } catch {
            print("❌ Failed to start playback: \(error)")
        }
        
        return false
    }
    
    func pausePlayback() {
        guard isPlaying else { return }
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
        print("⏸️ Playback paused")
    }
    
    func resumePlayback() {
        guard !isPlaying, audioPlayer != nil else { return }
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
        print("▶️ Playback resumed")
    }
    
    func stopPlayback() {
        guard audioPlayer != nil else { return }
        
        audioPlayer?.stop()
        isPlaying = false
        stopPlaybackTimer()
        
        audioPlayer = nil
        playbackDuration = 0
        totalDuration = 0
        
        print("⏹️ Playback stopped")
    }
    
    private func startRecordingTimers() {
        // Duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingDuration()
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    private func stopRecordingTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackDuration()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updateRecordingDuration() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recordingDuration = recorder.currentTime
    }
    
    private func updatePlaybackDuration() {
        guard let player = audioPlayer, player.isPlaying else { return }
        playbackDuration = player.currentTime
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert dB to 0-1 range for visualization
        let normalizedAverage = pow(10.0, averagePower / 20.0)
        let normalizedPeak = pow(10.0, peakPower / 20.0)
        
        // Update audio levels for waveform visualization
        DispatchQueue.main.async {
            self.audioLevels.append(Float(normalizedPeak))
            if self.audioLevels.count > 100 { // Keep last 100 samples
                self.audioLevels.removeFirst()
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎤 Recording finished successfully: \(flag)")
        if !flag {
            print("❌ Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("▶️ Playback finished successfully: \(flag)")
        isPlaying = false
        stopPlaybackTimer()
        
        if !flag {
            print("❌ Playback failed")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Playback decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        stopPlaybackTimer()
    }
} 