import Foundation

// MARK: - Compression Engine

class CompressionEngine: UICompression {
    func compress(_ elements: [GridMappedElement]) -> AdaptiveCompressedUI {
        let regionGroups = groupByRegions(elements)
        let compressed = generateCompressedRepresentation(regionGroups)
        
        return AdaptiveCompressedUI(
            format: compressed,
            tokenCount: compressed.split(separator: ",").count,
            compressionRatio: calculateCompressionRatio(elements.count, compressed.count),
            regionBreakdown: calculateRegionBreakdown(regionGroups),
            confidence: calculateConfidence(elements)
        )
    }
    
    private func groupByRegions(_ elements: [GridMappedElement]) -> [GridRegion: [GridMappedElement]] {
        var groups: [GridRegion: [GridMappedElement]] = [:]
        
        for element in elements {
            for region in GridRegion.allCases {
                if region.contains(position: element.gridPosition) {
                    groups[region, default: []].append(element)
                    break
                }
            }
        }
        
        return groups
    }
    
    private func generateCompressedRepresentation(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        var parts: [String] = []
        
        // Add clickable elements first
        let clickableElements = regionGroups.values.flatMap { $0 }.filter { $0.originalElement.isClickable }
        if !clickableElements.isEmpty {
            let clickableStrings = clickableElements.map { "click:\($0.compressedRepresentation)" }
            parts.append(clickableStrings.joined(separator: ","))
        }
        
        // Add other elements by region
        for region in GridRegion.allCases {
            if let elements = regionGroups[region], !elements.isEmpty {
                let nonClickable = elements.filter { !$0.originalElement.isClickable }
                if !nonClickable.isEmpty {
                    let elementStrings = nonClickable.map { $0.compressedRepresentation }
                    parts.append(elementStrings.joined(separator: ","))
                }
            }
        }
        
        return parts.joined(separator: ",")
    }
    
    private func calculateCompressionRatio(_ elementCount: Int, _ compressedLength: Int) -> Double {
        guard compressedLength > 0 else { return 1.0 }
        return Double(elementCount * 100) / Double(compressedLength) // Rough estimate
    }
    
    private func calculateRegionBreakdown(_ regionGroups: [GridRegion: [GridMappedElement]]) -> [String: Int] {
        var breakdown: [String: Int] = [:]
        for (region, elements) in regionGroups {
            breakdown[region.rawValue] = elements.count
        }
        return breakdown
    }
    
    private func calculateConfidence(_ elements: [GridMappedElement]) -> Double {
        guard !elements.isEmpty else { return 0.0 }
        return elements.reduce(0) { $0 + $1.originalElement.confidence } / Double(elements.count)
    }
} 