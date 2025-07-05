import SwiftUI
import PencilKit

/// Complete meeting recording view with handwriting recognition integration
struct MeetingRecordingView: View {
    
    // MARK: - State
    @StateObject private var handwritingViewModel = HandwritingViewModel()
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var meetingTitle = "Marketing Strategy Session"
    @State private var showingToolPicker = false
    @State private var showingSettings = false
    
    // MARK: - Timer
    @State private var recordingTimer: Timer?
    
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
            let meetingId = UUID()
            handwritingViewModel.loadFromMeeting(meetingId: meetingId)
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
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .foregroundColor(isRecording ? .red : .gray)
                    
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            // Recording controls
            HStack(spacing: 16) {
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(isRecording ? .orange : .green)
                }
                
                Button(action: stopRecording) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .disabled(!isRecording && recordingDuration == 0)
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.blue)
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
            WaveformVisualizationView(isRecording: isRecording)
                .frame(height: 60)
                .padding(.horizontal)
            
            // Live transcription preview
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Transcription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("So for the Q4 campaign, I think we should focus on digital marketing initiatives...")
                        .font(.body)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            // Recognition preview
            if !handwritingViewModel.recognizedText.isEmpty {
                HStack {
                    Text("Recognized: \(handwritingViewModel.recognizedText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if handwritingViewModel.isRecognizing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemBackground))
            }
            
            // Canvas
            HandwritingCanvasView(
                drawing: $handwritingViewModel.currentDrawing,
                recognizedText: $handwritingViewModel.recognizedText,
                isRecognizing: $handwritingViewModel.isRecognizing,
                allowsFingerDrawing: handwritingViewModel.allowsFingerDrawing,
                showRecognitionPreview: handwritingViewModel.showRecognitionPreview,
                recognitionDelay: handwritingViewModel.recognitionDelay
            )
        }
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
    
    // MARK: - Helper Views
    
    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            pauseRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
        }
        
        // Start audio recording here
        // AudioRecordingService.shared.startRecording()
    }
    
    private func pauseRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Pause audio recording here
        // AudioRecordingService.shared.pauseRecording()
    }
    
    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
        
        // Stop audio recording and save meeting
        // AudioRecordingService.shared.stopRecording()
        handwritingViewModel.saveToMeeting()
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
}

// MARK: - Waveform Visualization (Placeholder)

struct WaveformVisualizationView: View {
    let isRecording: Bool
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isRecording ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 3)
                    .frame(height: CGFloat.random(in: 4...40))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.02),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            if isRecording {
                animationPhase = 1
            }
        }
        .onChange(of: isRecording) { newValue in
            animationPhase = newValue ? 1 : 0
        }
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

struct MeetingRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingRecordingView()
            .previewDevice("iPad Air (5th generation)")
    }
} 