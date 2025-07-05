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
    
    // MARK: - Callbacks
    let onDrawingChange: ((PKDrawing) -> Void)?
    let onRecognitionTrigger: ((PKDrawing) -> Void)?
    
    // MARK: - State
    @State private var canvasView: PKCanvasView?
    
    // MARK: - Initialization
    init(
        drawing: Binding<PKDrawing>,
        recognizedText: Binding<String>,
        isRecognizing: Binding<Bool> = .constant(false),
        allowsFingerDrawing: Bool = true,  // Default ON for testing
        showRecognitionPreview: Bool = true,
        recognitionDelay: TimeInterval = 1.0,
        onDrawingChange: ((PKDrawing) -> Void)? = nil,
        onRecognitionTrigger: ((PKDrawing) -> Void)? = nil
    ) {
        self._drawing = drawing
        self._recognizedText = recognizedText
        self._isRecognizing = isRecognizing
        self.allowsFingerDrawing = allowsFingerDrawing
        self.showRecognitionPreview = showRecognitionPreview
        self.recognitionDelay = recognitionDelay
        self.onDrawingChange = onDrawingChange
        self.onRecognitionTrigger = onRecognitionTrigger
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        
        // Configure canvas
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
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
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
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
        }
        
        // MARK: - PKCanvasViewDelegate
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            print("🎨 [DEBUG] canvasViewDrawingDidChange called - strokes: \(canvasView.drawing.strokes.count)")
            
            // Update the binding
            parent.drawing = canvasView.drawing
            
            // Notify parent of drawing change
            print("🎨 [DEBUG] Calling onDrawingChange callback...")
            parent.onDrawingChange?(canvasView.drawing)
            
            // Schedule text recognition
            print("🎨 [DEBUG] Scheduling text recognition...")
            scheduleTextRecognition(for: canvasView.drawing)
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Optional: Handle tool usage start
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            print("🎨 [DEBUG] canvasViewDidEndUsingTool called - triggering immediate recognition")
            // Trigger immediate recognition when user stops drawing
            triggerRecognition(for: canvasView.drawing)
        }
        
        // MARK: - Text Recognition
        
        private func scheduleTextRecognition(for drawing: PKDrawing) {
            print("🎨 [DEBUG] scheduleTextRecognition called")
            
            guard parent.showRecognitionPreview else { 
                print("🎨 [DEBUG] Recognition preview disabled, skipping")
                return 
            }
            
            print("🎨 [DEBUG] Scheduling recognition with delay: \(parent.recognitionDelay)s")
            
            // Cancel previous timer
            recognitionTimer?.invalidate()
            
            // Schedule new recognition
            recognitionTimer = Timer.scheduledTimer(withTimeInterval: parent.recognitionDelay, repeats: false) { [weak self] _ in
                print("🎨 [DEBUG] Recognition timer fired!")
                self?.triggerRecognition(for: drawing)
            }
        }
        
        private func triggerRecognition(for drawing: PKDrawing) {
            print("🎨 [DEBUG] triggerRecognition called with \(drawing.strokes.count) strokes")
            parent.onRecognitionTrigger?(drawing)
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
        onRecognitionTrigger?(drawing)
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
                showRecognitionPreview: true,
                onDrawingChange: { drawing in
                    // Handle drawing changes
                },
                onRecognitionTrigger: { drawing in
                    // Handle recognition trigger
                }
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