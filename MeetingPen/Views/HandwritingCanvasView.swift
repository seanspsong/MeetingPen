import SwiftUI
import PencilKit
import Combine

/// SwiftUI view that provides a handwriting canvas with Apple Pencil support and text recognition
struct HandwritingCanvasView: UIViewRepresentable {
    
    // MARK: - Bindings
    @Binding var drawing: PKDrawing
    @Binding var recognizedText: String
    @Binding var isRecognizing: Bool
    
    // MARK: - Configuration
    let allowsFingerDrawing: Bool
    let showRecognitionPreview: Bool
    let recognitionDelay: TimeInterval
    
    // MARK: - State
    @StateObject private var recognitionService = HandwritingRecognitionService()
    @State private var canvasView: PKCanvasView?
    
    // MARK: - Initialization
    init(
        drawing: Binding<PKDrawing>,
        recognizedText: Binding<String>,
        isRecognizing: Binding<Bool> = .constant(false),
        allowsFingerDrawing: Bool = false,
        showRecognitionPreview: Bool = true,
        recognitionDelay: TimeInterval = 1.0
    ) {
        self._drawing = drawing
        self._recognizedText = recognizedText
        self._isRecognizing = isRecognizing
        self.allowsFingerDrawing = allowsFingerDrawing
        self.showRecognitionPreview = showRecognitionPreview
        self.recognitionDelay = recognitionDelay
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        
        // Configure canvas
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.allowsFingerDrawing = allowsFingerDrawing
        canvasView.backgroundColor = UIColor.systemBackground
        
        // Configure tool picker
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        
        // Enable ruler and other tools
        canvasView.isRulerActive = false
        canvasView.drawingPolicy = .default
        
        // Store reference for later use
        self.canvasView = canvasView
        
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Update drawing if it changed externally
        if canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
        
        // Update finger drawing setting
        canvasView.allowsFingerDrawing = allowsFingerDrawing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: HandwritingCanvasView
        private var recognitionTimer: Timer?
        
        init(_ parent: HandwritingCanvasView) {
            self.parent = parent
            super.init()
            
            // Setup recognition service observers
            setupRecognitionObservers()
        }
        
        private func setupRecognitionObservers() {
            parent.recognitionService.$recognizedText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] text in
                    self?.parent.recognizedText = text
                }
                .store(in: &parent.recognitionService.cancellables)
            
            parent.recognitionService.$isProcessing
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isProcessing in
                    self?.parent.isRecognizing = isProcessing
                }
                .store(in: &parent.recognitionService.cancellables)
        }
        
        // MARK: - PKCanvasViewDelegate
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Update the binding
            parent.drawing = canvasView.drawing
            
            // Schedule text recognition
            scheduleTextRecognition(for: canvasView.drawing)
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Optional: Handle tool usage start
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // Trigger immediate recognition when user stops drawing
            performTextRecognition(for: canvasView.drawing)
        }
        
        // MARK: - Text Recognition
        
        private func scheduleTextRecognition(for drawing: PKDrawing) {
            guard parent.showRecognitionPreview else { return }
            
            // Cancel previous timer
            recognitionTimer?.invalidate()
            
            // Schedule new recognition
            recognitionTimer = Timer.scheduledTimer(withTimeInterval: parent.recognitionDelay, repeats: false) { [weak self] _ in
                self?.performTextRecognition(for: drawing)
            }
        }
        
        private func performTextRecognition(for drawing: PKDrawing) {
            parent.recognitionService.recognizeText(from: drawing) { result in
                switch result {
                case .success(let text):
                    DispatchQueue.main.async {
                        self.parent.recognizedText = text
                    }
                case .failure(let error):
                    print("Text recognition failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Canvas Tools Extension

extension HandwritingCanvasView {
    
    /// Update the drawing tool
    func setTool(_ tool: PKTool) {
        canvasView?.tool = tool
    }
    
    /// Clear the canvas
    func clearCanvas() {
        canvasView?.drawing = PKDrawing()
        drawing = PKDrawing()
        recognizedText = ""
    }
    
    /// Undo last stroke
    func undo() {
        canvasView?.undoManager?.undo()
    }
    
    /// Redo last undone stroke
    func redo() {
        canvasView?.undoManager?.redo()
    }
    
    /// Manually trigger text recognition
    func recognizeText() {
        recognitionService.recognizeText(from: drawing) { result in
            switch result {
            case .success(let text):
                DispatchQueue.main.async {
                    self.recognizedText = text
                }
            case .failure(let error):
                print("Manual text recognition failed: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct HandwritingCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        HandwritingCanvasPreview()
    }
}

struct HandwritingCanvasPreview: View {
    @State private var drawing = PKDrawing()
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    
    var body: some View {
        VStack {
            // Recognition preview
            if !recognizedText.isEmpty {
                Text("Recognized: \(recognizedText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Canvas
            HandwritingCanvasView(
                drawing: $drawing,
                recognizedText: $recognizedText,
                isRecognizing: $isRecognizing,
                allowsFingerDrawing: true,
                showRecognitionPreview: true
            )
            .frame(height: 400)
            .border(Color.gray.opacity(0.3))
            
            // Controls
            HStack {
                Button("Clear") {
                    drawing = PKDrawing()
                    recognizedText = ""
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if isRecognizing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
        }
        .navigationTitle("Handwriting Canvas")
    }
} 