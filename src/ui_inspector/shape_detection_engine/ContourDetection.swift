import Foundation
import AppKit
import Vision
import CoreImage

// MARK: - Contour Detection

class ContourDetection {
    
    // MARK: - Main Contour Detection
    
    static func detectContours(
        _ cgImage: CGImage, 
        imageSize: CGSize, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ShapeContour] {
        if debug {
            print("🔍 DEBUG: Creating CIImage from CGImage...")
        }
        let ciImage = CIImage(cgImage: cgImage)
        
        // Create contour detection request
        if debug {
            print("🔍 DEBUG: Setting up VNDetectContoursRequest...")
        }
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0      // Enhance contrast for better detection
        request.maximumImageDimension = 1024   // Balance performance vs accuracy
        
        if debug {
            print("🔍 DEBUG: Creating VNImageRequestHandler...")
        }
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        do {
            if debug {
                print("🔍 DEBUG: Performing contour detection request...")
            }
            try handler.perform([request])
            
            guard let observations = request.results else {
                if debug {
                    print("🔍 DEBUG: No observations returned from contour detection")
                }
                return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            if debug {
                print("🔍 DEBUG: Got \(observations.count) contour observations from Vision")
            }
            
            // Convert observations to our format
            let shapes = observations.flatMap { observation in
                convertContoursToShapes(observation, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            if debug {
                print("🔍 DEBUG: Converted to \(shapes.count) shape contours")
            }
            
            if shapes.isEmpty {
                if debug {
                    print("🔍 DEBUG: No shapes after conversion, trying rectangle fallback...")
                }
                return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            return shapes
            
        } catch {
            print("❌ Contour detection failed: \(error)")
            
            // Fallback to rectangle detection if contours fail
            if debug {
                print("🔍 DEBUG: Falling back to rectangle detection due to error...")
            }
            return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
        }
    }
    
    // MARK: - Contour Conversion
    
    private static func convertContoursToShapes(
        _ observation: VNContoursObservation, 
        imageSize: CGSize, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ShapeContour] {
        var shapes: [ShapeContour] = []
        var potentialSearchBoxes: [CGRect] = []
        
        if debug {
            print("🔍 DEBUG: Converting contour observation with \(observation.contourCount) contours")
        }
        
        // Process each contour
        for contourIndex in 0..<observation.contourCount {
            if debug {
                print("🔍 DEBUG: Processing contour \(contourIndex + 1)/\(observation.contourCount)")
            }
            do {
                let contour = try observation.contour(at: contourIndex)
                
                // Convert normalized path to window coordinates
                let windowPath = convertNormalizedPath(contour.normalizedPath, imageSize: imageSize, windowFrame: windowFrame)
                let boundingBox = windowPath.boundingBox
                
                // Track potential search boxes (wide rectangles in center area)
                let aspectRatio = boundingBox.width / boundingBox.height
                if aspectRatio > 2.0 && boundingBox.width > 100 && boundingBox.height > 20 {
                    potentialSearchBoxes.append(boundingBox)
                    if debug {
                        print("🔍 DEBUG: POTENTIAL SEARCH BOX - Contour \(contourIndex): \(Int(boundingBox.width))x\(Int(boundingBox.height)) at (\(Int(boundingBox.origin.x)), \(Int(boundingBox.origin.y))) - aspect: \(String(format: "%.1f", aspectRatio))")
                    }
                }
                
                // Filter out tiny or huge shapes
                guard isValidShapeSize(boundingBox, debug: debug) else { 
                    if debug {
                        print("🔍 DEBUG: Contour \(contourIndex) filtered out by size validation")
                    }
                    continue 
                }
                
                let shapeContour = ShapeContour(
                    path: windowPath,
                    boundingBox: boundingBox,
                    pointCount: contour.pointCount,
                    aspectRatio: boundingBox.width / boundingBox.height,
                    area: boundingBox.width * boundingBox.height,
                    confidence: 0.8 // Base confidence for contour detection
                )
                
                shapes.append(shapeContour)
                
            } catch {
                print("⚠️ Failed to process contour \(contourIndex): \(error)")
            }
        }
        
        if debug && !potentialSearchBoxes.isEmpty {
            print("🔍 DEBUG: Found \(potentialSearchBoxes.count) potential search box candidates (before size filtering)")
            for (index, box) in potentialSearchBoxes.enumerated() {
                print("   Candidate \(index + 1): \(Int(box.width))x\(Int(box.height)) at (\(Int(box.origin.x)), \(Int(box.origin.y)))")
            }
        }
        
        return shapes
    }
    
    // MARK: - Path Conversion
    
    private static func convertNormalizedPath(
        _ normalizedPath: CGPath, 
        imageSize: CGSize, 
        windowFrame: CGRect
    ) -> CGPath {
        // First convert normalized coordinates (0-1) to image pixel coordinates
        var imageTransform = CGAffineTransform(scaleX: imageSize.width, y: imageSize.height)
        guard let imagePath = normalizedPath.copy(using: &imageTransform) else {
            return normalizedPath
        }
        
        // Then scale from high-res image coordinates to window coordinates
        let scaleX = windowFrame.width / imageSize.width
        let scaleY = windowFrame.height / imageSize.height
        
        // Apply scaling and translation to window coordinates
        var windowTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        windowTransform = windowTransform.translatedBy(x: windowFrame.origin.x / scaleX, y: windowFrame.origin.y / scaleY)
        
        return imagePath.copy(using: &windowTransform) ?? imagePath
    }
    
    // MARK: - Rectangle Fallback Detection
    
    private static func fallbackToRectangleDetection(
        _ cgImage: CGImage, 
        imageSize: CGSize, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ShapeContour] {
        if debug {
            print("🔄 DEBUG: Falling back to rectangle detection...")
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 20.0
        request.minimumSize = 0.01
        request.maximumObservations = 50
        request.minimumConfidence = 0.3
        
        if debug {
            print("🔍 DEBUG: Rectangle detection parameters:")
            print("   - minimumAspectRatio: \(request.minimumAspectRatio)")
            print("   - maximumAspectRatio: \(request.maximumAspectRatio)")
            print("   - minimumSize: \(request.minimumSize)")
            print("   - minimumConfidence: \(request.minimumConfidence)")
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        do {
            if debug {
                print("🔍 DEBUG: Performing rectangle detection...")
            }
            try handler.perform([request])
            
            guard let observations = request.results else { 
                if debug {
                    print("🔍 DEBUG: No rectangle observations returned")
                }
                return [] 
            }
            
            if debug {
                print("🔍 DEBUG: Got \(observations.count) rectangle observations")
            }
            
            let shapes = observations.map { observation in
                let rect = CGRect(
                    x: observation.boundingBox.origin.x * imageSize.width,
                    y: (1.0 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageSize.height,
                    width: observation.boundingBox.width * imageSize.width,
                    height: observation.boundingBox.height * imageSize.height
                )
                
                if debug {
                    print("🔍 DEBUG: Rectangle found - confidence: \(observation.confidence), size: \(Int(rect.width))x\(Int(rect.height))")
                }
                
                // Create rectangular path
                let path = CGPath(rect: rect, transform: nil)
                
                return ShapeContour(
                    path: path,
                    boundingBox: rect,
                    pointCount: 4,
                    aspectRatio: rect.width / rect.height,
                    area: rect.width * rect.height,
                    confidence: Double(observation.confidence)
                )
            }
            
            if debug {
                print("🔍 DEBUG: Rectangle detection created \(shapes.count) shape contours")
            }
            return shapes
            
        } catch {
            print("❌ Fallback rectangle detection failed: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private static func isValidShapeSize(_ bounds: CGRect, debug: Bool) -> Bool {
        let area = bounds.width * bounds.height
        let isValid = area > 40 && area < 100000 && // Reasonable size range (40px = small button height)
                     bounds.width > 5 && bounds.height > 5 && // Minimum dimensions
                     bounds.width < 2000 && bounds.height < 2000 // Maximum dimensions
        
        if !isValid && debug {
            print("🔍 DEBUG: Shape filtered out - size: \(Int(bounds.width))x\(Int(bounds.height)), area: \(Int(area))")
        }
        
        return isValid
    }
}