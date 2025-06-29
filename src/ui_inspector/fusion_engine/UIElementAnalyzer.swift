import Foundation
import AppKit

/// Analyzes UI elements and provides detailed reporting
class UIElementAnalyzer {
    
    /// Print detailed button summary with accessibility and shape-detected buttons
    func printButtonSummary(elements: [UIElement], shapeElements: [UIShapeCandidate]) {
        print("\n🔘 BUTTON ANALYSIS:")
        print(String(repeating: "=", count: 50))
        
        // Find all button-like elements
        let accessibilityButtons = elements.filter { element in
            element.type.contains("Button") || element.actionHint?.contains("Click") == true
        }
        
        let shapeButtons = shapeElements.filter { shape in
            shape.interactionType == .button || shape.interactionType == .iconButton || shape.interactionType == .closeButton
        }
        
        print("📊 Button Summary:")
        print("   • Accessibility Buttons: \(accessibilityButtons.count)")
        print("   • Shape-Detected Buttons: \(shapeButtons.count)")
        print("   • Total Interactive Elements: \(accessibilityButtons.count + shapeButtons.count)")
        
        if !accessibilityButtons.isEmpty {
            print("\n🎯 Accessibility Buttons:")
            for (index, button) in accessibilityButtons.enumerated() {
                let pos = button.position
                let size = button.size
                let text = button.visualText ?? button.accessibilityData?.description ?? button.accessibilityData?.title ?? "No text"
                let type = button.type.replacingOccurrences(of: "AX", with: "")
                
                print("   \(index + 1). \(type) at (\(Int(pos.x)), \(Int(pos.y))) - \(Int(size.width))x\(Int(size.height))")
                print("      Text: '\(text)'")
                if let actionHint = button.actionHint {
                    print("      Action: \(actionHint)")
                }
                print()
            }
        }
        
        if !shapeButtons.isEmpty {
            print("🎨 Shape-Detected Buttons:")
            for (index, button) in shapeButtons.enumerated() {
                let bounds = button.boundingBox
                
                print("   \(index + 1). \(button.interactionType.rawValue) (\(button.type.rawValue)) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) - \(Int(bounds.width))x\(Int(bounds.height))")
                print("      Confidence: \(String(format: "%.1f", button.confidence * 100))%")
                print()
            }
        }
        
        if accessibilityButtons.isEmpty && shapeButtons.isEmpty {
            print("   ℹ️  No buttons detected in this window")
        }
    }
    
    /// Extract shape elements from filtered UI elements for analysis
    func extractShapeElementsFromFiltered(_ elements: [UIElement]) -> [UIShapeCandidate] {
        // Convert filtered UI elements back to shape candidates for button summary
        return elements.compactMap { element in
            // Only extract elements that were originally from shape detection
            guard element.type.hasPrefix("Shape_") else { return nil }
            
            // Extract the shape type from the element type
            let shapeTypeString = String(element.type.dropFirst(6)) // Remove "Shape_" prefix
            guard let shapeType = ShapeType(rawValue: shapeTypeString) else { return nil }
            
            // Create a dummy contour path (just for display purposes)
            let bounds = CGRect(origin: CGPoint(x: element.position.x - element.size.width/2, 
                                               y: element.position.y - element.size.height/2), 
                               size: element.size)
            let path = CGPath(rect: bounds, transform: nil)
            
            // Determine interaction type from semantic meaning or action hint
            let interactionType: InteractionType
            if let actionHint = element.actionHint {
                switch actionHint.lowercased() {
                case let hint where hint.contains("text_input"):
                    interactionType = .textInput
                case let hint where hint.contains("close"):
                    interactionType = .closeButton
                case let hint where hint.contains("icon"):
                    interactionType = .iconButton
                case let hint where hint.contains("button"):
                    interactionType = .button
                default:
                    interactionType = .button
                }
            } else {
                interactionType = .button
            }
            
            return UIShapeCandidate(
                contour: path,
                boundingBox: bounds,
                type: shapeType,
                uiRole: .button,
                interactionType: interactionType,
                confidence: element.confidence,
                area: element.size.width * element.size.height,
                aspectRatio: element.size.width / element.size.height,
                corners: [],
                curvature: 0.0
            )
        }
    }
    
    /// Print detection summary showing element progression
    func printDetectionSummary(ocrOnlyCount: Int, fusedCount: Int, finalCount: Int, shapeCount: Int) {
        print("\n📊 DETECTION SUMMARY")
        print("====================")
        print("📈 Element Count Progression:")
        print("   OCR-only: \(ocrOnlyCount)")
        print("   + Accessibility: \(fusedCount) (+\(fusedCount - ocrOnlyCount))")
        print("   + Shapes & Deduplication: \(finalCount) (+\(shapeCount) shapes, deduplication applied)")
    }
    
    /// Analyze element distribution and types
    func analyzeElementDistribution(_ elements: [UIElement]) -> ElementDistributionReport {
        var report = ElementDistributionReport()
        
        for element in elements {
            // Count by type
            if element.type.contains("Button") {
                report.buttonCount += 1
            } else if element.type.contains("Text") {
                report.textCount += 1
            } else if element.type.contains("Menu") {
                report.menuCount += 1
            } else {
                report.otherCount += 1
            }
            
            // Count by source
            if element.accessibilityData != nil && element.ocrData != nil {
                report.fusedElementsCount += 1
            } else if element.accessibilityData != nil {
                report.accessibilityOnlyCount += 1
            } else if element.ocrData != nil {
                report.ocrOnlyCount += 1
            } else {
                report.visualOnlyCount += 1
            }
            
            // Track confidence
            if element.confidence > 0.8 {
                report.highConfidenceCount += 1
            } else if element.confidence > 0.5 {
                report.mediumConfidenceCount += 1
            } else {
                report.lowConfidenceCount += 1
            }
        }
        
        report.totalElements = elements.count
        return report
    }
    
    // MARK: - Coordinate Debugging
    
    /// Print detailed coordinate debugging information
    func printCoordinateDebugging(
        windowFrame: CGRect,
        accessibilityElements: [AccessibilityData],
        ocrElements: [OCRData],
        fusedElements: [UIElement]
    ) {
        print("\n🎯 COORDINATE DEBUGGING:")
        print("========================")
        print("Window Frame: \(windowFrame)")
        print("✅ Using percentage-based coordinates (0-100% of window dimensions)")
        
        // Show sample coordinate positions for key elements
        let keywordElements = fusedElements.filter { element in
            guard let text = element.visualText else { return false }
            return ["macintosh", "network", "drive", "downloads", "desktop", "applications"].contains(where: { text.lowercased().contains($0) })
        }
        
        print("\n📍 Key Elements Percentage Positions:")
        for element in keywordElements.prefix(5) {
            let xPercent = Int((element.position.x / windowFrame.width) * 100)
            let yPercent = Int((element.position.y / windowFrame.height) * 100)
            print("   '\(element.visualText ?? "Unknown")' -> \(xPercent)%:\(yPercent)%")
        }
        
        print("\n📊 Element Distribution:")
        print("   Total elements: \(fusedElements.count)")
        print("   Window dimensions: \(Int(windowFrame.width))×\(Int(windowFrame.height))")
        
        // Additional coordinate debugging information
        print("\n🔍 Coordinate System Validation:")
        print("   Accessibility elements: \(accessibilityElements.count)")
        print("   OCR elements: \(ocrElements.count)")
        print("   Fused elements: \(fusedElements.count)")
        
        // Check for any elements outside window bounds
        let elementsOutOfBounds = fusedElements.filter { element in
            element.position.x < 0 || element.position.y < 0 || 
            element.position.x > windowFrame.width || element.position.y > windowFrame.height
        }
        
        if !elementsOutOfBounds.isEmpty {
            print("   ⚠️  Elements outside window bounds: \(elementsOutOfBounds.count)")
            for element in elementsOutOfBounds.prefix(3) {
                print("      - '\(element.visualText ?? "Unknown")' at (\(Int(element.position.x)), \(Int(element.position.y)))")
            }
        } else {
            print("   ✅ All elements within window bounds")
        }
    }
}

// MARK: - Analysis Results

extension UIElementAnalyzer {
    struct ElementDistributionReport {
        var totalElements: Int = 0
        
        // By type
        var buttonCount: Int = 0
        var textCount: Int = 0
        var menuCount: Int = 0
        var otherCount: Int = 0
        
        // By source
        var fusedElementsCount: Int = 0
        var accessibilityOnlyCount: Int = 0
        var ocrOnlyCount: Int = 0
        var visualOnlyCount: Int = 0
        
        // By confidence
        var highConfidenceCount: Int = 0
        var mediumConfidenceCount: Int = 0
        var lowConfidenceCount: Int = 0
    }
} 