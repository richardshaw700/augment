import Foundation
import AppKit

// MARK: - Visual Integration

class VisualIntegration {
    
    // MARK: - Public Methods
    
    static func integrateVisualElements(
        fusedElements: [UIElement],
        visualElements: [UIShapeCandidate],
        ocrElements: [OCRData],
        windowFrame: CGRect
    ) -> [UIElement] {
        var integratedElements = fusedElements
        
        print("🎨 Integrating \(visualElements.count) shape elements...")
        
        for visualElement in visualElements {
            // Find overlapping existing elements to enhance
            var enhancedExisting = false
            
            for (index, existing) in integratedElements.enumerated() {
                let existingRect = CGRect(origin: existing.position, size: existing.size)
                let visualRect = visualElement.boundingBox
                
                // Calculate intersection
                let intersection = existingRect.intersection(visualRect)
                let overlapArea = intersection.width * intersection.height
                let visualArea = visualRect.width * visualRect.height
                
                // If significant overlap (>30%), enhance the existing element instead of adding new
                if overlapArea > (visualArea * 0.3) {
                    let enhancedElement = ElementCreation.enhanceElementWithButtonContext(
                        existing: existing,
                        buttonCandidate: visualElement,
                        ocrElements: ocrElements,
                        windowFrame: windowFrame
                    )
                    integratedElements[index] = enhancedElement
                    enhancedExisting = true
                    
                    print("   🔗 Enhanced existing element with button context: \(visualElement.type.rawValue) at (\(Int(visualElement.boundingBox.origin.x)), \(Int(visualElement.boundingBox.origin.y)))")
                    break
                }
            }
            
            // If no overlap, add as new element
            if !enhancedExisting {
                let newUIElement = ElementCreation.createUIElementFromVisual(
                    visualElement: visualElement,
                    ocrElements: ocrElements,
                    windowFrame: windowFrame
                )
                integratedElements.append(newUIElement)
                
                print("   ✅ Added new shape element: \(visualElement.type.rawValue) at (\(Int(visualElement.boundingBox.origin.x)), \(Int(visualElement.boundingBox.origin.y)))")
            }
        }
        
        print("🎨 Shape integration complete: \(integratedElements.count - fusedElements.count) new elements added")
        
        return integratedElements
    }
}