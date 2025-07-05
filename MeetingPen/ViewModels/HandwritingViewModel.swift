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
    @Published var allowsFingerDrawing = false
    @Published var showRecognitionPreview = true
    
    // MARK: - Recognition Settings
    @Published var autoRecognitionEnabled = true
    @Published var recognitionDelay: TimeInterval = 1.0
    @Published var minimumConfidence: Float = 0.3
    
    // MARK: - Private Properties
    private let recognitionService = HandwritingRecognitionService()
    private var cancellables = Set<AnyCancellable>()
    private var meetingId: UUID?
    
    // MARK: - Initialization
    
    init(meetingId: UUID? = nil) {
        self.meetingId = meetingId
        setupObservers()
        configureInitialSettings()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe recognition service state
        recognitionService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.recognizedText = text
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
    
    /// Start handwriting recognition for the current drawing
    func recognizeCurrentDrawing() {
        guard !currentDrawing.strokes.isEmpty else { return }
        
        recognitionService.recognizeText(from: currentDrawing) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    self?.recognizedText = text
                    self?.saveRecognizedText(text)
                case .failure(let error):
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
                    self?.textElements = elements.filter { $0.confidence >= self?.minimumConfidence ?? 0.3 }
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
        currentDrawing = PKDrawing()
        recognizedText = ""
        textElements = []
        recognitionError = nil
    }
    
    /// Save the current drawing and recognized text to the meeting
    func saveToMeeting() {
        guard let meetingId = meetingId else { return }
        
        // Save drawing data
        let drawingData = currentDrawing.dataRepresentation()
        
        // Save to meeting (this would integrate with your data layer)
        saveMeetingHandwriting(
            meetingId: meetingId,
            drawingData: drawingData,
            recognizedText: recognizedText,
            textElements: textElements
        )
    }
    
    /// Load drawing and recognized text from a meeting
    func loadFromMeeting(meetingId: UUID) {
        self.meetingId = meetingId
        
        // Load from meeting (this would integrate with your data layer)
        loadMeetingHandwriting(meetingId: meetingId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let handwritingData):
                    self?.currentDrawing = handwritingData.drawing
                    self?.recognizedText = handwritingData.recognizedText
                    self?.textElements = handwritingData.textElements
                case .failure(let error):
                    self?.recognitionError = error
                }
            }
        }
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
        recognitionDelay = max(0.1, min(5.0, delay))
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
    }
    
    private func saveRecognizedText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Auto-save recognized text to meeting if enabled
        if autoRecognitionEnabled {
            saveToMeeting()
        }
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .handwritingRecognized,
            object: self,
            userInfo: ["text": text, "meetingId": meetingId as Any]
        )
    }
    
    private func loadUserPreferences() {
        let defaults = UserDefaults.standard
        
        autoRecognitionEnabled = defaults.bool(forKey: "handwriting.autoRecognition") 
        recognitionDelay = defaults.double(forKey: "handwriting.recognitionDelay")
        minimumConfidence = defaults.float(forKey: "handwriting.minimumConfidence")
        allowsFingerDrawing = defaults.bool(forKey: "handwriting.allowsFingerDrawing")
        showRecognitionPreview = defaults.bool(forKey: "handwriting.showRecognitionPreview")
        
        // Set defaults if not previously set
        if recognitionDelay == 0 { recognitionDelay = 1.0 }
        if minimumConfidence == 0 { minimumConfidence = 0.3 }
        if defaults.object(forKey: "handwriting.showRecognitionPreview") == nil { showRecognitionPreview = true }
    }
    
    private func saveUserPreferences() {
        let defaults = UserDefaults.standard
        
        defaults.set(autoRecognitionEnabled, forKey: "handwriting.autoRecognition")
        defaults.set(recognitionDelay, forKey: "handwriting.recognitionDelay")
        defaults.set(minimumConfidence, forKey: "handwriting.minimumConfidence")
        defaults.set(allowsFingerDrawing, forKey: "handwriting.allowsFingerDrawing")
        defaults.set(showRecognitionPreview, forKey: "handwriting.showRecognitionPreview")
    }
    
    // MARK: - Data Integration (Placeholder)
    
    private func saveMeetingHandwriting(
        meetingId: UUID,
        drawingData: Data,
        recognizedText: String,
        textElements: [TextElement]
    ) {
        // This would integrate with your Core Data or CloudKit implementation
        // For now, we'll just save to UserDefaults as a placeholder
        
        let handwritingData = HandwritingData(
            meetingId: meetingId,
            drawingData: drawingData,
            recognizedText: recognizedText,
            textElements: textElements,
            timestamp: Date()
        )
        
        // Save to persistent storage
        saveHandwritingData(handwritingData)
    }
    
    private func loadMeetingHandwriting(meetingId: UUID, completion: @escaping (Result<HandwritingData, Error>) -> Void) {
        // This would integrate with your Core Data or CloudKit implementation
        // For now, we'll just load from UserDefaults as a placeholder
        
        loadHandwritingData(for: meetingId, completion: completion)
    }
    
    private func saveHandwritingData(_ data: HandwritingData) {
        // Placeholder implementation - replace with actual data persistence
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "handwriting.\(data.meetingId)")
        }
    }
    
    private func loadHandwritingData(for meetingId: UUID, completion: @escaping (Result<HandwritingData, Error>) -> Void) {
        // Placeholder implementation - replace with actual data loading
        if let data = UserDefaults.standard.data(forKey: "handwriting.\(meetingId)"),
           let handwritingData = try? JSONDecoder().decode(HandwritingData.self, from: data) {
            completion(.success(handwritingData))
        } else {
            completion(.failure(HandwritingError.noDataFound))
        }
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