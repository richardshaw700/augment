import Foundation
import AppKit

// MARK: - Coordinate System

class CoordinateSystem: CoordinateMapping {
    private let windowFrame: CGRect
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
    }
    
    // MARK: - Coordinate Normalization
    
    func normalize(_ point: CGPoint) -> NormalizedPoint {
        // Convert absolute screen coordinates to window-relative coordinates
        let relativeX = point.x - windowFrame.origin.x
        let relativeY = point.y - windowFrame.origin.y
        
        // Normalize to 0.0-1.0 range within the window bounds
        let normalizedX = Double(relativeX / windowFrame.width)
        let normalizedY = Double(relativeY / windowFrame.height)
        
        return NormalizedPoint(normalizedX, normalizedY)
    }
    
    // MARK: - Grid Mapping (REMOVED - using percentage coordinates)
    
    // MARK: - Coordinate Validation
    
    func isValidCoordinate(_ point: CGPoint) -> Bool {
        return point.x >= windowFrame.minX &&
               point.x <= windowFrame.maxX &&
               point.y >= windowFrame.minY &&
               point.y <= windowFrame.maxY
    }
    
    func clampToWindow(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: max(windowFrame.minX, min(windowFrame.maxX, point.x)),
            y: max(windowFrame.minY, min(windowFrame.maxY, point.y))
        )
    }
    
    // MARK: - OCR Coordinate Correction
    
    func correctOCRCoordinates(_ ocrData: OCRData) -> OCRData {
        // OCR bounding box is in normalized coordinates (0.0-1.0)
        // Convert to absolute window coordinates
        let bbox = ocrData.boundingBox
        
        let absoluteX = windowFrame.origin.x + (bbox.origin.x * windowFrame.width)
        let absoluteY = windowFrame.origin.y + (bbox.origin.y * windowFrame.height)
        let absoluteWidth = bbox.width * windowFrame.width
        let absoluteHeight = bbox.height * windowFrame.height
        
        let correctedBounds = CGRect(
            x: absoluteX,
            y: absoluteY,
            width: absoluteWidth,
            height: absoluteHeight
        )
        
        return OCRData(
            text: ocrData.text,
            confidence: ocrData.confidence,
            boundingBox: correctedBounds
        )
    }
    
    // MARK: - Accessibility Coordinate Validation
    
    func validateAccessibilityCoordinates(_ accData: AccessibilityData) -> AccessibilityData {
        guard let position = accData.position else { return accData }
        
        // Ensure accessibility coordinates are within window bounds
        let validatedPosition = clampToWindow(position)
        
        return AccessibilityData(
            role: accData.role,
            description: accData.description,
            title: accData.title,
            help: accData.help,
            enabled: accData.enabled,
            focused: accData.focused,
            position: validatedPosition,
            size: accData.size,
            element: accData.element,
            subrole: accData.subrole,
            value: accData.value,
            selected: accData.selected,
            parent: accData.parent,
            children: accData.children
        )
    }
    
    // MARK: - Spatial Correlation
    
    func spatialDistance(between point1: CGPoint, and point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    func isNearby(_ point1: CGPoint, _ point2: CGPoint, threshold: Double = 50.0) -> Bool {
        return spatialDistance(between: point1, and: point2) < threshold
    }
    
    // MARK: - Debug Information
    
    func debugCoordinateInfo(for point: CGPoint) -> [String: Any] {
        let normalized = normalize(point)
        
        return [
            "absolute": ["x": point.x, "y": point.y],
            "normalized": ["x": normalized.x, "y": normalized.y],
            "percentage": ["x": Int(normalized.x * 100), "y": Int(normalized.y * 100)],
            "windowFrame": [
                "x": windowFrame.origin.x,
                "y": windowFrame.origin.y,
                "width": windowFrame.width,
                "height": windowFrame.height
            ]
        ]
    }
}

// MARK: - Data Correction Extension

extension CoordinateSystem {
    /// Correct OCR coordinates from Vision framework to window-relative coordinates
    func correctOCRCoordinates(_ ocrElements: [OCRData], windowFrame: CGRect) -> [OCRData] {
        return ocrElements.map { ocrData in
            // Convert Vision's normalized coordinates to window-relative coordinates
            let bbox = ocrData.boundingBox
            
            // Vision coordinates: (0,0) at bottom-left, normalized
            // Convert to: window-relative absolute coordinates with (0,0) at top-left
            let absoluteX = windowFrame.origin.x + (bbox.origin.x * windowFrame.width)
            let absoluteY = windowFrame.origin.y + ((1.0 - bbox.origin.y - bbox.height) * windowFrame.height)
            let absoluteWidth = bbox.width * windowFrame.width
            let absoluteHeight = bbox.height * windowFrame.height
            
            let correctedBounds = CGRect(
                x: absoluteX,
                y: absoluteY,
                width: absoluteWidth,
                height: absoluteHeight
            )
            
            return OCRData(
                text: ocrData.text,
                confidence: ocrData.confidence,
                boundingBox: correctedBounds
            )
        }
    }
    
    /// Validate and correct accessibility coordinates
    func validateAccessibilityCoordinates(_ elements: [AccessibilityData]) -> [AccessibilityData] {
        return elements.map { element in
            validateAccessibilityCoordinates(element)
        }
    }
    
    /// Convert menu bar items to UI elements with proper coordinates
    func convertMenuBarItemsToUIElements(_ menuItems: [[String: Any]]) -> [UIElement] {
        var elements: [UIElement] = []
        
        for item in menuItems {
            guard let title = item["title"] as? String,
                  let actualPosition = item["actualPosition"] as? [String: Double],
                  let actualSize = item["actualSize"] as? [String: Double],
                  let x = actualPosition["x"],
                  let y = actualPosition["y"],
                  let width = actualSize["width"],
                  let height = actualSize["height"] else {
                print("⚠️ Skipping menu item '\(item["title"] ?? "unknown")' - missing real position/size data")
                continue
            }
            
            let index = item["index"] as? Int ?? 0
            
            let type = item["type"] as? String ?? "menu"
            let elementType = (type == "systemMenu") ? "systemMenu" : "appMenu"
            let isSystemWide = item["isSystemWide"] as? Bool ?? false
            
            let element = UIElement(
                id: UUID().uuidString,
                type: elementType,
                position: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                size: CGSize(width: CGFloat(width), height: CGFloat(height)),
                accessibilityData: nil,
                ocrData: nil,
                isClickable: true,
                confidence: 0.95, // High confidence for menu items
                semanticMeaning: "Menu bar item: \(title)",
                actionHint: "Click \(title)",
                visualText: title,
                interactions: ["click"],
                context: UIElement.ElementContext(
                    purpose: isSystemWide ? "System Control" : "App Navigation",
                    region: "MenuBar",
                    navigationPath: "MenuBar[\(index)] > \(title)",
                    availableActions: ["click"]
                )
            )
            
            elements.append(element)
        }
        
        return elements
    }
}

// MARK: - Adaptive Density Mapper (REMOVED - using percentage coordinates) 