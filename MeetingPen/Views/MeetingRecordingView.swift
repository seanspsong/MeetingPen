import SwiftUI
import PencilKit
import UIKit

/// Complete meeting recording view with handwriting recognition integration
struct MeetingRecordingView: View {
    
    // MARK: - Properties
    let meeting: Meeting
    @Binding var isPresented: Bool
    let shouldStartRecording: Bool // New parameter to control auto-start
    
    // MARK: - Environment
    @EnvironmentObject var meetingStore: MeetingStore
    
    // MARK: - State
    @StateObject private var handwritingViewModel = HandwritingViewModel()
    @StateObject private var audioRecordingService = AudioRecordingService.shared
    @StateObject private var speechRecognitionService = SpeechRecognitionService.shared
    @State private var showingToolPicker = false
    @State private var showingSettings = false
    
    private var meetingTitle: String {
        meeting.title
    }
    

    
    // MARK: - Initializer
    init(meeting: Meeting, isPresented: Binding<Bool>, shouldStartRecording: Bool = false) {
        self.meeting = meeting
        self._isPresented = isPresented
        self.shouldStartRecording = shouldStartRecording
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with recording controls
                headerView
                
                // Main content area
                if UIDevice.current.orientation.isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
                
                // Drawing tools toolbar
                drawingToolsView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Setup handwriting recognition for current meeting
            handwritingViewModel.meetingStore = meetingStore
            handwritingViewModel.loadFromMeeting(meetingId: meeting.id)
            
            // Auto-start recording if requested
            if shouldStartRecording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    startRecording()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            HandwritingSettingsView(viewModel: handwritingViewModel)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meetingTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    // Recording indicator
                    if audioRecordingService.isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                        Text("Recording: \(formattedRecordingDuration)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .monospacedDigit()
                    }
                    // Playback indicator
                    else if audioRecordingService.isPlaying {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                        Text("Playing: \(formattedPlaybackDuration)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                    // Idle state
                    else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                        Text(formattedRecordingDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            Spacer()
            
            // Main controls (left: record, right: play)
            HStack(spacing: 32) {
                // Left button - Recording (red)
                Button(action: toggleRecording) {
                    Image(systemName: audioRecordingService.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(audioRecordingService.isRecording ? .red : .red)
                }
                .disabled(audioRecordingService.isPlaying) // Cannot record while playing
                
                // Right button - Playback (green)
                Button(action: togglePlayback) {
                    Image(systemName: audioRecordingService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(audioRecordingService.isPlaying ? .green : .green)
                }
                .disabled(audioRecordingService.isRecording || !hasRecordedAudio) // Cannot play while recording or if no audio
            }
            
            Spacer()
            
            // Secondary controls
            HStack(spacing: 16) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Layout Views
    
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side: Audio visualization and transcription
            audioVisualizationView
                .frame(width: geometry.size.width * 0.35)
            
            Divider()
            
            // Right side: Handwriting canvas
            handwritingCanvasView
                .frame(width: geometry.size.width * 0.65)
        }
    }
    
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top: Audio visualization and transcription
            audioVisualizationView
                .frame(height: geometry.size.height * 0.3)
            
            Divider()
            
            // Bottom: Handwriting canvas
            handwritingCanvasView
                .frame(height: geometry.size.height * 0.7)
        }
    }
    
    // MARK: - Audio Visualization View
    
    private var audioVisualizationView: some View {
        VStack(spacing: 12) {
            // Audio waveform visualization
            WaveformVisualizationView(
                isRecording: audioRecordingService.isRecording,
                audioLevels: audioRecordingService.audioLevels
            )
            .frame(height: 60)
            .padding(.horizontal)
            
            // Live transcription preview
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Live Transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if speechRecognitionService.isTranscribing {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    
                    if speechRecognitionService.transcribedText.isEmpty {
                        Text("Transcription will appear here when recording starts...")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(speechRecognitionService.transcribedText)
                            .font(.body)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Handwriting Canvas View
    
    private var handwritingCanvasView: some View {
        VStack(spacing: 0) {
            // Debug Info Section (Always Visible)
            debugSection
            
            // Handwriting Recognition Section (Always Visible)
            recognitionResultsSection
            
            // Canvas
            HandwritingCanvasView(
                drawing: $handwritingViewModel.currentDrawing,
                recognizedText: $handwritingViewModel.recognizedText,
                isRecognizing: $handwritingViewModel.isRecognizing,
                allowsFingerDrawing: handwritingViewModel.allowsFingerDrawing,
                showRecognitionPreview: handwritingViewModel.showRecognitionPreview,
                recognitionDelay: handwritingViewModel.recognitionDelay,
                onDrawingChange: { drawing in
                    print("📝 [DEBUG] MeetingRecordingView.onDrawingChange called with \(drawing.strokes.count) strokes")
                    // Update the view model with the new drawing
                    handwritingViewModel.currentDrawing = drawing
                },
                onRecognitionTrigger: { drawing in
                    print("📝 [DEBUG] MeetingRecordingView.onRecognitionTrigger called with \(drawing.strokes.count) strokes")
                    // Trigger automatic recognition through the view model (uses cache)
                    handwritingViewModel.performAutoRecognition()
                }
            )
        }
    }
    
    // MARK: - Debug Section (Always Visible)
    
    private var debugSection: some View {
        VStack(spacing: 0) {
            // Debug Info Section
            VStack(alignment: .leading, spacing: 8) {
                Text("🔍 Debug Info")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Strokes: \(handwritingViewModel.currentDrawing.strokes.count)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text("Auto Recognition: \(handwritingViewModel.autoRecognitionEnabled ? "✅ ON" : "❌ OFF")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(handwritingViewModel.autoRecognitionEnabled ? .green : .red)
                    
                    Text("Recognition Delay: \(handwritingViewModel.recognitionDelay, specifier: "%.1f")s")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text("Finger Drawing: \(handwritingViewModel.allowsFingerDrawing ? "✅ ON" : "❌ OFF")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(handwritingViewModel.allowsFingerDrawing ? .green : .red)
                    
                    Text("Meeting ID: \(handwritingViewModel.meetingId?.uuidString.prefix(8) ?? "nil")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text("Meeting Store: \(handwritingViewModel.meetingStore != nil ? "✅ Connected" : "❌ Disconnected")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(handwritingViewModel.meetingStore != nil ? .green : .red)
                    
                    Text("Recognized Text: '\(handwritingViewModel.recognizedText.isEmpty ? "None" : handwritingViewModel.recognizedText)'")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(handwritingViewModel.recognizedText.isEmpty ? .secondary : .blue)
                    
                    // Recognition Status
                    Text("Recognition Status: \(handwritingViewModel.isRecognizing ? "🔄 Processing..." : "⏹️ Idle")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(handwritingViewModel.isRecognizing ? .orange : .secondary)
                }
                
                // Debug buttons
                HStack(spacing: 8) {
                    Button(action: {
                        print("📝 [DEBUG] Manual recognition button pressed")
                        handwritingViewModel.forceRecognition()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                            Text("Recognize")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Button(action: {
                        print("📝 [DEBUG] Clear button pressed")
                        handwritingViewModel.clearDrawing()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Button(action: {
                        print("📝 [DEBUG] Toggle auto recognition")
                        handwritingViewModel.setAutoRecognition(enabled: !handwritingViewModel.autoRecognitionEnabled)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: handwritingViewModel.autoRecognitionEnabled ? "pause.circle" : "play.circle")
                                .font(.system(size: 11))
                            Text("Auto")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(handwritingViewModel.autoRecognitionEnabled ? .orange : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((handwritingViewModel.autoRecognitionEnabled ? Color.orange : Color.green).opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Button(action: {
                        print("📝 [DEBUG] Reset service button pressed")
                        handwritingViewModel.recognitionService.resetService()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "restart.circle")
                                .font(.system(size: 11))
                            Text("Reset Service")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemBackground))
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Recognition Results Section
    
    private var recognitionResultsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("Recognition Results")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if handwritingViewModel.isRecognizing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Processing...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            
            // Recognition Content (Always Visible)
            VStack(alignment: .leading, spacing: 12) {
                // Recognized Text
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recognized Text")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(handwritingViewModel.recognizedText.isEmpty ? "No text recognized yet" : handwritingViewModel.recognizedText)
                            .font(.system(size: 16))
                            .foregroundColor(handwritingViewModel.recognizedText.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // Action buttons
                    VStack(spacing: 8) {
                        Button(action: copyRecognizedText) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(handwritingViewModel.recognizedText.isEmpty ? .secondary : .blue)
                                .frame(width: 32, height: 32)
                                .background((handwritingViewModel.recognizedText.isEmpty ? Color.secondary : Color.blue).opacity(0.1))
                                .cornerRadius(8)
                        }
                        .disabled(handwritingViewModel.recognizedText.isEmpty)
                        
                        Button(action: saveRecognizedText) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(handwritingViewModel.recognizedText.isEmpty ? .secondary : .green)
                                .frame(width: 32, height: 32)
                                .background((handwritingViewModel.recognizedText.isEmpty ? Color.secondary : Color.green).opacity(0.1))
                                .cornerRadius(8)
                        }
                        .disabled(handwritingViewModel.recognizedText.isEmpty)
                    }
                }
                
                // Recognition Stats (Always Visible)
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.word.spacing")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("\(handwritingViewModel.textElements.count) elements")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("\(handwritingViewModel.textElements.isEmpty ? "0" : String(Int(averageConfidence * 100)))% confidence")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("Last: \(handwritingViewModel.recognizedText.isEmpty ? "Never" : Date().formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: handwritingViewModel.recognizedText)
    }
    
    // MARK: - Recognition Computed Properties
    
    private var averageConfidence: Float {
        guard !handwritingViewModel.textElements.isEmpty else { return 0.0 }
        let totalConfidence = handwritingViewModel.textElements.reduce(0) { $0 + $1.confidence }
        return totalConfidence / Float(handwritingViewModel.textElements.count)
    }
    
    // MARK: - Drawing Tools View
    
    private var drawingToolsView: some View {
        HStack {
            // Tool buttons
            HStack(spacing: 20) {
                // Pen tool
                Button(action: { selectPenTool() }) {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                // Highlighter tool
                Button(action: { selectHighlighterTool() }) {
                    Image(systemName: "highlighter")
                        .font(.title3)
                        .foregroundColor(.yellow)
                }
                
                // Eraser tool
                Button(action: { selectEraserTool() }) {
                    Image(systemName: "eraser")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                
                // Undo
                Button(action: { handwritingViewModel.clearDrawing() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Recognition controls
            HStack(spacing: 16) {
                // Manual recognition trigger
                Button(action: { handwritingViewModel.recognizeCurrentDrawing() }) {
                    Image(systemName: "textformat.abc")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                // Clear canvas
                Button(action: { handwritingViewModel.clearDrawing() }) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Helper Views and Computed Properties
    
    private var formattedRecordingDuration: String {
        let minutes = Int(audioRecordingService.recordingDuration) / 60
        let seconds = Int(audioRecordingService.recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedPlaybackDuration: String {
        let currentMinutes = Int(audioRecordingService.playbackDuration) / 60
        let currentSeconds = Int(audioRecordingService.playbackDuration) % 60
        let totalMinutes = Int(audioRecordingService.totalDuration) / 60
        let totalSeconds = Int(audioRecordingService.totalDuration) % 60
        return String(format: "%02d:%02d / %02d:%02d", currentMinutes, currentSeconds, totalMinutes, totalSeconds)
    }
    
    private var hasRecordedAudio: Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("meeting_\(meeting.id.uuidString).m4a")
        return FileManager.default.fileExists(atPath: audioURL.path)
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if audioRecordingService.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func togglePlayback() {
        if audioRecordingService.isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startRecording() {
        // Start audio recording
        let success = audioRecordingService.startRecording(for: meeting.id)
        if success {
            // Start live transcription with a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.speechRecognitionService.startTranscribing()
            }
            print("🎤 Started recording and transcription for meeting: \(meeting.title)")
        } else {
            print("❌ Failed to start recording")
        }
    }
    
    private func startPlayback() {
        // Start audio playback
        let success = audioRecordingService.startPlayback(for: meeting.id)
        if success {
            print("▶️ Started playback for meeting: \(meeting.title)")
        } else {
            print("❌ Failed to start playback")
        }
    }
    
    private func stopRecording() {
        // Stop audio recording
        let recordingURL = audioRecordingService.stopRecording()
        
        // Stop transcription and save to meeting
        speechRecognitionService.stopTranscribing()
        speechRecognitionService.saveTranscription(to: meetingStore, meetingId: meeting.id)
        
        // Save handwriting notes
        handwritingViewModel.saveToMeeting()
        
        print("⏹️ Stopped recording. File: \(recordingURL?.lastPathComponent ?? "none")")
    }
    
    private func stopPlayback() {
        // Stop audio playback
        audioRecordingService.stopPlayback()
        
        print("⏹️ Stopped playback")
    }
    
    private func selectPenTool() {
        let penTool = handwritingViewModel.createPenTool(color: .black, width: 2)
        handwritingViewModel.setTool(penTool)
    }
    
    private func selectHighlighterTool() {
        let highlighterTool = handwritingViewModel.createHighlighterTool(color: .yellow, width: 20)
        handwritingViewModel.setTool(highlighterTool)
    }
    
    private func selectEraserTool() {
        let eraserTool = handwritingViewModel.createEraserTool()
        handwritingViewModel.setTool(eraserTool)
    }
    
    // MARK: - Recognition Actions
    
    private func copyRecognizedText() {
        UIPasteboard.general.string = handwritingViewModel.recognizedText
        
        // Show feedback (you could add haptic feedback here)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func saveRecognizedText() {
        // Save to meeting notes
        handwritingViewModel.saveToMeeting()
        
        // Show feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Waveform Visualization (Placeholder)

struct WaveformVisualizationView: View {
    let isRecording: Bool
    let audioLevels: [Float]
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isRecording ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 3)
                    .frame(height: getBarHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: audioLevels
                    )
            }
        }
        .onAppear {
            if isRecording {
                animationPhase = 1
            }
        }
        .onChange(of: isRecording) { _, newValue in
            animationPhase = newValue ? 1 : 0
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        if !isRecording {
            return 4.0
        }
        
        // Use real audio levels if available
        if !audioLevels.isEmpty {
            let levelIndex = min(index, audioLevels.count - 1)
            let level = audioLevels[levelIndex]
            return CGFloat(level) * 40.0 + 4.0 // Scale to 4-44 range
        }
        
        // Fallback to random animation for visual feedback
        return CGFloat.random(in: 4...40)
    }
}

// MARK: - Settings View

struct HandwritingSettingsView: View {
    @ObservedObject var viewModel: HandwritingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recognition Settings")) {
                    Toggle("Auto Recognition", isOn: $viewModel.autoRecognitionEnabled)
                    
                    Toggle("Show Recognition Preview", isOn: $viewModel.showRecognitionPreview)
                    
                    VStack {
                        HStack {
                            Text("Recognition Delay")
                            Spacer()
                            Text("\(viewModel.recognitionDelay, specifier: "%.1f")s")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $viewModel.recognitionDelay,
                            in: 0.1...5.0,
                            step: 0.1
                        )
                    }
                    
                    VStack {
                        HStack {
                            Text("Minimum Confidence")
                            Spacer()
                            Text("\(viewModel.minimumConfidence, specifier: "%.1f")")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $viewModel.minimumConfidence,
                            in: 0.0...1.0,
                            step: 0.1
                        )
                    }
                }
                
                Section(header: Text("Input Settings")) {
                    Toggle("Allow Finger Drawing", isOn: $viewModel.allowsFingerDrawing)
                }
                
                Section(header: Text("Actions")) {
                    Button("Clear All Handwriting") {
                        viewModel.clearDrawing()
                    }
                    .foregroundColor(.red)
                    
                    Button("Recognize Current Drawing") {
                        viewModel.recognizeCurrentDrawing()
                    }
                }
            }
            .navigationTitle("Handwriting Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @State var isPresented = true
    return MeetingRecordingView(meeting: Meeting.sampleMeetings[0], isPresented: $isPresented, shouldStartRecording: false)
} 