import Foundation
import Vision
import AppKit

// MARK: - OCR Engine

class OCREngine: TextRecognition {
    func extractText(from image: NSImage) -> [OCRData] {
        return extractText(from: image, useAccurateMode: false)
    }
    
    func extractText(from image: NSImage, useAccurateMode: Bool = false) -> [OCRData] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to get CGImage from NSImage")
            return []
        }
        
        return performOCR(on: cgImage, useAccurateMode: useAccurateMode)
    }
    
    // MARK: - OCR Processing
    
    // High-performance batch OCR processing
    func extractTextBatch(from images: [NSImage]) -> [[OCRData]] {
        let dispatchGroup = DispatchGroup()
        var results: [[OCRData]] = Array(repeating: [], count: images.count)
        let resultsQueue = DispatchQueue(label: "com.ocrengine.results", attributes: .concurrent)
        
        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let ocrData = self.extractText(from: image)
                
                resultsQueue.async(flags: .barrier) {
                    results[index] = ocrData
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.wait()
        return results
    }
    
    private func performOCR(on cgImage: CGImage, useAccurateMode: Bool = false) -> [OCRData] {
        var ocrResults: [OCRData] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create OCR request with optimized completion handler
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("❌ OCR Error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            ocrResults = self?.processOCRObservationsOptimized(observations) ?? []
        }
        
        // Configure OCR request for optimal performance
        configureOCRRequest(request, useAccurateMode: useAccurateMode)
        
        // Perform OCR with background queue to avoid blocking main thread
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform OCR: \(error)")
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        return ocrResults
    }
    
    private func configureOCRRequest(_ request: VNRecognizeTextRequest, useAccurateMode: Bool = false) {
        // Use fast recognition for better performance (3x faster than .accurate)
        // When useAccurateMode is enabled, use accurate mode for better text detection
        if useAccurateMode {
            request.recognitionLevel = .accurate  // Slower but more thorough
        } else {
            request.recognitionLevel = .fast      // 3x faster
        }
        request.usesLanguageCorrection = true // Enable for better accuracy
        request.minimumTextHeight = Float(PerformanceConfig.minTextHeight) // Use config value for small UI text
        
        // Limit to primary language only for speed
        request.recognitionLanguages = ["en-US"]
        
        // Disable automatic language detection for speed
        request.automaticallyDetectsLanguage = false
        
        // Set custom words to nil to avoid processing overhead
        request.customWords = []
        
        // OCR configured for optimal accuracy while maintaining reasonable performance
    }
    
    private func processOCRObservationsOptimized(_ observations: [VNRecognizedTextObservation]) -> [OCRData] {
        // Simplified: just return what OCR finds above confidence threshold
        let minConfidence = Float(PerformanceConfig.minElementConfidence)
        
        var ocrElements: [OCRData] = []
        ocrElements.reserveCapacity(observations.count)
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let confidence = topCandidate.confidence
            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Only filter by confidence and non-empty text
            guard confidence > minConfidence && !text.isEmpty else {
                continue
            }
            
            ocrElements.append(OCRData(
                text: text,
                confidence: confidence,
                boundingBox: observation.boundingBox
            ))
        }
        
        return ocrElements
    }
    

    
    // Keep original method for debugging when needed
    private func processOCRObservations(_ observations: [VNRecognizedTextObservation]) -> [OCRData] {
        var ocrElements: [OCRData] = []
        
        print("🔤 Processing \(observations.count) text regions")
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            let bbox = observation.boundingBox
            
            // Debug output for all detected text (before filtering)
            if text.count > 2 {
                print("   OCR: '\(text)' (conf: \(String(format: "%.2f", confidence)), bbox: \(bbox))")
            }
            
            // Filter out low-confidence or empty text
            guard confidence > Float(PerformanceConfig.minElementConfidence),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if text.count > 2 {
                    print("     ❌ Filtered out: confidence \(confidence) < \(PerformanceConfig.minElementConfidence)")
                }
                continue
            }
            
            // Create OCR data with normalized bounding box
            let ocrData = OCRData(
                text: text,
                confidence: confidence,
                boundingBox: observation.boundingBox
            )
            
            ocrElements.append(ocrData)
        }
        
        return ocrElements
    }
    
    // MARK: - Text Processing
    
    func preprocessImage(_ image: NSImage) -> NSImage? {
        // Optional: Apply image preprocessing for better OCR results
        // This could include contrast enhancement, noise reduction, etc.
        
        guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            return nil
        }
        
        // For now, return the original image
        // Future enhancements could include:
        // - Contrast adjustment
        // - Noise reduction
        // - Sharpening
        // - Binarization
        
        return image
    }
    
    func filterTextElements(_ elements: [OCRData]) -> [OCRData] {
        // Simplified: no additional filtering beyond what OCR processing already did
        return elements
    }
    
    // MARK: - Coordinate Helpers
    
    func convertBoundingBox(_ boundingBox: CGRect, to windowFrame: CGRect) -> CGRect {
        // Convert Vision's normalized coordinates (0,0 at bottom-left)
        // to AppKit coordinates (0,0 at top-left) within the window frame
        
        let x = windowFrame.origin.x + (boundingBox.origin.x * windowFrame.width)
        let y = windowFrame.origin.y + ((1.0 - boundingBox.origin.y - boundingBox.height) * windowFrame.height)
        let width = boundingBox.width * windowFrame.width
        let height = boundingBox.height * windowFrame.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
} 