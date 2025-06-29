import Foundation
import AppKit

// MARK: - Deduplication

class Deduplication {
    private let coordinateSystem: CoordinateSystem
    
    init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
    }
    
    // MARK: - Public Methods
    
    func deduplicateElements(_ elements: [UIElement]) -> [UIElement] {
        var deduplicatedElements: [UIElement] = []
        
        for element in elements {
            // Check if this element is a duplicate of any already processed element
            let isDuplicate = deduplicatedElements.contains { existing in
                areElementsDuplicates(element, existing)
            }
            
            if !isDuplicate {
                deduplicatedElements.append(element)
            }
        }
        
        return deduplicatedElements
    }
    
    // MARK: - Private Helper Methods
    
    private func areElementsDuplicates(_ element1: UIElement, _ element2: UIElement) -> Bool {
        // Special handling for window control buttons (close, minimize, maximize)
        if areWindowControlButtons(element1, element2) {
            return areSimilarButtons(element1, element2)
        }
        
        // General spatial proximity check (≤5px distance)
        let distance = sqrt(
            pow(element1.position.x - element2.position.x, 2) +
            pow(element1.position.y - element2.position.y, 2)
        )
        
        guard distance <= 5.0 else { return false }
        
        // Size similarity check (≤20% difference)
        let size1 = element1.size
        let size2 = element2.size
        
        let widthDiff = abs(size1.width - size2.width) / max(size1.width, size2.width)
        let heightDiff = abs(size1.height - size2.height) / max(size1.height, size2.height)
        
        return widthDiff <= 0.2 && heightDiff <= 0.2
    }
    
    private func areWindowControlButtons(_ element1: UIElement, _ element2: UIElement) -> Bool {
        let isWindowControl1 = isWindowControlButton(element1)
        let isWindowControl2 = isWindowControlButton(element2)
        return isWindowControl1 && isWindowControl2
    }
    
    private func isWindowControlButton(_ element: UIElement) -> Bool {
        // Check if it's a small button (typically window controls are small)
        let area = element.size.width * element.size.height
        guard area <= 400 else { return false } // 20x20 max typical size
        
        // Check for window control indicators in type or accessibility data
        let type = element.type.lowercased()
        if type.contains("button") {
            // Check accessibility data for window control hints
            if let accData = element.accessibilityData {
                let role = accData.role.lowercased()
                let description = accData.description?.lowercased() ?? ""
                let title = accData.title?.lowercased() ?? ""
                
                return role.contains("close") || role.contains("minimize") || role.contains("zoom") ||
                       description.contains("close") || description.contains("minimize") || description.contains("zoom") ||
                       title.contains("close") || title.contains("minimize") || title.contains("zoom")
            }
            return true // Small buttons are likely window controls
        }
        
        return false
    }
    
    private func areSimilarButtons(_ element1: UIElement, _ element2: UIElement) -> Bool {
        // For window control buttons, use tighter proximity (≤3px)
        let distance = sqrt(
            pow(element1.position.x - element2.position.x, 2) +
            pow(element1.position.y - element2.position.y, 2)
        )
        
        return distance <= 3.0
    }
}

// MARK: - Legacy Deduplication Methods (for FusionEngine compatibility)

extension Deduplication {
    
    /// Legacy deduplication method for original FusionEngine
    func legacyDeduplicateElements(_ elements: [UIElement]) -> [UIElement] {
        var uniqueElements: [UIElement] = []
        
        for element in elements {
            var isDuplicate = false
            
            // Check against all existing unique elements
            for existingElement in uniqueElements {
                if legacyAreElementsDuplicates(element, existingElement) {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                uniqueElements.append(element)
            }
        }
        
        return uniqueElements
    }
    
    private func legacyAreElementsDuplicates(_ element1: UIElement, _ element2: UIElement) -> Bool {
        // Check spatial proximity (within 5 pixels)
        let distance = coordinateSystem.spatialDistance(between: element1.position, and: element2.position)
        guard distance <= 5.0 else { return false }
        
        // Check size similarity (within 20% difference)
        let size1 = element1.size
        let size2 = element2.size
        let sizeDiffWidth = abs(size1.width - size2.width) / max(size1.width, size2.width)
        let sizeDiffHeight = abs(size1.height - size2.height) / max(size1.height, size2.height)
        guard sizeDiffWidth <= 0.2 && sizeDiffHeight <= 0.2 else { return false }
        
        // Special handling for window control buttons (stoplight buttons)
        if legacyAreWindowControlButtons(element1, element2) {
            return true
        }
        
        // Check if both are buttons with similar roles
        if legacyAreSimilarButtons(element1, element2) {
            return true
        }
        
        // Check if both have similar accessibility roles
        if let acc1 = element1.accessibilityData, let acc2 = element2.accessibilityData {
            if acc1.role == acc2.role {
                // Same role + same position + same size = likely duplicate
                return true
            }
        }
        
        return false
    }
    
    private func legacyAreWindowControlButtons(_ element1: UIElement, _ element2: UIElement) -> Bool {
        // Check if both are small buttons in the top-left corner (typical window controls)
        let isSmallButton1 = element1.size.width <= 20 && element1.size.height <= 20 && 
                            (element1.type.contains("Button") || element1.isClickable)
        let isSmallButton2 = element2.size.width <= 20 && element2.size.height <= 20 && 
                            (element2.type.contains("Button") || element2.isClickable)
        
        guard isSmallButton1 && isSmallButton2 else { return false }
        
        // Check if both are in the top-left area (window control region)
        let isTopLeft1 = element1.position.x <= 100 && element1.position.y <= 50
        let isTopLeft2 = element2.position.x <= 100 && element2.position.y <= 50
        
        return isTopLeft1 && isTopLeft2
    }
    
    private func legacyAreSimilarButtons(_ element1: UIElement, _ element2: UIElement) -> Bool {
        // Both must be buttons or clickable
        guard (element1.type.contains("Button") || element1.isClickable) &&
              (element2.type.contains("Button") || element2.isClickable) else { return false }
        
        // Check for generic button types that are likely duplicates
        let isGeneric1 = element1.type == "AXButton" || element1.type == "button" || element1.type.contains("Shape_")
        let isGeneric2 = element2.type == "AXButton" || element2.type == "button" || element2.type.contains("Shape_")
        
        return isGeneric1 && isGeneric2
    }
}