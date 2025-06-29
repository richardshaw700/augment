import Foundation
import AppKit

// MARK: - Spatial Optimization

class SpatialOptimization {
    
    // MARK: - Spatial Grid Structure
    
    struct SpatialGrid {
        let cellSize: Double = 50.0  // 50px grid cells
        private var grid: [String: [Int]] = [:]  // Grid cell -> accessibility indices
        
        mutating func buildGrid(from cache: [(position: CGPoint, data: AccessibilityData)]) {
            grid.removeAll()
            
            for (index, cached) in cache.enumerated() {
                let cellKey = getCellKey(for: cached.position)
                grid[cellKey, default: []].append(index)
            }
        }
        
        func getNearbyIndices(for position: CGPoint, radius: Double = 50.0) -> [Int] {
            let cellsToCheck = Int(ceil(radius / cellSize))
            var nearbyIndices: [Int] = []
            
            let centerX = Int(position.x / cellSize)
            let centerY = Int(position.y / cellSize)
            
            for dx in -cellsToCheck...cellsToCheck {
                for dy in -cellsToCheck...cellsToCheck {
                    let cellKey = "\(centerX + dx),\(centerY + dy)"
                    if let indices = grid[cellKey] {
                        nearbyIndices.append(contentsOf: indices)
                    }
                }
            }
            
            return nearbyIndices
        }
        
        private func getCellKey(for position: CGPoint) -> String {
            let x = Int(position.x / cellSize)
            let y = Int(position.y / cellSize)
            return "\(x),\(y)"
        }
    }
    
    // MARK: - Position Cache Management
    
    static func buildPositionCaches(
        accessibility: [AccessibilityData],
        ocr: [OCRData]
    ) -> (
        accessibilityCache: [(position: CGPoint, data: AccessibilityData)],
        ocrCache: [(position: CGPoint, data: OCRData)]
    ) {
        // Pre-compute all OCR positions (using top-left corner for consistency)
        let ocrPositionCache = ocr.map { ocrData in
            let position = CGPoint(
                x: ocrData.boundingBox.origin.x,
                y: ocrData.boundingBox.origin.y
            )
            return (position: position, data: ocrData)
        }
        
        // Pre-compute all accessibility positions (filter out nil positions)
        let accessibilityPositionCache: [(position: CGPoint, data: AccessibilityData)] = accessibility.compactMap { accData in
            guard let position = accData.position else { return nil }
            return (position: position, data: accData)
        }
        
        return (accessibilityPositionCache, ocrPositionCache)
    }
    
    // MARK: - Optimized Spatial Lookup Methods
    
    /// Optimized linear search for small datasets
    static func findNearbyAccessibilityElementLinear(
        for ocrPosition: CGPoint,
        maxDistance: Double,
        in accessibilityCache: [(position: CGPoint, data: AccessibilityData)]
    ) -> (AccessibilityData?, Int?) {
        var bestMatch: (data: AccessibilityData, distance: Double, index: Int)?
        let maxDistanceSquared = maxDistance * maxDistance
        
        for (index, cachedAcc) in accessibilityCache.enumerated() {
            // Fast squared distance calculation
            let dx = ocrPosition.x - cachedAcc.position.x
            let dy = ocrPosition.y - cachedAcc.position.y
            let distanceSquared = dx * dx + dy * dy
            
            // Early rejection if too far
            guard distanceSquared <= maxDistanceSquared else { continue }
            
            // Early termination: if very close, use immediately
            if distanceSquared < 25.0 { // 5px squared
                return (cachedAcc.data, index)
            }
            
            // Track best match (avoid sqrt until necessary)
            if bestMatch == nil || distanceSquared < (bestMatch!.distance * bestMatch!.distance) {
                bestMatch = (cachedAcc.data, sqrt(distanceSquared), index)
            }
        }
        
        return (bestMatch?.data, bestMatch?.index)
    }
    
    /// Grid-based spatial lookup - O(1) instead of O(n)
    static func findNearbyAccessibilityElementWithGrid(
        for ocrPosition: CGPoint,
        maxDistance: Double,
        in accessibilityCache: [(position: CGPoint, data: AccessibilityData)],
        spatialGrid: SpatialGrid
    ) -> (AccessibilityData?, Int?) {
        // Get candidate indices from spatial grid
        let candidateIndices = spatialGrid.getNearbyIndices(for: ocrPosition, radius: maxDistance)
        
        var bestMatch: (data: AccessibilityData, distance: Double, index: Int)?
        let maxDistanceSquared = maxDistance * maxDistance
        
        for index in candidateIndices {
            guard index < accessibilityCache.count else { continue }
            
            let cachedAcc = accessibilityCache[index]
            
            // Fast squared distance calculation
            let dx = ocrPosition.x - cachedAcc.position.x
            let dy = ocrPosition.y - cachedAcc.position.y
            let distanceSquared = dx * dx + dy * dy
            
            // Early rejection if too far
            if distanceSquared > maxDistanceSquared {
                continue
            }
            
            // Early termination: if very close, use immediately
            if distanceSquared < 25.0 { // 5px squared
                return (cachedAcc.data, index)
            }
            
            // Track best match
            if bestMatch == nil {
                bestMatch = (cachedAcc.data, sqrt(distanceSquared), index)
            } else {
                let distance = sqrt(distanceSquared)
                if distance < bestMatch!.distance {
                    bestMatch = (cachedAcc.data, Double(distance), index)
                }
            }
        }
        
        return (bestMatch?.data, bestMatch?.index)
    }
    
    // MARK: - High-Value Element Detection
    
    static func isHighValueAccessibilityElement(_ accData: AccessibilityData) -> Bool {
        // Optimized role checking - use prefix matching for faster comparison
        let role = accData.role
        
        // Fast prefix-based role checking
        if role.hasPrefix("AXButton") || role.hasPrefix("AXMenuItem") || role.hasPrefix("AXPopUp") {
            return true
        }
        
        if role.hasPrefix("AXText") {
            return true  // AXTextField, AXTextArea
        }
        
        if role.hasPrefix("AXCheck") || role.hasPrefix("AXRadio") {
            return true  // AXCheckBox, AXRadioButton
        }
        
        if role.hasPrefix("AXSlider") || role.hasPrefix("AXProgress") {
            return true  // AXSlider, AXProgressIndicator
        }
        
        if role == "AXScrollArea" {
            // Quick size check with early return
            guard let size = accData.size else { return false }
            return size.width > 100 && size.height > 100
        }
        
        if role == "AXRow" || role == "AXCell" {
            // Fast nil checks
            return accData.title != nil || accData.description != nil
        }
        
        return false
    }
    
    /// Ultra-optimized version for batch processing
    static func isHighValueAccessibilityElementOptimized(_ accData: AccessibilityData) -> Bool {
        let role = accData.role
        
        // Ultra-fast character-based early detection
        let firstChar = role.first
        guard firstChar == "A" else { return false } // All AX roles start with 'A'
        
        // Fast second character check
        if role.count < 3 { return false }
        let secondChar = role[role.index(role.startIndex, offsetBy: 1)]
        guard secondChar == "X" else { return false } // All AX roles have 'X' as second char
        
        // Optimized role checking with character-based lookup
        if role.count >= 8 { // "AXButton" = 8 chars
            let prefix = String(role.prefix(8))
            if prefix == "AXButton" || prefix == "AXMenuIt" || prefix == "AXPopUpB" {
                return true
            }
        }
        
        if role.count >= 6 { // "AXText" = 6 chars minimum
            let prefix = String(role.prefix(6))
            if prefix == "AXText" {
                return true
            }
        }
        
        if role.count >= 7 { // "AXCheck" = 7 chars minimum
            let prefix = String(role.prefix(7))
            if prefix == "AXCheck" || prefix == "AXRadio" || prefix == "AXSlide" {
                return true
            }
        }
        
        // Exact matches for short roles
        if role == "AXRow" || role == "AXCell" {
            // Fast existence check without nil coalescing
            return accData.title != nil || accData.description != nil
        }
        
        if role == "AXScrollArea" {
            // Optimized size check
            return accData.size?.width ?? 0 > 100 && accData.size?.height ?? 0 > 100
        }
        
        return false
    }
    
    // MARK: - Basic Fusion Helper Methods
    
    /// Find the closest OCR text near a given position, excluding already used elements
    static func findClosestOCRTextNear(
        position: CGPoint,
        in ocrElements: [OCRData],
        excluding usedIndices: Set<Int>,
        coordinateSystem: CoordinateSystem
    ) -> (data: OCRData, index: Int)? {
        
        var bestMatch: (data: OCRData, index: Int, distance: Double)?
        
        // Check each OCR text element
        for (ocrIndex, ocrElement) in ocrElements.enumerated() {
            // Skip if we already used this OCR text
            guard !usedIndices.contains(ocrIndex) else { continue }
            
            // Calculate where this OCR text is positioned (top-left corner of its bounding box)
            let ocrPosition = CGPoint(
                x: ocrElement.boundingBox.origin.x,
                y: ocrElement.boundingBox.origin.y
            )
            
            // Measure how far apart the accessibility element and OCR text are
            let distance = coordinateSystem.spatialDistance(between: position, and: ocrPosition)
            
            // If they're close enough (within 100 pixels), consider this a potential match
            if coordinateSystem.isNearby(position, ocrPosition, threshold: 100.0) {
                // Keep track of the closest match
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (ocrElement, ocrIndex, distance)
                }
            }
        }
        
        // Return the closest match we found (if any)
        return bestMatch.map { (data: $0.data, index: $0.index) }
    }
}