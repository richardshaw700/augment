import Foundation

// MARK: - Compression Engine

class CompressionEngine: UICompression {
    func compress(_ elements: [GridMappedElement]) -> AdaptiveCompressedUI {
        let compressed = generateGridBasedCompression(elements)
        
        return AdaptiveCompressedUI(
            format: compressed,
            tokenCount: compressed.split(separator: ",").count,
            compressionRatio: calculateCompressionRatio(elements.count, compressed.count),
            regionBreakdown: calculateGridBreakdown(elements),
            confidence: calculateConfidence(elements)
        )
    }
    
    private func generateGridBasedCompression(_ elements: [GridMappedElement]) -> String {
        // Sort elements by importance and grid position for optimal compression
        let sortedElements = elements.sorted { 
            if $0.importance != $1.importance {
                return $0.importance > $1.importance
            }
            return $0.gridPosition.description < $1.gridPosition.description
        }
        
        var parts: [String] = []
        
        // Add interactive elements first (highest priority) with semantic types
        let interactiveElements = sortedElements.filter { $0.originalElement.isClickable }
        if !interactiveElements.isEmpty {
            let interactiveStrings = interactiveElements.map { element in
                let elementType = getSemanticElementType(element.originalElement)
                return "\(elementType):\(element.compressedRepresentation)"
            }
            parts.append(interactiveStrings.joined(separator: ","))
        }
        
        // Add other elements by importance
        let otherElements = sortedElements.filter { !$0.originalElement.isClickable }
        if !otherElements.isEmpty {
            let elementStrings = otherElements.map { element in
                let elementType = getSemanticElementType(element.originalElement)
                return "\(elementType):\(element.compressedRepresentation)"
            }
            parts.append(elementStrings.joined(separator: ","))
        }
        
        return parts.joined(separator: ",")
    }
    
    private func getSemanticElementType(_ element: UIElement) -> String {
        // Map element types to semantic abbreviations for AI consumption
        
        // Check accessibility role first
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton":
                return "btn"
            case "AXPopUpButton":
                return "dropdown"
            case "AXTextField", "AXTextArea", "AXSearchField":
                return "txtinp"
            case "AXCheckBox":
                return "checkbox"
            case "AXRadioButton":
                return "radio"
            case "AXSlider":
                return "slider"
            case "AXScrollArea":
                return "scroll"
            case "AXLink":
                return "link"
            case "AXImage":
                return "img"
            case "AXStaticText":
                return "txt"
            case "AXMenuButton":
                return "menu"
            case "AXTab":
                return "tab"
            default:
                break
            }
        }
        
        // Check element type as fallback
        let type = element.type.lowercased()
        if type.contains("button") {
            return "btn"
        } else if type.contains("textfield") || type.contains("input") {
            return "txtinp"
        } else if type.contains("text") {
            return "txt"
        } else if type.contains("image") {
            return "img"
        } else if type.contains("link") {
            return "link"
        }
        
        // Default for interactive elements
        if element.isClickable {
            return "btn"
        }
        
        // Default for non-interactive elements
        return "txt"
    }
    
    private func calculateCompressionRatio(_ elementCount: Int, _ compressedLength: Int) -> Double {
        guard compressedLength > 0 else { return 1.0 }
        return Double(elementCount * 100) / Double(compressedLength) // Rough estimate
    }
    
    private func calculateGridBreakdown(_ elements: [GridMappedElement]) -> [String: Int] {
        // Count elements by grid quadrants for analysis
        var breakdown: [String: Int] = [:]
        
        for element in elements {
            let x = element.gridPosition.normalizedX
            let y = element.gridPosition.normalizedY
            
            let quadrant: String
            if x < 0.5 && y < 0.5 { quadrant = "TopLeft" }
            else if x >= 0.5 && y < 0.5 { quadrant = "TopRight" }
            else if x < 0.5 && y >= 0.5 { quadrant = "BottomLeft" }
            else { quadrant = "BottomRight" }
            
            breakdown[quadrant, default: 0] += 1
        }
        
        return breakdown
    }
    
    private func calculateConfidence(_ elements: [GridMappedElement]) -> Double {
        guard !elements.isEmpty else { return 0.0 }
        return elements.reduce(0) { $0 + $1.originalElement.confidence } / Double(elements.count)
    }
} 