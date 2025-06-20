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
        
        // Add clickable elements first (highest priority)
        let clickableElements = sortedElements.filter { $0.originalElement.isClickable }
        if !clickableElements.isEmpty {
            let clickableStrings = clickableElements.map { "click:\($0.compressedRepresentation)" }
            parts.append(clickableStrings.joined(separator: ","))
        }
        
        // Add other elements by importance
        let otherElements = sortedElements.filter { !$0.originalElement.isClickable }
        if !otherElements.isEmpty {
            let elementStrings = otherElements.map { $0.compressedRepresentation }
            parts.append(elementStrings.joined(separator: ","))
        }
        
        return parts.joined(separator: ",")
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