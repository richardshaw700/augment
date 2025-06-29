import Foundation
import CoreGraphics

// MARK: - Interaction Detection

class InteractionDetection {
    
    // MARK: - Interaction Type Assignment
    
    static func assignInteractionTypes(_ shapes: [ClassifiedShape], debug: Bool = false) -> [UIShapeCandidate] {
        return shapes.map { shape in
            let interactionType = determineInteraction(shape, debug: debug)
            
            return UIShapeCandidate(
                contour: shape.contour.path,
                boundingBox: shape.contour.boundingBox,
                type: shape.type,
                uiRole: shape.uiRole,
                interactionType: interactionType,
                confidence: shape.confidence,
                area: shape.contour.area,
                aspectRatio: shape.contour.aspectRatio,
                corners: extractKeyCorners(shape.contour),
                curvature: estimateCurvature(shape.contour)
            )
        }
    }
    
    // MARK: - Interaction Type Detection
    
    private static func determineInteraction(_ shape: ClassifiedShape, debug: Bool = false) -> InteractionType {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let role = shape.uiRole
        let area = shape.contour.area
        
        // Enhanced text input detection (optimized for search boxes and text fields)
        if isTextInputCandidate(shape, debug: debug) {
            return .textInput
        }
        
        // EDGE-DETECTED TEXT INPUT: Check if this might be a text input from edge detection
        if isEdgeDetectedTextInput(shape, debug: debug) {
            return .textInput
        }
        
        // FINE-TUNED BUTTON DETECTION for real interactive elements only
        
        // 1. Close/window control buttons (small circles in top-left corner)
        if type == .circle && area >= 100 && area <= 800 && isInTopCorner(bounds) {
            return .closeButton
        }
        
        // 2. Main action buttons (reasonable size, typically rectangular-ish)
        if role == .button && area >= 1000 && area <= 10000 {
            return .button
        }
        
        // 3. Icon buttons (medium-sized circles or squares, not tiny artifacts)
        if (type == .circle || type == .irregular) && 
           area >= 600 && area <= 3000 && // Increased minimum to filter false positives
           bounds.width >= 20 && bounds.height >= 20 && // Increased minimum clickable size
           role == .icon {
            
            // FILTER OUT: Small circular false positives (common artifacts)
            if type == .circle && area < 1500 && bounds.width < 40 && bounds.height < 40 {
                return .unknown // Filter out small circles
            }
            
            return .iconButton
        }
        
        // Dropdown detection (rectangle with specific aspect ratio)
        if type == .rectangle && shape.contour.aspectRatio > 2.0 && shape.contour.aspectRatio < 5.0 {
            return .dropdown
        }
        
        return .unknown
    }
    
    // MARK: - Interactive Element Filtering
    
    static func filterForInteractiveElements(_ candidates: [UIShapeCandidate]) -> [UIShapeCandidate] {
        return candidates.filter { candidate in
            // SPECIALIZED DETECTORS: Only keep text inputs and buttons
            switch candidate.interactionType {
            case .textInput:
                return true  // TEXT INPUT SPECIALTY: Always keep text inputs
            case .button, .iconButton, .closeButton:
                return true  // BUTTON SPECIALTY: Keep all button types
            case .dropdown:
                return false // Skip dropdowns for now - not in our specialties
            case .menuButton:
                return false // Skip menu buttons for now - not in our specialties
            case .slider, .toggle, .tab:
                return false // Skip other elements for now - not in our specialties
            case .unknown:
                return false // Skip unknown elements
            }
        }
    }
    
    // MARK: - Text Input Detection
    
    private static func isTextInputCandidate(_ shape: ClassifiedShape, debug: Bool = false) -> Bool {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let aspectRatio = shape.contour.aspectRatio
        let area = shape.contour.area
        
        // DEBUG: Print all potential candidates for analysis
        if debug {
            print("🔍 DEBUG: Analyzing potential text input - type: \(type.rawValue), aspect: \(String(format: "%.1f", aspectRatio)), size: \(Int(bounds.width))x\(Int(bounds.height)), area: \(Int(area)), center: (\(Int(bounds.midX)), \(Int(bounds.midY)))")
        }
        
        // Note: Google search box may be too subtle for contour detection
        // but accessibility system typically handles it well
        
        // ENHANCED TEXT INPUT DETECTION for modern search boxes
        
        // 1. Classic wide rectangles (traditional input fields)
        if type == .rectangle && aspectRatio > 3.0 && bounds.height >= 20 && bounds.height <= 60 {
            return true
        }
        
        // 2. Rounded rectangles (modern search boxes like Google)
        if type == .roundedRectangle && aspectRatio > 2.5 && bounds.height >= 25 && bounds.height <= 80 {
            return true
        }
        
        // 3. Large irregular shapes that are wide and in center area (Google-style search)
        if type == .irregular && 
           aspectRatio > 2.0 && // More flexible aspect ratio
           bounds.height >= 30 && bounds.height <= 120 && // Larger height range for modern search boxes
           area >= 5000 && // Minimum size for main search boxes
           isInCenterArea(bounds) { // Must be in center area of screen
            return true
        }
        
        // 4. Medium irregular shapes that are very wide (alternative search box styles)
        if type == .irregular && 
           aspectRatio > 4.0 && // Very wide
           bounds.height >= 20 && bounds.height <= 80 && 
           area >= 2000 {
            return true
        }
        
        return false
    }
    
    private static func isEdgeDetectedTextInput(_ shape: ClassifiedShape, debug: Bool = false) -> Bool {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let aspectRatio = shape.contour.aspectRatio
        let width = bounds.width
        let height = bounds.height
        
        // EdgeDetectionEngine-inspired criteria for text inputs
        let minWidth: CGFloat = 50
        let maxWidth: CGFloat = 800
        let minHeight: CGFloat = 15
        let maxHeight: CGFloat = 100
        let minAspectRatio: CGFloat = 1.5  // At least 1.5:1 width to height
        let maxAspectRatio: CGFloat = 20.0 // But not extremely wide
        
        // Basic size and aspect ratio check
        guard width >= minWidth && width <= maxWidth &&
              height >= minHeight && height <= maxHeight &&
              aspectRatio >= minAspectRatio && aspectRatio <= maxAspectRatio else {
            return false
        }
        
        // Prefer rectangles and rounded rectangles for text inputs
        guard type == .rectangle || type == .roundedRectangle || type == .irregular else {
            return false
        }
        
        // Debug output for edge-detected candidates
        if debug {
            print("🔍 DEBUG: Edge-detected text input candidate - type: \(type.rawValue), aspect: \(String(format: "%.1f", aspectRatio)), size: \(Int(width))x\(Int(height))")
        }
        
        // Additional criteria for high-confidence detection
        if aspectRatio > 4.0 && width > 200 && height > 25 && height < 80 {
            if debug {
                print("✅ DEBUG: High-confidence text input detected!")
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Helper Methods
    
    private static func extractKeyCorners(_ contour: ShapeContour) -> [CGPoint] {
        let bounds = contour.boundingBox
        
        // For now, return bounding box corners
        // TODO: Could be enhanced to find actual path corners
        return [
            CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
            CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
            CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
            CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
        ]
    }
    
    private static func estimateCurvature(_ contour: ShapeContour) -> Double {
        // Simple curvature estimation based on point count vs perimeter
        let boundingPerimeter = 2 * (contour.boundingBox.width + contour.boundingBox.height)
        let complexityRatio = Double(contour.pointCount) / Double(boundingPerimeter)
        return min(1.0, complexityRatio * 100) // Normalize to 0-1
    }
    
    private static func isInTopCorner(_ bounds: CGRect) -> Bool {
        return bounds.minY < 100 && (bounds.minX < 100 || bounds.maxX > bounds.width - 100)
    }
    
    private static func isInCenterArea(_ bounds: CGRect) -> Bool {
        // Check if element is in the center portion of the window (for main search boxes)
        // Note: This function needs window frame context to work properly
        // For now, we'll use the bounds themselves to determine relative position
        let centerY = bounds.midY
        
        // Without window context, we can't determine absolute center area
        // This is a limitation that should be addressed by passing window frame
        // For now, assume elements with reasonable Y coordinates are potentially in center
        return centerY > 100 && centerY < 800 // Very rough approximation
    }
}