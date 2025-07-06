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
        private var lastStrokeTime: Date?
        private var strokeCount = 0
        
        init(_ parent: HandwritingCanvasView) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - PKCanvasViewDelegate
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            print("🎨 [DEBUG] canvasViewDrawingDidChange called - strokes: \(canvasView.drawing.strokes.count)")
            
            lastStrokeTime = Date()
            strokeCount = canvasView.drawing.strokes.count
            
            // Update the binding
            parent.drawing = canvasView.drawing
            
            // Notify parent of drawing change
            print("🎨 [DEBUG] Calling onDrawingChange callback...")
            parent.onDrawingChange?(canvasView.drawing)
            
            // Schedule text recognition with improved logic
            print("🎨 [DEBUG] Scheduling text recognition...")
            scheduleTextRecognition(for: canvasView.drawing)
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            print("🎨 [DEBUG] canvasViewDidBeginUsingTool called")
            // Cancel any pending recognition while actively drawing
            recognitionTimer?.invalidate()
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            print("🎨 [DEBUG] canvasViewDidEndUsingTool called - strokes: \(canvasView.drawing.strokes.count)")
            
            // Don't trigger immediate recognition anymore - let the timer handle it
            // This prevents the "every letter" issue after clearing
            print("🎨 [DEBUG] Tool ended - letting scheduled recognition handle this")
            
            // Only schedule recognition, don't trigger immediately
            scheduleTextRecognition(for: canvasView.drawing)
        }
        
        // MARK: - Text Recognition
        
        private func scheduleTextRecognition(for drawing: PKDrawing) {
            print("🎨 [DEBUG] scheduleTextRecognition called")
            
            guard parent.showRecognitionPreview else { 
                print("🎨 [DEBUG] Recognition preview disabled, skipping")
                return 
            }
            
            guard !drawing.strokes.isEmpty else {
                print("🎨 [DEBUG] No strokes, skipping recognition")
                return
            }
            
            // Use longer delay for better word recognition
            let delayToUse = max(parent.recognitionDelay, 2.0)  // Minimum 2 seconds
            print("🎨 [DEBUG] Scheduling recognition with delay: \(delayToUse)s")
            
            // Cancel previous timer
            recognitionTimer?.invalidate()
            
            // Schedule new recognition with longer delay
            recognitionTimer = Timer.scheduledTimer(withTimeInterval: delayToUse, repeats: false) { [weak self] _ in
                print("🎨 [DEBUG] Recognition timer fired after \(delayToUse)s delay!")
                
                // Additional check: only trigger if user hasn't been actively drawing recently
                if let lastStroke = self?.lastStrokeTime,
                   Date().timeIntervalSince(lastStroke) >= 1.0 {  // Wait 1 second after last stroke
                    print("🎨 [DEBUG] Triggering recognition - last stroke was \(Date().timeIntervalSince(lastStroke))s ago")
                    self?.triggerRecognition(for: drawing)
                } else {
                    print("🎨 [DEBUG] Skipping recognition - user still actively drawing")
                }
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