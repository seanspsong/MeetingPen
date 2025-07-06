import Foundation
import PencilKit
import Combine
import SwiftUI

/// View model that manages handwriting recognition state and meeting integration
class HandwritingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentDrawing = PKDrawing()
    @Published var recognizedText = ""
    @Published var isRecognizing = false
    @Published var recognitionError: Error?
    @Published var textElements: [TextElement] = []
    @Published var selectedTool: PKTool = PKInkingTool(.pen, color: .black, width: 2)
    @Published var allowsFingerDrawing = true  // Default ON for testing
    @Published var showRecognitionPreview = true
    
    // MARK: - Recognition Settings
    @Published var autoRecognitionEnabled = true
    @Published var recognitionDelay: TimeInterval = 2.0  // Increased default delay
    @Published var minimumConfidence: Float = 0.3
    @Published var postClearDelay: TimeInterval = 3.0  // Extra delay after clearing
    
    // MARK: - Private Properties
    let recognitionService = HandwritingRecognitionService()  // Public access for debug controls
    private var cancellables = Set<AnyCancellable>()
    var meetingId: UUID?  // Made public for debug access
    var meetingStore: MeetingStore?
    private var lastClearTime: Date?  // Track when canvas was last cleared
    
    // MARK: - Initialization
    
    init(meetingId: UUID? = nil, meetingStore: MeetingStore? = nil) {
        self.meetingId = meetingId
        self.meetingStore = meetingStore
        setupObservers()
        configureInitialSettings()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe recognition service state
        recognitionService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.appendRecognizedText(text)
            }
            .store(in: &cancellables)
        
        recognitionService.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                self?.isRecognizing = isProcessing
            }
            .store(in: &cancellables)
        
        recognitionService.$recognitionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.recognitionError = error
            }
            .store(in: &cancellables)
    }
    
    private func configureInitialSettings() {
        // Configure default drawing tool
        selectedTool = PKInkingTool(.pen, color: .black, width: 2)
        
        // Load user preferences
        loadUserPreferences()
    }
    
    // MARK: - Public Methods
    
    /// Start handwriting recognition for the current drawing (manual recognition bypasses cache)
    func recognizeCurrentDrawing() {
        performRecognition(bypassCache: true, source: "MANUAL")
    }
    
    /// Force a completely fresh recognition attempt (clears cache first)
    func forceRecognition() {
        print("🖊️ [DEBUG] ForceRecognition: Clearing cache first")
        recognitionService.clearCache()
        performRecognition(bypassCache: true, source: "FORCE")
    }
    
    /// Perform automatic recognition (uses cache for performance)
    func performAutoRecognition() {
        // Check if enough time has passed since clearing
        if let lastClear = lastClearTime {
            let timeSinceClear = Date().timeIntervalSince(lastClear)
            if timeSinceClear < postClearDelay {
                print("🖊️ [DEBUG] Auto recognition blocked - only \(String(format: "%.1f", timeSinceClear))s since clear (need \(postClearDelay)s)")
                return
            } else {
                print("🖊️ [DEBUG] Auto recognition allowed - \(String(format: "%.1f", timeSinceClear))s since clear")
            }
        }
        
        performRecognition(bypassCache: false, source: "AUTO")
    }
    
    /// Internal method to perform recognition with cache control
    private func performRecognition(bypassCache: Bool, source: String) {
        print("🖊️ [DEBUG] HandwritingViewModel.performRecognition() called (source: \(source), bypassCache: \(bypassCache))")
        print("🖊️ [DEBUG] Current drawing has \(currentDrawing.strokes.count) strokes")
        
        guard !currentDrawing.strokes.isEmpty else { 
            print("🖊️ [DEBUG] No strokes found, returning early")
            return 
        }
        
        if bypassCache {
            print("🖊️ [DEBUG] Starting \(source) recognition service (bypassing cache)...")
        } else {
            print("🖊️ [DEBUG] Starting \(source) recognition service (using cache)...")
        }
        
        isRecognizing = true
        
        recognitionService.recognizeText(from: currentDrawing, bypassCache: bypassCache) { [weak self] result in
            DispatchQueue.main.async {
                print("🖊️ [DEBUG] \(source) recognition service completed")
                self?.isRecognizing = false
                
                switch result {
                case .success(let text):
                    print("🖊️ [DEBUG] \(source) recognition SUCCESS: '\(text)'")
                    self?.appendRecognizedText(text)
                    self?.saveRecognizedText(text)
                case .failure(let error):
                    print("🖊️ [DEBUG] \(source) recognition FAILED: \(error)")
                    self?.recognitionError = error
                }
            }
        }
    }
    
    /// Extract individual text elements from the current drawing
    func extractTextElements() {
        recognitionService.extractTextElements(from: currentDrawing) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let elements):
                    let newElements = elements.filter { $0.confidence >= self?.minimumConfidence ?? 0.3 }
                    self?.appendTextElements(newElements)
                case .failure(let error):
                    self?.recognitionError = error
                }
            }
        }
    }
    
    /// Recognize text from a specific region of the drawing
    func recognizeText(in region: CGRect) {
        recognitionService.recognizeText(from: currentDrawing, in: region) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    self?.handleRegionRecognition(text, in: region)
                case .failure(let error):
                    self?.recognitionError = error
                }
            }
        }
    }
    
    /// Clear the current drawing and reset recognition state
    func clearDrawing() {
        print("🖊️ [DEBUG] Clearing drawing and cache")
        currentDrawing = PKDrawing()
        recognizedText = ""
        textElements = []
        recognitionError = nil
        lastClearTime = Date()  // Record clear time
        
        // Clear the recognition cache to ensure fresh processing
        recognitionService.clearCache()
    }
    
    /// Clear only the drawing canvas, preserving recognized text
    func clearCanvas() {
        print("🖊️ [DEBUG] Clearing canvas only, preserving recognized text")
        currentDrawing = PKDrawing()
        recognitionError = nil
        lastClearTime = Date()  // Record clear time
        
        // Clear the recognition cache to ensure fresh processing
        recognitionService.clearCache()
    }
    
    /// Append new recognized text to existing text
    private func appendRecognizedText(_ newText: String) {
        guard !newText.isEmpty else { return }
        
        if recognizedText.isEmpty {
            recognizedText = newText
        } else {
            // Check if this text is already included to avoid duplicates
            if !recognizedText.contains(newText) {
                recognizedText += " " + newText
            }
        }
        print("🖊️ [DEBUG] Appended text. Total recognized text: '\(recognizedText)'")
    }
    
    /// Append new text elements to existing elements
    private func appendTextElements(_ newElements: [TextElement]) {
        guard !newElements.isEmpty else { return }
        
        for newElement in newElements {
            // Check if this element is already in our list to avoid duplicates
            let isDuplicate = textElements.contains { existing in
                existing.text == newElement.text && 
                abs(existing.boundingBox.origin.x - newElement.boundingBox.origin.x) < 10 &&
                abs(existing.boundingBox.origin.y - newElement.boundingBox.origin.y) < 10
            }
            
            if !isDuplicate {
                textElements.append(newElement)
            }
        }
        print("🖊️ [DEBUG] Appended text elements. Total elements: \(textElements.count)")
    }
    
    /// Save the current drawing and recognized text to the meeting
    func saveToMeeting() {
        print("🖊️ [DEBUG] saveToMeeting() called")
        print("🖊️ [DEBUG] meetingId: \(meetingId?.uuidString ?? "nil")")
        print("🖊️ [DEBUG] meetingStore: \(meetingStore != nil ? "exists" : "nil")")
        print("🖊️ [DEBUG] recognizedText: '\(recognizedText)'")
        
        guard let meetingId = meetingId,
              let meetingStore = meetingStore,
              let meeting = meetingStore.meetings.first(where: { $0.id == meetingId }) else { 
            print("🖊️ [DEBUG] Cannot save: missing meetingId, meetingStore, or meeting")
            return 
        }
        
        print("🖊️ [DEBUG] Found meeting: '\(meeting.title)'")
        print("🖊️ [DEBUG] Current handwritten notes: '\(meeting.handwritingData.allRecognizedText)'")
        
        // Update the meeting with handwritten notes and drawing data
        var updatedMeeting = meeting
        updatedMeeting.handwritingData.textSegments.append(
            HandwritingTextSegment(
                recognizedText: recognizedText,
                confidence: 0.85,
                boundingBox: .zero,
                timestamp: Date().timeIntervalSince1970,
                pageIndex: 0
            )
        )
        
        // Also save drawing data to the meeting
        let drawingData = currentDrawing.dataRepresentation()
        var drawingObject = HandwritingDrawing(
            boundingBox: .zero,
            timestamp: Date().timeIntervalSince1970,
            pageIndex: 0,
            title: "Handwriting \(Date().formatted(date: .omitted, time: .shortened))"
        )
        drawingObject.drawingData = drawingData
        updatedMeeting.handwritingData.drawings.append(drawingObject)
        
        meetingStore.updateMeeting(updatedMeeting)
        
        print("✅ [DEBUG] Saved handwriting to meeting: '\(recognizedText)'")
        print("🖊️ [DEBUG] Updated meeting handwritten notes: '\(updatedMeeting.handwritingData.allRecognizedText)'")
    }
    
    /// Load drawing and recognized text from a meeting
    func loadFromMeeting(meetingId: UUID) {
        self.meetingId = meetingId
        
        guard let meetingStore = meetingStore,
              let meeting = meetingStore.meetings.first(where: { $0.id == meetingId }) else { 
            print("Cannot load: missing meetingStore or meeting")
            return 
        }
        
        // Load handwritten notes
        recognizedText = meeting.handwritingData.allRecognizedText
        
        // Load drawing data if available
        if let lastDrawing = meeting.handwritingData.drawings.last,
           let drawingData = lastDrawing.drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            currentDrawing = drawing
        } else {
            currentDrawing = PKDrawing()
        }
        
        print("📖 Loaded handwriting from meeting: '\(recognizedText)'")
    }
    
    // MARK: - Drawing Tools
    
    /// Set the current drawing tool
    func setTool(_ tool: PKTool) {
        selectedTool = tool
    }
    
    /// Create a pen tool with specified color and width
    func createPenTool(color: UIColor = .black, width: CGFloat = 2) -> PKTool {
        return PKInkingTool(.pen, color: color, width: width)
    }
    
    /// Create a highlighter tool with specified color and width
    func createHighlighterTool(color: UIColor = .yellow, width: CGFloat = 20) -> PKTool {
        return PKInkingTool(.marker, color: color, width: width)
    }
    
    /// Create an eraser tool
    func createEraserTool() -> PKTool {
        return PKEraserTool(.bitmap)
    }
    
    // MARK: - Recognition Configuration
    
    /// Enable or disable automatic recognition
    func setAutoRecognition(enabled: Bool) {
        autoRecognitionEnabled = enabled
        saveUserPreferences()
    }
    
    /// Set the recognition delay
    func setRecognitionDelay(_ delay: TimeInterval) {
        recognitionDelay = max(1.0, min(5.0, delay))  // Increased minimum
        saveUserPreferences()
    }
    
    /// Set the post-clear delay
    func setPostClearDelay(_ delay: TimeInterval) {
        postClearDelay = max(2.0, min(10.0, delay))
        saveUserPreferences()
    }
    
    /// Set minimum confidence threshold for recognition
    func setMinimumConfidence(_ confidence: Float) {
        minimumConfidence = max(0.0, min(1.0, confidence))
        saveUserPreferences()
    }
    
    // MARK: - Private Methods
    
    private func handleRegionRecognition(_ text: String, in region: CGRect) {
        // Create a text element for the recognized region
        let textElement = TextElement(
            text: text,
            confidence: 1.0, // Region-specific recognition
            boundingBox: region
        )
        
        // Add to text elements if not already present
        if !textElements.contains(where: { $0.boundingBox == region }) {
            textElements.append(textElement)
        }
        
        // Also append to the main recognized text
        appendRecognizedText(text)
    }
    
    private func saveRecognizedText(_ text: String) {
        print("🖊️ [DEBUG] saveRecognizedText() called with: '\(text)'")
        
        guard !text.isEmpty else { 
            print("🖊️ [DEBUG] Text is empty, returning early")
            return 
        }
        
        print("🖊️ [DEBUG] Extracting text elements...")
        // Extract text elements when recognition is complete
        extractTextElements()
        
        // Auto-save recognized text to meeting if enabled
        if autoRecognitionEnabled {
            print("🖊️ [DEBUG] Auto-recognition enabled, saving to meeting...")
            saveToMeeting()
        } else {
            print("🖊️ [DEBUG] Auto-recognition disabled, not saving to meeting")
        }
        
        // Post notification for other parts of the app
        print("🖊️ [DEBUG] Posting handwriting recognized notification")
        NotificationCenter.default.post(
            name: .handwritingRecognized,
            object: self,
            userInfo: ["text": text, "meetingId": meetingId as Any]
        )
    }
    
    private func loadUserPreferences() {
        let defaults = UserDefaults.standard
        
        // Set defaults if not previously set
        if defaults.object(forKey: "handwriting.autoRecognition") == nil {
            autoRecognitionEnabled = true  // Default to enabled for automatic recognition
        } else {
            autoRecognitionEnabled = defaults.bool(forKey: "handwriting.autoRecognition")
        }
        
        recognitionDelay = defaults.double(forKey: "handwriting.recognitionDelay")
        postClearDelay = defaults.double(forKey: "handwriting.postClearDelay")
        minimumConfidence = defaults.float(forKey: "handwriting.minimumConfidence")
        allowsFingerDrawing = defaults.bool(forKey: "handwriting.allowsFingerDrawing")
        showRecognitionPreview = defaults.bool(forKey: "handwriting.showRecognitionPreview")
        
        // Set other defaults if not previously set
        if recognitionDelay == 0 { recognitionDelay = 2.0 }  // Increased default
        if postClearDelay == 0 { postClearDelay = 3.0 }  // New setting
        if minimumConfidence == 0 { minimumConfidence = 0.3 }
        if defaults.object(forKey: "handwriting.allowsFingerDrawing") == nil { allowsFingerDrawing = true }
        if defaults.object(forKey: "handwriting.showRecognitionPreview") == nil { showRecognitionPreview = true }
    }
    
    private func saveUserPreferences() {
        let defaults = UserDefaults.standard
        
        defaults.set(autoRecognitionEnabled, forKey: "handwriting.autoRecognition")
        defaults.set(recognitionDelay, forKey: "handwriting.recognitionDelay")
        defaults.set(postClearDelay, forKey: "handwriting.postClearDelay")
        defaults.set(minimumConfidence, forKey: "handwriting.minimumConfidence")
        defaults.set(allowsFingerDrawing, forKey: "handwriting.allowsFingerDrawing")
        defaults.set(showRecognitionPreview, forKey: "handwriting.showRecognitionPreview")
    }
    
}

// MARK: - Supporting Types

/// Data structure for storing handwriting information
struct HandwritingData: Codable {
    let meetingId: UUID
    let drawingData: Data
    let recognizedText: String
    let textElements: [TextElement]
    let timestamp: Date
    
    var drawing: PKDrawing {
        (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }
}

/// Extended TextElement to support Codable
extension TextElement: Codable {
    enum CodingKeys: String, CodingKey {
        case text, confidence, boundingBox
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        
        // Encode CGRect as array
        let rectArray = [boundingBox.origin.x, boundingBox.origin.y, boundingBox.size.width, boundingBox.size.height]
        try container.encode(rectArray, forKey: .boundingBox)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Float.self, forKey: .confidence)
        
        // Decode CGRect from array
        let rectArray = try container.decode([CGFloat].self, forKey: .boundingBox)
        guard rectArray.count == 4 else {
            throw DecodingError.dataCorruptedError(forKey: .boundingBox, in: container, debugDescription: "Invalid bounding box data")
        }
        boundingBox = CGRect(x: rectArray[0], y: rectArray[1], width: rectArray[2], height: rectArray[3])
    }
}



// MARK: - Notifications

extension Notification.Name {
    static let handwritingRecognized = Notification.Name("handwritingRecognized")
} 