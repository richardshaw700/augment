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
    
    private func performOCR(on cgImage: CGImage) -> [OCRData] {
        var ocrResults: [OCRData] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create OCR request
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("❌ OCR Error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ No OCR observations found")
                return
            }
            
            ocrResults = self?.processOCRObservations(observations) ?? []
        }
        
        // Configure OCR request for optimal performance
        configureOCRRequest(request)
        
        // Perform OCR
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
        } catch {
            print("❌ Failed to perform OCR: \(error)")
        }
        
        print("🔤 OCR extracted \(ocrResults.count) text elements")
        return ocrResults
    }
    
    private func configureOCRRequest(_ request: VNRecognizeTextRequest) {
        // Optimize for speed while maintaining accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01 // Detect small text
        
        // Set supported languages (English primarily, with fallbacks)
        request.recognitionLanguages = ["en-US", "en-GB"]
        
        // Enable automatic language detection
        request.automaticallyDetectsLanguage = true
    }
    
    private func processOCRObservations(_ observations: [VNRecognizedTextObservation]) -> [OCRData] {
        var ocrElements: [OCRData] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Filter out low-confidence or empty text
            guard confidence > Config.minElementConfidence,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
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
        return elements.filter { element in
            let text = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Filter out very short text (likely noise)
            guard text.count > 1 else { return false }
            
            // Filter out purely numeric strings (often noise)
            guard !text.allSatisfy({ $0.isNumber }) else { return false }
            
            // Filter out strings with only special characters
            guard text.contains(where: { $0.isLetter }) else { return false }
            
            // Filter out very low confidence text
            guard element.confidence > Config.minElementConfidence else { return false }
            
            return true
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