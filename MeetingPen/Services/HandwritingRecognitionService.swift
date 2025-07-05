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
    
    // MARK: - Recognition Configuration
    private let recognitionLanguages = ["en-US", "en-GB"] // Can be expanded
    private let minimumTextHeight: Float = 16.0
    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    
    // MARK: - Public Methods
    
    /// Recognize text from a PencilKit drawing
    /// - Parameters:
    ///   - drawing: The PKDrawing containing handwritten strokes
    ///   - completion: Completion handler with recognized text or error
    func recognizeText(from drawing: PKDrawing, completion: @escaping (Result<String, Error>) -> Void) {
        
        guard !drawing.strokes.isEmpty else {
            completion(.success(""))
            return
        }
        
        // Generate cache key based on drawing data
        let cacheKey = generateCacheKey(for: drawing)
        
        // Check cache first
        if let cachedText = recognitionCache[cacheKey] {
            completion(.success(cachedText))
            return
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
        
        do {
            // Convert drawing to image
            let image = try convertDrawingToImage(drawing)
            
            // Create Vision request
            let request = VNRecognizeTextRequest { [weak self] request, error in
                self?.handleVisionResponse(request: request, error: error, cacheKey: cacheKey, completion: completion)
            }
            
            // Configure recognition settings
            request.recognitionLevel = recognitionLevel
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = true
            request.minimumTextHeight = minimumTextHeight
            
            // Perform recognition
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    private func handleVisionResponse(request: VNRequest, error: Error?, cacheKey: String?, completion: @escaping (Result<String, Error>) -> Void) {
        
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(HandwritingError.noTextFound))
                return
            }
            
            let recognizedText = self?.processObservations(observations) ?? ""
            
            // Cache the result
            if let cacheKey = cacheKey {
                self?.recognitionCache[cacheKey] = recognizedText
            }
            
            completion(.success(recognizedText))
        }
    }
    
    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> String {
        var recognizedStrings: [String] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            // Filter out low-confidence results
            if topCandidate.confidence > 0.3 {
                recognizedStrings.append(topCandidate.string)
            }
        }
        
        return recognizedStrings.joined(separator: " ")
    }
    
    private func convertDrawingToImage(_ drawing: PKDrawing) throws -> CGImage {
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 800, height: 600) : drawing.bounds
        let scale: CGFloat = 2.0 // Higher resolution for better recognition
        
        let scaledBounds = CGRect(
            x: bounds.origin.x * scale,
            y: bounds.origin.y * scale,
            width: bounds.size.width * scale,
            height: bounds.size.height * scale
        )
        
        let image = drawing.imageWithWhiteBackground(from: scaledBounds, scale: scale)
        guard let cgImage = image.cgImage else {
            throw HandwritingError.imageConversionFailed
        }
        
        return cgImage
    }
    
    private func generateCacheKey(for drawing: PKDrawing) -> String {
        // Create a hash based on drawing data for caching
        let data = drawing.dataRepresentation()
        return data.base64EncodedString().prefix(32).description
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