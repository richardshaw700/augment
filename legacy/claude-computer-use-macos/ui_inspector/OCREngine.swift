import Foundation
import Vision
import AppKit

// MARK: - OCR Engine

class OCREngine: TextRecognition {
    func extractText(from image: NSImage) -> [OCRData] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to get CGImage from NSImage")
            return []
        }
        
        return performOCR(on: cgImage)
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
    
    private func performOCR(on cgImage: CGImage) -> [OCRData] {
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
        configureOCRRequest(request)
        
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
    
    private func configureOCRRequest(_ request: VNRecognizeTextRequest) {
        // Optimize for speed - use fast recognition for better performance
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false // Disable for speed
        request.minimumTextHeight = 0.01 // Slightly higher threshold for speed
        
        // Limit to primary language only for speed
        request.recognitionLanguages = ["en-US"]
        
        // Disable automatic language detection for speed
        request.automaticallyDetectsLanguage = false
        
        // Set custom words to nil to avoid processing overhead
        request.customWords = []
        
        // OCR configured for optimal speed while maintaining usable accuracy
    }
    
    private func processOCRObservationsOptimized(_ observations: [VNRecognizedTextObservation]) -> [OCRData] {
        // Performance optimization: Vectorized batch processing
        let minConfidence = Float(Config.minElementConfidence)
        
        // Pre-allocate result array with estimated capacity
        var ocrElements: [OCRData] = []
        ocrElements.reserveCapacity(observations.count / 2) // Estimate ~50% pass filter
        
        // Batch process observations with vectorized operations
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let confidence = topCandidate.confidence
            let text = topCandidate.string
            
            // Ultra-fast vectorized filtering: combine all checks in single pass
            guard confidence > minConfidence &&
                  text.count > 1 &&
                  !text.isEmpty &&
                  hasValidTextContent(text) else {
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
    
    private func hasValidTextContent(_ text: String) -> Bool {
        // Vectorized text validation - single pass through characters
        var hasLetter = false
        var charCount = 0
        
        for char in text {
            charCount += 1
            if char.isLetter {
                hasLetter = true
                break // Early termination on first letter found
            }
            if charCount > 10 { // Don't check extremely long strings
                break
            }
        }
        
        return hasLetter
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
            guard confidence > Float(Config.minElementConfidence),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if text.count > 2 {
                    print("     ❌ Filtered out: confidence \(confidence) < \(Config.minElementConfidence)")
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
        let minConfidence = Float(Config.minElementConfidence)
        
        return elements.filter { element in
            // Fast confidence check first
            guard element.confidence > minConfidence else { return false }
            
            let text = element.text
            
            // Fast length check
            guard text.count > 1 else { return false }
            
            // Check for letters without expensive string operations
            var hasLetter = false
            var isAllNumeric = true
            
            for char in text {
                if char.isLetter {
                    hasLetter = true
                    isAllNumeric = false
                } else if !char.isNumber && !char.isWhitespace {
                    isAllNumeric = false
                }
            }
            
            // Must have at least one letter and not be purely numeric
            return hasLetter && !isAllNumeric
        }
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