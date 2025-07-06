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
    
    /// Clean up duplicates in all meetings (for existing users with duplication issues)
    func cleanupAllMeetingDuplicates() {
        guard let meetingStore = meetingStore else { return }
        
        print("🧹 [DEBUG] Starting cleanup of all meetings...")
        var totalCleaned = 0
        
        for meeting in meetingStore.meetings {
            let originalCount = meeting.handwritingData.textSegments.count
            if originalCount > 0 {
                cleanupDuplicatesInMeeting(meeting)
                // Refresh the meeting to get updated count
                if let updatedMeeting = meetingStore.meetings.first(where: { $0.id == meeting.id }) {
                    let newCount = updatedMeeting.handwritingData.textSegments.count
                    if newCount < originalCount {
                        totalCleaned += (originalCount - newCount)
                    }
                }
            }
        }
        
        print("🧹 [DEBUG] Cleanup complete: removed \(totalCleaned) duplicate segments")
        
        // Debug: Show summary of all meetings after cleanup
        print("\n📝 [DEBUG] === ALL MEETINGS AFTER CLEANUP ===")
        for meeting in meetingStore.meetings {
            if !meeting.handwritingData.textSegments.isEmpty {
                print("🖊️ [DEBUG] Meeting: '\(meeting.title)' - \(meeting.handwritingData.textSegments.count) segments")
                printSavedHandwritingDebug(meeting)
            }
        }
        print("🖊️ [DEBUG] =====================================\n")
    }
    
    /// Set recognized text (each recognition is treated as a separate segment)
    private func appendRecognizedText(_ newText: String) {
        guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let cleanNewText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🖊️ [DEBUG] === SETTING RECOGNIZED TEXT ===")
        print("🖊️ [DEBUG] New text: '\(cleanNewText)'")
        
        // Each recognition is treated as a separate line - don't combine
        // Just set the current recognized text to the new text
        recognizedText = cleanNewText
        print("🖊️ [DEBUG] Set recognized text: '\(cleanNewText)'")
        print("🖊️ [DEBUG] ===================================")
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
        
        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🖊️ [DEBUG] Recognized text is empty, not saving")
            return
        }
        
        // Debug: Show current saved text in file-like format
        printSavedHandwritingDebug(meeting)
        
        print("🖊️ [DEBUG] Found meeting: '\(meeting.title)'")
        print("🖊️ [DEBUG] Current handwritten notes: '\(meeting.handwritingData.allRecognizedText)'")
        
        var updatedMeeting = meeting
        
        // Check if this text already exists to prevent duplicates
        let newTextSegment = HandwritingTextSegment(
            recognizedText: recognizedText,
            confidence: 0.85,
            boundingBox: .zero,
            timestamp: Date().timeIntervalSince1970,
            pageIndex: 0
        )
        
        // Check for duplicates and similar text
        let isDuplicate = updatedMeeting.handwritingData.textSegments.contains { segment in
            let similarity = calculateTextSimilarity(segment.recognizedText, recognizedText)
            return similarity > 0.8 // 80% similarity threshold
        }
        
        if !isDuplicate {
            // Remove any segments that are substrings of the new text (improved versions)
            let removedSegments = updatedMeeting.handwritingData.textSegments.filter { segment in
                recognizedText.contains(segment.recognizedText) && 
                segment.recognizedText.count < recognizedText.count &&
                segment.recognizedText.count > 5 // Don't remove very short text
            }
            
            updatedMeeting.handwritingData.textSegments.removeAll { segment in
                recognizedText.contains(segment.recognizedText) && 
                segment.recognizedText.count < recognizedText.count &&
                segment.recognizedText.count > 5 // Don't remove very short text
            }
            
            // Debug: Show what segments were removed
            for removed in removedSegments {
                print("🖊️ [DEBUG] Removed shorter segment: '\(removed.recognizedText)'")
            }
            
            // Save each recognition as a separate segment - don't try to split
            // Each recognition call should be treated as a separate line
            print("🖊️ [DEBUG] Saving recognition as separate segment: '\(recognizedText)'")
            
            updatedMeeting.handwritingData.textSegments.append(newTextSegment)
            print("🖊️ [DEBUG] Added new segment: '\(recognizedText)'")
            
            print("🖊️ [DEBUG] New segments timestamp: \(Date(timeIntervalSince1970: newTextSegment.timestamp).formatted(date: .omitted, time: .standard))")
        } else {
            print("🖊️ [DEBUG] Skipping duplicate text: '\(recognizedText)'")
        }
        
        // Also save drawing data to the meeting (with deduplication)
        let drawingData = currentDrawing.dataRepresentation()
        let currentTime = Date().timeIntervalSince1970
        
        // Only add drawing if it's significantly different from the last one
        let shouldAddDrawing = updatedMeeting.handwritingData.drawings.isEmpty || {
            guard let lastDrawing = updatedMeeting.handwritingData.drawings.last else { return true }
            
            // Check if enough time has passed (at least 30 seconds)
            let timeDiff = currentTime - lastDrawing.timestamp
            if timeDiff < 30 { return false }
            
            // Check if drawing has significantly more strokes
            let lastStrokeCount = (try? PKDrawing(data: lastDrawing.drawingData ?? Data()))?.strokes.count ?? 0
            let currentStrokeCount = currentDrawing.strokes.count
            return currentStrokeCount > lastStrokeCount + 3 // At least 3 more strokes
        }()
        
        if shouldAddDrawing {
            var drawingObject = HandwritingDrawing(
                boundingBox: .zero,
                timestamp: currentTime,
                pageIndex: 0,
                title: "Handwriting \(Date().formatted(date: .omitted, time: .shortened))"
            )
            drawingObject.drawingData = drawingData
            updatedMeeting.handwritingData.drawings.append(drawingObject)
            print("🖊️ [DEBUG] Added new drawing data")
        } else {
            print("🖊️ [DEBUG] Skipping similar drawing data")
        }
        
        meetingStore.updateMeeting(updatedMeeting)
        
        print("✅ [DEBUG] Saved handwriting to meeting")
        print("🖊️ [DEBUG] Total text segments: \(updatedMeeting.handwritingData.textSegments.count)")
        
        // Debug: Show updated saved text in file-like format
        printSavedHandwritingDebug(updatedMeeting)
    }
    
    /// Print saved handwriting text in a file-like format for debugging
    private func printSavedHandwritingDebug(_ meeting: Meeting) {
        print("\n📝 [DEBUG] === SAVED HANDWRITING TEXT (File View) ===")
        print("🖊️ [DEBUG] Meeting: '\(meeting.title)'")
        print("🖊️ [DEBUG] Total segments: \(meeting.handwritingData.textSegments.count)")
        print("🖊️ [DEBUG] ============================================")
        
        if meeting.handwritingData.textSegments.isEmpty {
            print("🖊️ [DEBUG] (No handwriting text saved)")
        } else {
            // Group segments by time proximity to avoid breaking single inputs
            let groupedSegments = groupSegmentsByProximity(meeting.handwritingData.textSegments)
            
            for (index, group) in groupedSegments.enumerated() {
                let lineNumber = String(format: "%3d", index + 1)
                let combinedText = group.map { $0.recognizedText }.joined(separator: " ")
                let timestamp = Date(timeIntervalSince1970: group.first?.timestamp ?? 0)
                let timeString = timestamp.formatted(date: .omitted, time: .standard)
                
                print("🖊️ [DEBUG] \(lineNumber): [\(timeString)] \(combinedText)")
            }
        }
        
        print("🖊️ [DEBUG] ============================================")
        print("🖊️ [DEBUG] Final combined text (line breaks only between separate inputs):")
        let formattedText = meeting.handwritingData.allRecognizedText
        let lines = formattedText.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                print("🖊️ [DEBUG]   Line \(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        print("🖊️ [DEBUG] ============================================\n")
    }
    

    
    /// Group handwriting segments by time proximity to avoid breaking single inputs
    private func groupSegmentsByProximity(_ segments: [HandwritingTextSegment]) -> [[HandwritingTextSegment]] {
        guard !segments.isEmpty else { return [] }
        
        // Sort segments by timestamp
        let sortedSegments = segments.sorted { $0.timestamp < $1.timestamp }
        var groups: [[HandwritingTextSegment]] = []
        var currentGroup: [HandwritingTextSegment] = []
        
        let proximityThreshold: TimeInterval = 10.0 // 10 seconds
        
        for segment in sortedSegments {
            if currentGroup.isEmpty {
                currentGroup = [segment]
            } else {
                let lastTimestamp = currentGroup.last?.timestamp ?? 0
                let timeDifference = segment.timestamp - lastTimestamp
                
                if timeDifference <= proximityThreshold {
                    // Add to current group (same input session)
                    currentGroup.append(segment)
                } else {
                    // Start new group (different input session)
                    groups.append(currentGroup)
                    currentGroup = [segment]
                }
            }
        }
        
        // Add the last group
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// Calculate text similarity between two strings (0.0 = no similarity, 1.0 = identical)
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let clean1 = text1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clean2 = text2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        print("🖊️ [DEBUG] Calculating similarity between:")
        print("🖊️ [DEBUG]   Text 1: '\(clean1)'")
        print("🖊️ [DEBUG]   Text 2: '\(clean2)'")
        
        if clean1 == clean2 { 
            print("🖊️ [DEBUG]   Result: 1.0 (identical)")
            return 1.0 
        }
        if clean1.isEmpty || clean2.isEmpty { 
            print("🖊️ [DEBUG]   Result: 0.0 (one is empty)")
            return 0.0 
        }
        
        // Check if one is a substring of the other
        if clean1.contains(clean2) || clean2.contains(clean1) {
            let shorter = min(clean1.count, clean2.count)
            let longer = max(clean1.count, clean2.count)
            let result = Double(shorter) / Double(longer)
            print("🖊️ [DEBUG]   Result: \(result) (substring match: \(shorter)/\(longer))")
            return result
        }
        
        // Simple word-based similarity
        let words1 = Set(clean1.components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(clean2.components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        let result = union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
        print("🖊️ [DEBUG]   Result: \(result) (word match: \(intersection.count)/\(union.count))")
        return result
    }
    
    /// Load drawing and recognized text from a meeting
    func loadFromMeeting(meetingId: UUID) {
        self.meetingId = meetingId
        
        guard let meetingStore = meetingStore,
              let meeting = meetingStore.meetings.first(where: { $0.id == meetingId }) else { 
            print("Cannot load: missing meetingStore or meeting")
            return 
        }
        
        // Clean up duplicates in existing data (auto-repair)
        cleanupDuplicatesInMeeting(meeting)
        
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
        
        // Debug: Show loaded handwriting text in file-like format
        printSavedHandwritingDebug(meeting)
    }
    
    /// Clean up duplicate text segments in a meeting (auto-repair for existing data)
    private func cleanupDuplicatesInMeeting(_ meeting: Meeting) {
        guard let meetingStore = meetingStore else { return }
        
        var updatedMeeting = meeting
        let originalCount = updatedMeeting.handwritingData.textSegments.count
        
        // Remove duplicates based on similarity
        var uniqueSegments: [HandwritingTextSegment] = []
        
        for segment in updatedMeeting.handwritingData.textSegments {
            let isDuplicate = uniqueSegments.contains { existing in
                let similarity = calculateTextSimilarity(existing.recognizedText, segment.recognizedText)
                return similarity > 0.8
            }
            
            if !isDuplicate {
                // Also check if this segment is a substring of any existing segment
                let isSubstring = uniqueSegments.contains { existing in
                    existing.recognizedText.contains(segment.recognizedText) && 
                    existing.recognizedText.count > segment.recognizedText.count
                }
                
                if !isSubstring {
                    // Remove any existing segments that are substrings of this one
                    uniqueSegments.removeAll { existing in
                        segment.recognizedText.contains(existing.recognizedText) &&
                        segment.recognizedText.count > existing.recognizedText.count &&
                        existing.recognizedText.count > 5
                    }
                    
                    uniqueSegments.append(segment)
                }
            }
        }
        
        if uniqueSegments.count != originalCount {
            updatedMeeting.handwritingData.textSegments = uniqueSegments
            meetingStore.updateMeeting(updatedMeeting)
            print("🧹 [DEBUG] Cleaned up duplicates: \(originalCount) → \(uniqueSegments.count) segments")
            
            // Debug: Show cleaned up text in file-like format
            printSavedHandwritingDebug(updatedMeeting)
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