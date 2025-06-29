import Foundation
import CoreGraphics

// MARK: - Shape Classification System

class ShapeClassification {
    
    // MARK: - Main Classification
    
    static func classifyShapes(_ contours: [ShapeContour]) -> [ClassifiedShape] {
        return contours.map { contour in
            let type = determineShapeType(contour)
            let uiRole = inferUIRole(type, contour)
            let confidence = calculateShapeConfidence(type, uiRole, contour)
            
            return ClassifiedShape(
                contour: contour,
                type: type,
                uiRole: uiRole,
                confidence: confidence
            )
        }
    }
    
    // MARK: - Shape Type Detection
    
    private static func determineShapeType(_ contour: ShapeContour) -> ShapeType {
        let aspectRatio = contour.aspectRatio
        let pointCount = contour.pointCount
        let area = contour.area
        
        // Analyze shape characteristics
        let isSquarish = abs(aspectRatio - 1.0) < 0.3
        let isWide = aspectRatio > 2.0
        let isTall = aspectRatio < 0.5
        
        // Circle detection (compact, roughly square, many points for smooth curves)
        if isSquarish && pointCount > 12 && area > 200 {
            return .circle
        }
        
        // Rectangle detection (4 corners, reasonable aspect ratio)
        if pointCount <= 8 && (isWide || isTall || isSquarish) {
            // Check if it has rounded corners by analyzing curvature
            let curvature = estimateCurvature(contour)
            if curvature > 0.3 {
                return .roundedRectangle
            } else {
                return .rectangle
            }
        }
        
        // Line/border detection (very wide or very tall)
        if aspectRatio > 10.0 || aspectRatio < 0.1 {
            return .line
        }
        
        // Default to irregular for complex shapes
        return .irregular
    }
    
    // MARK: - UI Role Inference
    
    private static func inferUIRole(_ type: ShapeType, _ contour: ShapeContour) -> UIRole {
        let area = contour.area
        let aspectRatio = contour.aspectRatio
        let bounds = contour.boundingBox
        
        // Calculate relative thresholds based on container size for better scaling
        let containerArea = bounds.width * bounds.height
        let relativeArea = area / max(containerArea, 1.0) // Prevent division by zero
        
        switch type {
        case .circle:
            if relativeArea < 0.01 || area < 500 {  // Very small relative to container or absolutely small
                return .icon       // Small circles = icons/icon buttons
            } else if relativeArea < 0.05 || area < 4000 {  // Medium relative to container
                return .button     // Medium circles = buttons
            } else {
                return .decoration // Large circles = decorative
            }
            
        case .rectangle:
            if aspectRatio > 3.0 && (bounds.height < bounds.width * 0.1 || bounds.height < 60) {
                return .inputField // Wide, short rectangles = input fields
            } else if (relativeArea < 0.08 || area < 10000) && aspectRatio < 3.0 {
                return .button     // Square-ish rectangles = buttons
            } else {
                return .container  // Large rectangles = containers
            }
            
        case .roundedRectangle:
            if relativeArea < 0.06 || area < 8000 {  // Medium relative size
                return .button     // Rounded rectangles = modern buttons
            } else {
                return .container  // Large rounded = containers
            }
            
        case .line:
            return .decoration     // Lines are usually decorative
            
        case .irregular:
            if area < 2000 {
                return .icon       // Small irregular = icons
            } else {
                return .decoration // Large irregular = decorative
            }
        }
    }
    
    // MARK: - Confidence Calculation
    
    private static func calculateShapeConfidence(_ type: ShapeType, _ role: UIRole, _ contour: ShapeContour) -> Double {
        var confidence = contour.confidence
        
        // Boost confidence for likely UI elements
        switch (type, role) {
        case (.circle, .button), (.circle, .icon):
            confidence += 0.2
        case (.rectangle, .inputField):
            confidence += 0.3
        case (.roundedRectangle, .button):
            confidence += 0.25
        default:
            break
        }
        
        // Penalize very small or very large elements
        let area = contour.area
        if area < 100 || area > 50000 {
            confidence -= 0.2
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    // MARK: - Shape Filtering
    
    static func filterForUIElements(_ shapes: [ClassifiedShape], debug: Bool = false) -> [ClassifiedShape] {
        let filtered = shapes.filter { shape in
            let bounds = shape.contour.boundingBox
            let aspectRatio = shape.contour.aspectRatio
            
            // DEBUG: Print all shapes being considered for UI filtering
            if debug && bounds.width > 50 && aspectRatio > 1.5 { // Only print potentially interesting shapes
                print("🔍 DEBUG: UI Filter candidate - role: \(shape.uiRole.rawValue), type: \(shape.type.rawValue), confidence: \(String(format: "%.2f", shape.confidence)), size: \(Int(bounds.width))x\(Int(bounds.height))")
            }
            
            // Lowered confidence thresholds to capture more UI elements
            switch shape.uiRole {
            case .button, .inputField, .icon:
                return shape.confidence > 0.2  // Lowered from 0.3 for small icons and window controls
            case .container:
                return shape.confidence > 0.4 && shape.contour.area > 3000  // Lowered from 0.5
            case .decoration:
                return shape.confidence > 0.3 && isLikelyInteractiveDecoration(shape)  // Lowered from 0.6 for profile pics
            case .unknown:
                return shape.confidence > 0.5  // Lowered from 0.7
            }
        }.sorted { $0.confidence > $1.confidence }
        
        if debug {
            print("🔍 DEBUG: UI filtering kept \(filtered.count) out of \(shapes.count) shapes")
        }
        return filtered
    }
    
    // MARK: - Helper Methods
    
    private static func estimateCurvature(_ contour: ShapeContour) -> Double {
        // Simple curvature estimation based on point count vs perimeter
        let boundingPerimeter = 2 * (contour.boundingBox.width + contour.boundingBox.height)
        let complexityRatio = Double(contour.pointCount) / Double(boundingPerimeter)
        return min(1.0, complexityRatio * 100) // Normalize to 0-1
    }
    
    private static func isLikelyInteractiveDecoration(_ shape: ClassifiedShape) -> Bool {
        // Some decorations might be interactive (logos, profile pics, etc.)
        let bounds = shape.contour.boundingBox
        let area = shape.contour.area
        
        // Use relative positioning instead of hardcoded pixel values
        // Assume bounds are relative to some container - check relative positions
        let containerWidth = bounds.maxX > 0 ? bounds.maxX : 1000 // Fallback if we can't determine container
        let containerHeight = bounds.maxY > 0 ? bounds.maxY : 800 // Fallback if we can't determine container
        
        // Check if in typical interactive positions (relative to container)
        let isInTopCorner = bounds.minY < containerHeight * 0.15 && 
                           (bounds.minX < containerWidth * 0.15 || bounds.maxX > containerWidth * 0.85)
        let isInSidebar = bounds.minX < containerWidth * 0.25 || bounds.maxX > containerWidth * 0.75
        
        // Dynamic size ranges based on container size
        let minInteractiveArea = containerWidth * containerHeight * 0.0001 // 0.01% of container
        let maxInteractiveArea = containerWidth * containerHeight * 0.05   // 5% of container
        let isReasonableSize = area > minInteractiveArea && area < maxInteractiveArea
        
        // Profile pictures are often circular/rounded and in specific size ranges
        let profilePicMinArea = containerWidth * containerHeight * 0.0005 // 0.05% of container
        let profilePicMaxArea = containerWidth * containerHeight * 0.01   // 1% of container
        let isLikelyProfilePic = (shape.type == .circle || shape.type == .roundedRectangle) && 
                                area > profilePicMinArea && area < profilePicMaxArea
        
        return (isInTopCorner || isInSidebar || isLikelyProfilePic) && isReasonableSize
    }
}