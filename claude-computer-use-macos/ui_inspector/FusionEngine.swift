import Foundation
import AppKit

// MARK: - Fusion Engine

class FusionEngine: DataFusion {
    private let coordinateSystem: CoordinateSystem
    
    init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
    }
    
    func fuse(accessibility: [AccessibilityData], ocr: [OCRData], coordinates: CoordinateMapping) -> [UIElement] {
        var fusedElements: [UIElement] = []
        var usedOCRIndices: Set<Int> = []
        var usedAccessibilityIndices: Set<Int> = []
        
        // Phase 1: Find spatially correlated elements (accessibility + OCR)
        for (accIndex, accData) in accessibility.enumerated() {
            guard let accPosition = accData.position else { continue }
            
            var bestOCRMatch: (index: Int, data: OCRData, distance: Double)?
            
            for (ocrIndex, ocrData) in ocr.enumerated() {
                guard !usedOCRIndices.contains(ocrIndex) else { continue }
                
                // Get OCR position from bounding box center
                let ocrPosition = CGPoint(
                    x: ocrData.boundingBox.midX,
                    y: ocrData.boundingBox.midY
                )
                
                let distance = coordinateSystem.spatialDistance(between: accPosition, and: ocrPosition)
                
                // Check if they're spatially close
                if coordinateSystem.isNearby(accPosition, ocrPosition, threshold: 100.0) {
                    if bestOCRMatch == nil || distance < bestOCRMatch!.distance {
                        bestOCRMatch = (ocrIndex, ocrData, distance)
                    }
                }
            }
            
            // Create fused element
            if let ocrMatch = bestOCRMatch {
                let fusedElement = createUIElement(
                    from: accData,
                    ocrData: ocrMatch.data,
                    position: accPosition
                )
                fusedElements.append(fusedElement)
                usedAccessibilityIndices.insert(accIndex)
                usedOCRIndices.insert(ocrMatch.index)
            }
        }
        
        // Phase 2: Add remaining accessibility-only elements
        for (accIndex, accData) in accessibility.enumerated() {
            guard !usedAccessibilityIndices.contains(accIndex),
                  let accPosition = accData.position else { continue }
            
            let accessibilityOnlyElement = createUIElement(
                from: accData,
                ocrData: nil,
                position: accPosition
            )
            fusedElements.append(accessibilityOnlyElement)
        }
        
        // Phase 3: Add remaining OCR-only elements
        for (ocrIndex, ocrData) in ocr.enumerated() {
            guard !usedOCRIndices.contains(ocrIndex) else { continue }
            
            let ocrPosition = CGPoint(
                x: ocrData.boundingBox.midX,
                y: ocrData.boundingBox.midY
            )
            
            let ocrOnlyElement = createUIElement(
                from: nil,
                ocrData: ocrData,
                position: ocrPosition
            )
            fusedElements.append(ocrOnlyElement)
        }
        
        print("🔗 Fusion complete: \(fusedElements.count) total elements")
        print("   • Fused (ACC+OCR): \(fusedElements.filter { $0.accessibilityData != nil && $0.ocrData != nil }.count)")
        print("   • Accessibility only: \(fusedElements.filter { $0.accessibilityData != nil && $0.ocrData == nil }.count)")
        print("   • OCR only: \(fusedElements.filter { $0.accessibilityData == nil && $0.ocrData != nil }.count)")
        
        return fusedElements
    }
    
    // MARK: - Element Creation
    
    private func createUIElement(from accData: AccessibilityData?, ocrData: OCRData?, position: CGPoint) -> UIElement {
        // Determine element type
        let type = determineElementType(accData: accData, ocrData: ocrData)
        
        // Calculate size
        let size = calculateElementSize(accData: accData, ocrData: ocrData)
        
        // Determine if clickable
        let isClickable = determineClickability(accData: accData, ocrData: ocrData)
        
        // Calculate confidence
        let confidence = calculateConfidence(accData: accData, ocrData: ocrData)
        
        return UIElement(
            type: type,
            position: position,
            size: size,
            accessibilityData: accData,
            ocrData: ocrData,
            isClickable: isClickable,
            confidence: confidence
        )
    }
    
    private func determineElementType(accData: AccessibilityData?, ocrData: OCRData?) -> String {
        if let accData = accData, let ocrData = ocrData {
            return "\(accData.role)+OCR"
        } else if let accData = accData {
            return accData.role
        } else if let ocrData = ocrData {
            return "TextContent"
        } else {
            return "Unknown"
        }
    }
    
    private func calculateElementSize(accData: AccessibilityData?, ocrData: OCRData?) -> CGSize {
        // Prefer accessibility size if available
        if let accSize = accData?.size {
            return accSize
        }
        
        // Use OCR bounding box size
        if let ocrData = ocrData {
            return ocrData.boundingBox.size
        }
        
        // Default size
        return CGSize(width: 20, height: 20)
    }
    
    private func determineClickability(accData: AccessibilityData?, ocrData: OCRData?) -> Bool {
        // Check accessibility role for clickable elements
        if let role = accData?.role {
            switch role {
            case "AXButton", "AXMenuItem", "AXPopUpButton", "AXCheckBox", "AXRadioButton":
                return true
            case "AXRow", "AXCell":
                // Rows and cells might be clickable in lists
                return true
            default:
                break
            }
        }
        
        // Check OCR text for clickable indicators
        if let text = ocrData?.text.lowercased() {
            let clickableKeywords = ["button", "click", "press", "tap", "select", "open", "close", "save", "cancel"]
            if clickableKeywords.contains(where: { text.contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    private func calculateConfidence(accData: AccessibilityData?, ocrData: OCRData?) -> Double {
        var confidence = 0.0
        var factors = 0
        
        // Accessibility confidence
        if let accData = accData {
            confidence += 0.7 // Accessibility data is generally reliable
            factors += 1
            
            // Bonus for interactive elements
            if accData.enabled {
                confidence += 0.1
            }
        }
        
        // OCR confidence
        if let ocrData = ocrData {
            confidence += Double(ocrData.confidence)
            factors += 1
        }
        
        // Fusion bonus (having both sources increases confidence)
        if accData != nil && ocrData != nil {
            confidence += 0.2
        }
        
        return factors > 0 ? confidence / Double(factors) : 0.5
    }
}

// MARK: - UIElement Extensions

extension UIElement {
    init(type: String, position: CGPoint, size: CGSize, 
         accessibilityData: AccessibilityData?, ocrData: OCRData?, 
         isClickable: Bool, confidence: Double) {
        self.id = UUID().uuidString
        self.type = type
        self.position = position
        self.size = size
        self.accessibilityData = accessibilityData
        self.ocrData = ocrData
        self.isClickable = isClickable
        self.confidence = confidence
        
        // Enhanced semantic understanding
        self.semanticMeaning = UIElement.inferSemanticMeaning(accessibilityData, ocrData)
        self.actionHint = UIElement.generateActionHint(accessibilityData, ocrData, isClickable)
        self.visualText = ocrData?.text
        self.interactions = UIElement.generateInteractions(accessibilityData, isClickable)
        self.context = UIElement.generateContext(accessibilityData, ocrData, position)
    }
    
    private static func inferSemanticMeaning(_ accData: AccessibilityData?, _ ocrData: OCRData?) -> String {
        if let accData = accData, let ocrData = ocrData {
            return "\(accData.role) with text '\(ocrData.text)'"
        } else if let accData = accData {
            return accData.description ?? accData.role
        } else if let ocrData = ocrData {
            return "Text content: '\(ocrData.text)'"
        } else {
            return "Unknown element"
        }
    }
    
    private static func generateActionHint(_ accData: AccessibilityData?, _ ocrData: OCRData?, _ isClickable: Bool) -> String? {
        guard isClickable else { return nil }
        
        if let ocrText = ocrData?.text.lowercased() {
            if ocrText.contains("close") || ocrText.contains("×") {
                return "Click to close"
            } else if ocrText.contains("save") {
                return "Click to save"
            } else if ocrText.contains("search") {
                return "Click to search"
            } else if ocrText.contains("share") {
                return "Click to share"
            } else if ocrText.contains("edit") {
                return "Click to edit"
            }
        }
        
        if let accDesc = accData?.description {
            return "Click \(accDesc)"
        }
        
        return "Clickable element"
    }
    
    private static func generateInteractions(_ accData: AccessibilityData?, _ isClickable: Bool) -> [String] {
        var interactions: [String] = []
        
        if isClickable {
            interactions.append("click")
        }
        
        if let accData = accData {
            switch accData.role {
            case "AXTextField":
                interactions.append(contentsOf: ["type", "select_all", "copy", "paste"])
            case "AXButton", "AXMenuItem":
                interactions.append("double_click")
            case "AXSlider":
                interactions.append(contentsOf: ["drag", "arrow_keys"])
            case "AXCheckBox", "AXRadioButton":
                interactions.append("toggle")
            case "AXScrollArea":
                interactions.append(contentsOf: ["scroll", "swipe"])
            case "AXPopUpButton":
                interactions.append("dropdown")
            case "AXImage", "AXGroup":
                interactions.append("right_click")
            default:
                break
            }
        }
        
        return interactions
    }
    
    private static func generateContext(_ accData: AccessibilityData?, _ ocrData: OCRData?, _ position: CGPoint) -> ElementContext? {
        guard let accData = accData else { return nil }
        
        let purpose = inferPurpose(accData, ocrData)
        let region = inferRegion(position)
        let navigationPath = generateNavigationPath(accData)
        let availableActions = generateAvailableActions(accData, ocrData)
        
        return ElementContext(
            purpose: purpose,
            region: region,
            navigationPath: navigationPath,
            availableActions: availableActions
        )
    }
    
    private static func inferPurpose(_ accData: AccessibilityData, _ ocrData: OCRData?) -> String {
        if let text = ocrData?.text.lowercased() {
            if text.contains("close") || text.contains("×") { return "window_control" }
            if text.contains("save") { return "file_operation" }
            if text.contains("search") { return "search" }
            if text.contains("share") { return "sharing" }
        }
        
        switch accData.role {
        case "AXButton": return "action_trigger"
        case "AXTextField": return "text_input"
        case "AXStaticText": return "information_display"
        case "AXImage": return "visual_content"
        case "AXGroup": return "content_container"
        default: return "ui_element"
        }
    }
    
    private static func inferRegion(_ position: CGPoint) -> String {
        if position.y < 100 { return "toolbar" }
        if position.x < 200 { return "sidebar" }
        if position.y > 500 { return "status_bar" }
        return "main_content"
    }
    
    private static func generateNavigationPath(_ accData: AccessibilityData) -> String {
        var path = accData.role
        if let parent = accData.parent {
            path = "\(parent) > \(path)"
        }
        if let title = accData.title {
            path += "[\(title)]"
        }
        return path
    }
    
    private static func generateAvailableActions(_ accData: AccessibilityData, _ ocrData: OCRData?) -> [String] {
        var actions: [String] = []
        
        switch accData.role {
        case "AXButton":
            actions.append("activate")
        case "AXTextField":
            actions.append(contentsOf: ["focus", "type", "clear"])
        case "AXImage":
            actions.append(contentsOf: ["view", "save_as"])
        case "AXGroup":
            if !accData.children.isEmpty {
                actions.append("expand")
            }
        default:
            break
        }
        
        if let text = ocrData?.text.lowercased() {
            if text.contains("download") { actions.append("download") }
            if text.contains("open") { actions.append("open") }
            if text.contains("edit") { actions.append("edit") }
        }
        
        return actions
    }
}

// MARK: - Improved OCR-Primary Fusion Engine

class ImprovedFusionEngine: DataFusion {
    private let coordinateSystem: CoordinateSystem
    
    init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
    }
    
    func fuse(accessibility: [AccessibilityData], ocr: [OCRData], coordinates: CoordinateMapping) -> [UIElement] {
        var fusedElements: [UIElement] = []
        
        // Strategy: OCR-Primary Fusion
        // 1. Start with OCR elements (perfect coordinates)
        // 2. Enhance with nearby accessibility metadata (clickability, roles)
        // 3. Add only high-value accessibility-only elements
        
        // Phase 1: Create OCR-primary elements with accessibility enhancement
        for ocrData in ocr {
            let ocrPosition = CGPoint(
                x: ocrData.boundingBox.midX,
                y: ocrData.boundingBox.midY
            )
            
            // Find nearby accessibility element for metadata enhancement
            let nearbyAccessibility = findNearbyAccessibilityElement(
                for: ocrPosition, 
                in: accessibility,
                maxDistance: 30.0  // Tighter threshold
            )
            
            let enhancedElement = createOCRPrimaryElement(
                ocrData: ocrData,
                position: ocrPosition,
                accessibilityEnhancement: nearbyAccessibility
            )
            
            fusedElements.append(enhancedElement)
        }
        
        // Phase 2: Add high-value accessibility-only elements
        let usedAccessibilityElements = Set(fusedElements.compactMap { $0.accessibilityData?.element })
        
        for accData in accessibility {
            // Skip if already used for enhancement
            if let element = accData.element, usedAccessibilityElements.contains(element) {
                continue
            }
            
            // Only add if it provides unique value
            if isHighValueAccessibilityElement(accData) {
                guard let position = accData.position else { continue }
                
                let accessibilityElement = createAccessibilityOnlyElement(
                    accData: accData,
                    position: position
                )
                fusedElements.append(accessibilityElement)
            }
        }
        
        print("🔗 Improved Fusion complete: \(fusedElements.count) total elements")
        print("   • OCR-enhanced: \(fusedElements.filter { $0.ocrData != nil }.count)")
        print("   • High-value accessibility: \(fusedElements.filter { $0.ocrData == nil && $0.accessibilityData != nil }.count)")
        
        return fusedElements
    }
    
    // MARK: - Helper Methods
    
    private func findNearbyAccessibilityElement(
        for ocrPosition: CGPoint,
        in accessibility: [AccessibilityData],
        maxDistance: Double
    ) -> AccessibilityData? {
        var bestMatch: (data: AccessibilityData, distance: Double)?
        
        for accData in accessibility {
            guard let accPosition = accData.position else { continue }
            
            let distance = coordinateSystem.spatialDistance(between: ocrPosition, and: accPosition)
            
            if distance <= maxDistance {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (accData, distance)
                }
            }
        }
        
        return bestMatch?.data
    }
    
    private func isHighValueAccessibilityElement(_ accData: AccessibilityData) -> Bool {
        // Only include accessibility elements that provide unique interaction value
        let role = accData.role
        
        switch role {
        case "AXButton", "AXMenuItem", "AXPopUpButton":
            // Interactive buttons without text
            return true
        case "AXTextField", "AXTextArea":
            // Text input fields
            return true
        case "AXCheckBox", "AXRadioButton":
            // Form controls
            return true
        case "AXSlider", "AXProgressIndicator":
            // UI controls
            return true
        case "AXScrollArea":
            // Scrollable regions (only if large enough)
            if let size = accData.size {
                return size.width > 100 && size.height > 100
            }
            return false
        case "AXRow", "AXCell":
            // Table/list items (only if they have meaningful content)
            return accData.title != nil || accData.description != nil
        default:
            return false
        }
    }
    
    private func createOCRPrimaryElement(
        ocrData: OCRData,
        position: CGPoint,
        accessibilityEnhancement: AccessibilityData?
    ) -> UIElement {
        // Determine enhanced clickability
        let isClickable = determineEnhancedClickability(
            ocrData: ocrData,
            accessibilityData: accessibilityEnhancement
        )
        
        // Enhanced element type
        let type = determineEnhancedType(
            ocrData: ocrData,
            accessibilityData: accessibilityEnhancement
        )
        
        // Calculate enhanced confidence
        let confidence = calculateEnhancedConfidence(
            ocrData: ocrData,
            accessibilityData: accessibilityEnhancement
        )
        
        return UIElement(
            type: type,
            position: position,  // CRITICAL: Always use OCR position
            size: ocrData.boundingBox.size,
            accessibilityData: accessibilityEnhancement,
            ocrData: ocrData,
            isClickable: isClickable,
            confidence: confidence
        )
    }
    
    private func createAccessibilityOnlyElement(
        accData: AccessibilityData,
        position: CGPoint
    ) -> UIElement {
        let isClickable = determineClickability(accData: accData, ocrData: nil)
        
        return UIElement(
            type: accData.role,
            position: position,
            size: accData.size ?? CGSize(width: 20, height: 20),
            accessibilityData: accData,
            ocrData: nil,
            isClickable: isClickable,
            confidence: 0.7
        )
    }
    
    private func determineEnhancedClickability(
        ocrData: OCRData,
        accessibilityData: AccessibilityData?
    ) -> Bool {
        // Primary: Accessibility role-based detection
        if let role = accessibilityData?.role {
            switch role {
            case "AXButton", "AXMenuItem", "AXPopUpButton", "AXCheckBox", "AXRadioButton":
                return true
            case "AXRow", "AXCell":
                return true
            default:
                break
            }
        }
        
        // Secondary: OCR text-based detection
        let text = ocrData.text.lowercased()
        let clickableKeywords = ["button", "click", "open", "close", "save", "cancel", "download"]
        return clickableKeywords.contains(where: { text.contains($0) })
    }
    
    private func determineEnhancedType(
        ocrData: OCRData,
        accessibilityData: AccessibilityData?
    ) -> String {
        if let role = accessibilityData?.role {
            return "\(role)+OCR"
        }
        return "TextContent"
    }
    
    private func calculateEnhancedConfidence(
        ocrData: OCRData,
        accessibilityData: AccessibilityData?
    ) -> Double {
        var confidence = Double(ocrData.confidence)  // Start with OCR confidence
        
        // Bonus for accessibility enhancement
        if accessibilityData != nil {
            confidence += 0.2
        }
        
        // Bonus for interactive elements
        if let accData = accessibilityData, accData.enabled {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
    
    // Legacy methods for compatibility
    private func determineClickability(accData: AccessibilityData?, ocrData: OCRData?) -> Bool {
        if let role = accData?.role {
            switch role {
            case "AXButton", "AXMenuItem", "AXPopUpButton", "AXCheckBox", "AXRadioButton":
                return true
            case "AXRow", "AXCell":
                return true
            default:
                return false
            }
        }
        return false
    }
} 