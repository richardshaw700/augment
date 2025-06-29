import Foundation
import AppKit

// MARK: - Data Fusion Orchestrator
// 
// This orchestrator combines multiple data sources (accessibility tree, OCR text, visual shapes)
// into a unified set of UI elements that can be used for automation and interaction.
//
// Strategy:
// 1. Start with OCR text (which has more accurate positions)
// 2. Enhance OCR with nearby accessibility data 
// 3. Use performance optimizations for large datasets
// 4. Only add high-value accessibility elements
// 5. Integrate visual shapes and remove duplicates

class FusionOrchestrator: DataFusion {
    
    // Our tools and optimizations
    private let coordinateSystem: CoordinateSystem
    private let deduplication: Deduplication
    private var spatialGrid = SpatialOptimization.SpatialGrid()
    
    init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
        self.deduplication = Deduplication(coordinateSystem: coordinateSystem)
    }
    
    func fuse(accessibility: [AccessibilityData], ocr: [OCRData], coordinates: CoordinateMapping) -> [UIElement] {
        
        // STEP 1: Pre-calculate all positions for faster lookups
        let (accessibilityCache, ocrCache) = SpatialOptimization.buildPositionCaches(
            accessibility: accessibility, 
            ocr: ocr
        )
        
        // STEP 2: For large datasets, build a spatial grid for super-fast nearby element searches
        let shouldUseGridOptimization = accessibilityCache.count > 100
        if shouldUseGridOptimization {
            spatialGrid.buildGrid(from: accessibilityCache)
        }
        
        // STEP 3: Start with OCR text and enhance each with nearby accessibility data
        let (ocrEnhancedElements, usedAccessibilityIndices) = ElementCreation.enhanceOCRWithAccessibilityData(
            ocrCache: ocrCache,
            accessibilityCache: accessibilityCache,
            spatialGrid: spatialGrid,
            useGridOptimization: shouldUseGridOptimization
        )
        
        // STEP 4: Add only the most valuable leftover accessibility elements
        let valuableAccessibilityElements = ElementCreation.addHighValueAccessibilityElements(
            accessibilityCache: accessibilityCache,
            alreadyUsed: usedAccessibilityIndices
        )
        
        // STEP 5: Combine and show results
        let allElements = ocrEnhancedElements + valuableAccessibilityElements
        FusionReporting.printFusionSummary(
            total: allElements.count,
            ocrEnhanced: ocrEnhancedElements.count,
            accessibilityOnly: valuableAccessibilityElements.count,
            optimization: shouldUseGridOptimization ? "Grid-based" : "Linear"
        )
        
        return allElements
    }
    
    /// Integrate visual shapes with existing elements
    func integrateVisualElements(
        fusedElements: [UIElement],
        visualElements: [UIShapeCandidate],
        ocrElements: [OCRData], 
        windowFrame: CGRect
    ) -> [UIElement] {
        
        let integratedElements = VisualIntegration.integrateVisualElements(
            fusedElements: fusedElements,
            visualElements: visualElements,
            ocrElements: ocrElements,
            windowFrame: windowFrame
        )
        
        return deduplication.deduplicateElements(integratedElements)
    }
    
    /// Final cleanup of duplicate elements
    func performFinalDeduplication(_ elements: [UIElement]) -> [UIElement] {
        return deduplication.deduplicateElements(elements)
    }
}

// MARK: - Fusion Reporting
//
// Utility class for logging fusion results

class FusionReporting {
    
    static func printFusionSummary(total: Int, ocrEnhanced: Int, accessibilityOnly: Int, optimization: String) {
        print("🔗 Fusion complete: \(total) total elements")
        print("   • OCR-enhanced: \(ocrEnhanced)")
        print("   • High-value accessibility: \(accessibilityOnly)")
        print("   • Optimization: \(optimization) spatial lookup")
    }
}

// MARK: - Type Aliases for Backward Compatibility

typealias ImprovedFusionEngine = FusionOrchestrator