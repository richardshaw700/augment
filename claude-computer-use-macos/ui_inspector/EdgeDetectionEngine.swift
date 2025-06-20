import Foundation
import AppKit
import Vision
import CoreImage

// MARK: - Edge Detection Engine

class EdgeDetectionEngine {
    
    // MARK: - Input Field Detection
    
    func detectInputFields(in image: NSImage) -> [InputFieldCandidate] {
        print("🔍 DEBUG: Starting edge detection for input fields...")
        
        guard let cgImage = convertToCGImage(image) else {
            print("❌ Failed to convert NSImage to CGImage for edge detection")
            return []
        }
        
        // Step 1: Edge detection
        guard let edgeImage = performEdgeDetection(cgImage) else {
            print("❌ Edge detection failed")
            return []
        }
        
        // Step 2: Find rectangular regions
        let rectangularRegions = findRectangularRegions(in: edgeImage, originalSize: image.size)
        
        // Step 3: Filter for input field characteristics
        let inputFieldCandidates = filterForInputFields(rectangularRegions)
        
        print("🔍 DEBUG: Edge detection found \(inputFieldCandidates.count) input field candidates")
        
        return inputFieldCandidates
    }
    
    // MARK: - Edge Detection Processing
    
    private func performEdgeDetection(_ cgImage: CGImage) -> CIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        
        // Create edge detection filter
        guard let filter = CIFilter(name: "CIEdges") else {
            print("❌ Failed to create CIEdges filter")
            return nil
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputIntensityKey) // Edge detection intensity
        
        return filter.outputImage
    }
    
    private func findRectangularRegions(in edgeImage: CIImage, originalSize: CGSize) -> [CGRect] {
        // Use Vision framework to detect rectangles
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2  // Allow wide rectangles (typical for input fields)
        request.maximumAspectRatio = 20.0 // But not too wide
        request.minimumSize = 0.01        // Minimum size relative to image
        request.maximumObservations = 50  // Find up to 50 rectangles
        request.minimumConfidence = 0.3   // Lower confidence to catch more candidates
        
        let handler = VNImageRequestHandler(ciImage: edgeImage)
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results else {
                print("🔍 DEBUG: No rectangular observations found")
                return []
            }
            
            print("🔍 DEBUG: Found \(observations.count) rectangular regions")
            
            // Convert normalized coordinates to pixel coordinates
            return observations.compactMap { observation in
                let rect = observation.boundingBox
                return CGRect(
                    x: rect.origin.x * originalSize.width,
                    y: (1.0 - rect.origin.y - rect.height) * originalSize.height, // Flip Y coordinate
                    width: rect.width * originalSize.width,
                    height: rect.height * originalSize.height
                )
            }
            
        } catch {
            print("❌ Rectangle detection failed: \(error)")
            return []
        }
    }
    
    private func filterForInputFields(_ rectangles: [CGRect]) -> [InputFieldCandidate] {
        return rectangles.compactMap { rect in
            // Filter criteria for input fields
            let width = rect.width
            let height = rect.height
            let aspectRatio = width / height
            
            // Input field characteristics:
            // - Reasonable size (not too small, not too large)
            // - Wider than tall (typical input field aspect ratio)
            // - Minimum dimensions for usability
            
            let minWidth: CGFloat = 50
            let maxWidth: CGFloat = 800
            let minHeight: CGFloat = 15
            let maxHeight: CGFloat = 100
            let minAspectRatio: CGFloat = 1.5  // At least 1.5:1 width to height
            let maxAspectRatio: CGFloat = 20.0 // But not extremely wide
            
            guard width >= minWidth && width <= maxWidth &&
                  height >= minHeight && height <= maxHeight &&
                  aspectRatio >= minAspectRatio && aspectRatio <= maxAspectRatio else {
                return nil
            }
            
            // Calculate confidence based on how "input field-like" the dimensions are
            let idealAspectRatio: CGFloat = 8.0 // Typical search box ratio
            let aspectRatioScore = 1.0 - abs(aspectRatio - idealAspectRatio) / idealAspectRatio
            let aspectRatioConfidence = max(0.1, min(1.0, aspectRatioScore))
            
            let sizeScore = (width / maxWidth) * (height / maxHeight)
            let sizeConfidence = max(0.1, min(1.0, sizeScore))
            
            let overallConfidence = (aspectRatioConfidence + sizeConfidence) / 2.0
            
            return InputFieldCandidate(
                boundingBox: rect,
                confidence: overallConfidence,
                type: .textInput,
                characteristics: InputFieldCharacteristics(
                    aspectRatio: aspectRatio,
                    width: width,
                    height: height,
                    estimatedType: determineInputType(aspectRatio: aspectRatio, size: rect.size)
                )
            )
        }.sorted { $0.confidence > $1.confidence } // Sort by confidence
    }
    
    private func determineInputType(aspectRatio: CGFloat, size: CGSize) -> InputFieldType {
        if aspectRatio > 15 {
            return .searchBar
        } else if aspectRatio > 8 {
            return .textInput
        } else if aspectRatio > 3 {
            return .shortText
        } else {
            return .button
        }
    }
    
    // MARK: - Image Conversion
    
    private func convertToCGImage(_ nsImage: NSImage) -> CGImage? {
        guard let imageData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData) else {
            return nil
        }
        
        return bitmap.cgImage
    }
}

// MARK: - Data Models

struct InputFieldCandidate {
    let boundingBox: CGRect
    let confidence: Double
    let type: InputFieldType
    let characteristics: InputFieldCharacteristics
}

struct InputFieldCharacteristics {
    let aspectRatio: CGFloat
    let width: CGFloat
    let height: CGFloat
    let estimatedType: InputFieldType
}

enum InputFieldType: String {
    case textInput = "text_input"
    case searchBar = "search_bar"
    case shortText = "short_text"
    case button = "button"
    case textArea = "text_area"
}

// MARK: - Protocol Extension

extension EdgeDetectionEngine: VisualElementDetection {
    func detectVisualElements(in image: NSImage) -> [VisualElement] {
        let inputFields = detectInputFields(in: image)
        
        return inputFields.map { candidate in
            VisualElement(
                boundingBox: candidate.boundingBox,
                confidence: candidate.confidence,
                elementType: candidate.type.rawValue,
                isInteractive: true,
                visualDescription: "Detected \(candidate.type.rawValue) via edge detection"
            )
        }
    }
}

// MARK: - Visual Element Protocol

protocol VisualElementDetection {
    func detectVisualElements(in image: NSImage) -> [VisualElement]
}

struct VisualElement {
    let boundingBox: CGRect
    let confidence: Double
    let elementType: String
    let isInteractive: Bool
    let visualDescription: String
}