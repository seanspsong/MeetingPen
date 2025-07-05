import Foundation
import PencilKit
import Vision
import UIKit
import Combine

/// Service responsible for handwriting recognition using PencilKit and Vision Framework
class HandwritingRecognitionService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var recognizedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var recognitionError: Error?
    
    // MARK: - Private Properties
    var cancellables = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "handwriting.processing", qos: .userInitiated)
    private var recognitionCache: [String: String] = [:]
    private var recognitionAttemptCount = 0
    
    // MARK: - Recognition Configuration
    private let recognitionLanguages = ["en-US", "en-GB"] // Can be expanded
    private let minimumTextHeight: Float = 1.0  // Very small for finger drawings
    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate  // Try accurate for better results
    
    // MARK: - Public Methods
    
    /// Recognize text from a PencilKit drawing
    /// - Parameters:
    ///   - drawing: The PKDrawing containing handwritten strokes
    ///   - completion: Completion handler with recognized text or error
    func recognizeText(from drawing: PKDrawing, completion: @escaping (Result<String, Error>) -> Void) {
        recognizeText(from: drawing, bypassCache: false, completion: completion)
    }
    
    /// Recognize text from a PencilKit drawing with cache control
    /// - Parameters:
    ///   - drawing: The PKDrawing containing handwritten strokes
    ///   - bypassCache: Whether to bypass the cache and force fresh recognition
    ///   - completion: Completion handler with recognized text or error
    func recognizeText(from drawing: PKDrawing, bypassCache: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔍 [DEBUG] HandwritingRecognitionService.recognizeText called (bypassCache: \(bypassCache))")
        print("🔍 [DEBUG] Drawing has \(drawing.strokes.count) strokes")
        
        guard !drawing.strokes.isEmpty else {
            print("🔍 [DEBUG] No strokes found, returning empty string")
            completion(.success(""))
            return
        }
        
        // Generate cache key based on drawing data
        let cacheKey = generateCacheKey(for: drawing)
        print("🔍 [DEBUG] Cache key: \(cacheKey)")
        
        // Check cache first (unless bypassing)
        if !bypassCache, let cachedText = recognitionCache[cacheKey] {
            print("🔍 [DEBUG] Found cached result: '\(cachedText)'")
            completion(.success(cachedText))
            return
        }
        
        if bypassCache {
            print("🔍 [DEBUG] Bypassing cache, forcing fresh recognition")
        } else {
            print("🔍 [DEBUG] No cached result, performing recognition on background queue")
        }
        
        processingQueue.async { [weak self] in
            self?.performTextRecognition(drawing: drawing, cacheKey: cacheKey, completion: completion)
        }
    }
    
    /// Recognize text from a specific region of a PencilKit drawing
    /// - Parameters:
    ///   - drawing: The PKDrawing containing handwritten strokes
    ///   - region: The CGRect region to analyze
    ///   - completion: Completion handler with recognized text or error
    func recognizeText(from drawing: PKDrawing, in region: CGRect, completion: @escaping (Result<String, Error>) -> Void) {
        
        processingQueue.async { [weak self] in
            // Create a new drawing with only strokes in the specified region
            let filteredDrawing = self?.filterDrawing(drawing, in: region) ?? drawing
            self?.performTextRecognition(drawing: filteredDrawing, cacheKey: nil, completion: completion)
        }
    }
    
    /// Real-time recognition for live handwriting feedback
    /// - Parameter drawing: The current PKDrawing state
    func performLiveRecognition(for drawing: PKDrawing) {
        // Debounce rapid changes
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(processLiveRecognition(_:)), object: drawing)
        perform(#selector(processLiveRecognition(_:)), with: drawing, afterDelay: 0.5)
    }
    
    /// Extract individual text elements (words/lines) from drawing
    /// - Parameters:
    ///   - drawing: The PKDrawing to analyze
    ///   - completion: Completion handler with array of text elements
    func extractTextElements(from drawing: PKDrawing, completion: @escaping (Result<[TextElement], Error>) -> Void) {
        
        processingQueue.async { [weak self] in
            self?.performTextElementExtraction(drawing: drawing, completion: completion)
        }
    }
    
    // MARK: - Private Methods
    
    private func performTextRecognition(drawing: PKDrawing, cacheKey: String?, completion: @escaping (Result<String, Error>) -> Void) {
        recognitionAttemptCount += 1
        print("🔍 [DEBUG] performTextRecognition called on background queue (attempt #\(recognitionAttemptCount))")
        
        do {
            print("🔍 [DEBUG] Converting drawing to image...")
            // Convert drawing to image
            let image = try convertDrawingToImage(drawing)
                    print("🔍 [DEBUG] Image conversion successful - size: \(image.width)x\(image.height)")
        
        // Save image for debugging (temporary)
        if let imageData = UIImage(cgImage: image).pngData() {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let debugImageURL = documentsPath.appendingPathComponent("debug_handwriting.png")
            try? imageData.write(to: debugImageURL)
            print("🔍 [DEBUG] Saved debug image to: \(debugImageURL.path)")
        }
        
        // Create completely fresh Vision request each time
            let request = VNRecognizeTextRequest { [weak self] request, error in
                print("🔍 [DEBUG] Vision request completed with \(request.results?.count ?? 0) results")
                self?.handleVisionResponse(request: request, error: error, cacheKey: cacheKey, completion: completion)
            }
            
            // Configure recognition settings for handwriting - more aggressive settings
            request.recognitionLevel = .accurate  // Use accurate for better results
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = false  // Disable for handwriting
            request.minimumTextHeight = 0.0  // Accept any size text
            
            // Additional optimizations for handwriting
            request.automaticallyDetectsLanguage = true  // Enable for better detection
            request.customWords = []  // Clear custom words
            
            // Use latest revision for best results
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3  // Latest revision
            }
            
            print("🔍 [DEBUG] Vision request configured - Level: accurate, MinHeight: 0.0, AutoLanguage: true")
            
            print("🔍 [DEBUG] Performing Vision recognition...")
            print("🔍 [DEBUG] Recognition level: \(recognitionLevel)")
            print("🔍 [DEBUG] Recognition languages: \(recognitionLanguages)")
            print("🔍 [DEBUG] Minimum text height: \(minimumTextHeight)")
            
            // Perform recognition with fresh handler each time
            print("🔍 [DEBUG] Creating fresh VNImageRequestHandler...")
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            print("🔍 [DEBUG] Performing Vision request...")
            try handler.perform([request])
            print("🔍 [DEBUG] Vision request submitted successfully")
            
        } catch {
            print("🔍 [DEBUG] Error in performTextRecognition: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    private func handleVisionResponse(request: VNRequest, error: Error?, cacheKey: String?, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔍 [DEBUG] handleVisionResponse called")
        
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("🔍 [DEBUG] Vision error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("🔍 [DEBUG] No text observations found")
                completion(.failure(HandwritingError.noTextFound))
                return
            }
            
            print("🔍 [DEBUG] Found \(observations.count) text observations")
            
            let recognizedText = self?.processObservations(observations) ?? ""
            print("🔍 [DEBUG] Processed observations result: '\(recognizedText)'")
            
            // Cache the result
            if let cacheKey = cacheKey {
                print("🔍 [DEBUG] Caching result with key: \(cacheKey)")
                self?.recognitionCache[cacheKey] = recognizedText
            }
            
            completion(.success(recognizedText))
        }
    }
    
    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> String {
        print("🔍 [DEBUG] processObservations called with \(observations.count) observations")
        var recognizedStrings: [String] = []
        
        for (index, observation) in observations.enumerated() {
            print("🔍 [DEBUG] Processing observation \(index + 1)")
            
            guard let topCandidate = observation.topCandidates(1).first else { 
                print("🔍 [DEBUG] No top candidate for observation \(index + 1)")
                continue 
            }
            
            print("🔍 [DEBUG] Top candidate: '\(topCandidate.string)' (confidence: \(topCandidate.confidence))")
            
            // Accept ALL results regardless of confidence for testing
            print("🔍 [DEBUG] Accepting all results (no confidence threshold)")
            recognizedStrings.append(topCandidate.string)
        }
        
        let result = recognizedStrings.joined(separator: " ")
        print("🔍 [DEBUG] Final recognized text: '\(result)'")
        return result
    }
    
    private func convertDrawingToImage(_ drawing: PKDrawing) throws -> CGImage {
        // Always use a fresh copy of the drawing to avoid state corruption
        let freshDrawing = (try? PKDrawing(data: drawing.dataRepresentation())) ?? drawing
        let bounds = freshDrawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 800, height: 600) : freshDrawing.bounds
        print("🔍 [DEBUG] Fresh drawing bounds: \(bounds)")
        print("🔍 [DEBUG] Fresh drawing bounds empty: \(freshDrawing.bounds.isEmpty)")
        print("🔍 [DEBUG] Fresh drawing strokes: \(freshDrawing.strokes.count)")
        
        let scale: CGFloat = 3.0 // Reasonable resolution to avoid memory issues
        
        // Add reasonable padding around the bounds for better recognition
        let padding: CGFloat = 50
        let paddedBounds = CGRect(
            x: bounds.origin.x - padding,
            y: bounds.origin.y - padding,
            width: bounds.size.width + (padding * 2),
            height: bounds.size.height + (padding * 2)
        )
        
        let scaledBounds = CGRect(
            x: paddedBounds.origin.x * scale,
            y: paddedBounds.origin.y * scale,
            width: paddedBounds.size.width * scale,
            height: paddedBounds.size.height * scale
        )
        
        // Create enhanced image with better contrast but more memory-efficient
        let enhancedImage = UIGraphicsImageRenderer(size: CGSize(width: scaledBounds.width, height: scaledBounds.height)).image { context in
            // Fill with pure white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: scaledBounds.width, height: scaledBounds.height)))
            
            // Get the original drawing (using fresh copy)
            let originalImage = freshDrawing.image(from: scaledBounds, scale: scale)
            
            // Draw with enhanced contrast - simplified approach to avoid memory issues
            context.cgContext.setBlendMode(.multiply)
            context.cgContext.setAlpha(1.0)
            
            // Draw just a few times to thicken strokes without causing crashes
            let offsets: [CGPoint] = [
                CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
                CGPoint(x: -1, y: 0),  CGPoint(x: 0, y: 0),  CGPoint(x: 1, y: 0),
                CGPoint(x: -1, y: 1),  CGPoint(x: 0, y: 1),  CGPoint(x: 1, y: 1)
            ]
            
            for offset in offsets {
                originalImage.draw(at: offset)
            }
        }
        
        guard let cgImage = enhancedImage.cgImage else {
            throw HandwritingError.imageConversionFailed
        }
        
        return cgImage
    }
    
    /// Clear the recognition cache and reset internal state
    func clearCache() {
        print("🔍 [DEBUG] Clearing recognition cache (\(recognitionCache.count) items)")
        recognitionCache.removeAll()
        
        // Force memory cleanup
        DispatchQueue.main.async {
            // Trigger garbage collection
            print("🔍 [DEBUG] Cache cleared, triggering cleanup")
        }
    }
    
    /// Reset the entire recognition service state
    func resetService() {
        print("🔍 [DEBUG] Resetting HandwritingRecognitionService (was at attempt #\(recognitionAttemptCount))")
        recognitionCache.removeAll()
        recognitionAttemptCount = 0
        recognizedText = ""
        isProcessing = false
        recognitionError = nil
        
        // Clear any pending operations
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        print("🔍 [DEBUG] Service reset complete")
    }
    
    private func generateCacheKey(for drawing: PKDrawing) -> String {
        // Create a hash based on drawing data and timestamp for better uniqueness
        let data = drawing.dataRepresentation()
        let timestamp = Date().timeIntervalSince1970
        let combinedData = "\(data.base64EncodedString())-\(timestamp)".data(using: .utf8) ?? data
        let cacheKey = combinedData.base64EncodedString().prefix(32).description
        print("🔍 [DEBUG] Generated cache key: \(cacheKey) from \(data.count) bytes + timestamp")
        return cacheKey
    }
    
    private func filterDrawing(_ drawing: PKDrawing, in region: CGRect) -> PKDrawing {
        let filteredStrokes = drawing.strokes.filter { stroke in
            let strokeBounds = stroke.renderBounds
            return region.intersects(strokeBounds)
        }
        
        return PKDrawing(strokes: filteredStrokes)
    }
    
    @objc private func processLiveRecognition(_ drawing: PKDrawing) {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = true
        }
        
        recognizeText(from: drawing) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let text):
                    self?.recognizedText = text
                case .failure(let error):
                    self?.recognitionError = error
                }
            }
        }
    }
    
    private func performTextElementExtraction(drawing: PKDrawing, completion: @escaping (Result<[TextElement], Error>) -> Void) {
        
        do {
            let image = try convertDrawingToImage(drawing)
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(.failure(HandwritingError.noTextFound))
                    return
                }
                
                let textElements = observations.compactMap { observation -> TextElement? in
                    guard let topCandidate = observation.topCandidates(1).first,
                          topCandidate.confidence > 0.3 else { return nil }
                    
                    return TextElement(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                
                completion(.success(textElements))
            }
            
            request.recognitionLevel = recognitionLevel
            request.recognitionLanguages = recognitionLanguages
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Supporting Types

/// Represents a recognized text element with metadata
struct TextElement {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Custom errors for handwriting recognition
enum HandwritingError: Error, LocalizedError {
    case noTextFound
    case imageConversionFailed
    case recognitionFailed
    case noDataFound
    
    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be recognized in the handwriting"
        case .imageConversionFailed:
            return "Failed to convert drawing to image"
        case .recognitionFailed:
            return "Text recognition failed"
        case .noDataFound:
            return "No handwriting data found"
        }
    }
}

// MARK: - Extensions

extension PKDrawing {
    /// Convert drawing to image with specified bounds and scale
    func imageWithWhiteBackground(from rect: CGRect, scale: CGFloat) -> UIImage {
        // Use PKDrawing's built-in method to create an image
        let drawingImage = self.image(from: rect, scale: scale)
        
        // Create a new image with white background
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            drawingImage.draw(at: .zero)
        }
    }
} 