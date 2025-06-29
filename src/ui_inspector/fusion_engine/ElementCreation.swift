import Foundation
import AppKit

// MARK: - Element Creation

class ElementCreation {
    
    // MARK: - Public Methods
    
    static func createUIElement(
        from accData: AccessibilityData?, 
        ocrData: OCRData?, 
        position: CGPoint
    ) -> UIElement {
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
    
    static func createOCRPrimaryElement(
        ocrData: OCRData,
        position: CGPoint,
        accessibilityEnhancement: AccessibilityData?
    ) -> UIElement {
        // Determine enhanced clickability
        let isClickable = determineEnhancedClickability(
            ocrData: ocrData,
            accessibilityData: accessibilityEnhancement
        )
        
        // Enhanced element type (optimized string creation)
        let type = accessibilityEnhancement?.role.appending("+OCR") ?? "TextContent"
        
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
    
    static func createAccessibilityOnlyElement(
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
    
    static func createUIElementFromVisual(
        visualElement: UIShapeCandidate,
        ocrElements: [OCRData],
        windowFrame: CGRect
    ) -> UIElement {
        // Find OCR text within the visual element
        let elementText = findOCRTextInButton(buttonCandidate: visualElement, ocrElements: ocrElements)
        
        // Adjust coordinates to be relative to window frame
        let adjustedPosition = CGPoint(
            x: windowFrame.origin.x + visualElement.boundingBox.origin.x,
            y: windowFrame.origin.y + visualElement.boundingBox.origin.y
        )
        
        let context = UIElement.ElementContext(
            purpose: "Visual \(visualElement.uiRole.rawValue)",
            region: "Shape detected",
            navigationPath: "",
            availableActions: [visualElement.interactionType.rawValue]
        )
        
        return UIElement(
            id: UUID().uuidString,
            type: "Shape_\(visualElement.type.rawValue)",
            position: adjustedPosition,
            size: visualElement.boundingBox.size,
            accessibilityData: nil,
            ocrData: nil,
            isClickable: visualElement.interactionType != .unknown,
            confidence: visualElement.confidence,
            semanticMeaning: visualElement.uiRole.rawValue,
            actionHint: visualElement.interactionType.rawValue,
            visualText: elementText.isEmpty ? nil : elementText,
            interactions: [],
            context: context
        )
    }
    
    static func enhanceElementWithButtonContext(
        existing: UIElement,
        buttonCandidate: UIShapeCandidate,
        ocrElements: [OCRData],
        windowFrame: CGRect
    ) -> UIElement {
        // Find OCR text within the button boundaries
        let buttonText = findOCRTextInButton(buttonCandidate: buttonCandidate, ocrElements: ocrElements)
        
        // Create enhanced context
        let enhancedContext = UIElement.ElementContext(
            purpose: existing.context?.purpose ?? "Interactive element",
            region: existing.context?.region ?? "Unknown region",
            navigationPath: existing.context?.navigationPath ?? "",
            availableActions: (existing.context?.availableActions ?? []) + [buttonCandidate.interactionType.rawValue]
        )
        
        // Enhanced action hint combining original with button context
        let enhancedActionHint = existing.actionHint?.isEmpty == false ? 
            "\(existing.actionHint!) (\(buttonCandidate.interactionType.rawValue) button)" :
            "\(buttonCandidate.interactionType.rawValue) button"
        
        // Enhanced semantic meaning
        let enhancedSemanticMeaning = !existing.semanticMeaning.isEmpty ?
            "\(existing.semanticMeaning) with \(buttonCandidate.uiRole.rawValue) visual" :
            "\(buttonCandidate.uiRole.rawValue) button"
        
        return UIElement(
            id: existing.id,
            type: existing.type,
            position: existing.position,
            size: existing.size,
            accessibilityData: existing.accessibilityData,
            ocrData: existing.ocrData,
            isClickable: existing.isClickable || (buttonCandidate.interactionType != .unknown),
            confidence: max(existing.confidence, buttonCandidate.confidence),
            semanticMeaning: enhancedSemanticMeaning,
            actionHint: enhancedActionHint,
            visualText: existing.visualText ?? buttonText,
            interactions: existing.interactions,
            context: enhancedContext
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func determineElementType(accData: AccessibilityData?, ocrData: OCRData?) -> String {
        if let accData = accData, ocrData != nil {
            return "\(accData.role)+OCR"
        } else if let accData = accData {
            return accData.role
        } else if ocrData != nil {
            return "TextContent"
        } else {
            return "Unknown"
        }
    }
    
    private static func calculateElementSize(accData: AccessibilityData?, ocrData: OCRData?) -> CGSize {
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
    
    private static func determineClickability(accData: AccessibilityData?, ocrData: OCRData?) -> Bool {
        // Check accessibility role for clickable elements
        if let role = accData?.role {
            switch role {
            case "AXButton", "AXMenuItem", "AXPopUpButton", "AXCheckBox", "AXRadioButton":
                return true
            case "AXRow", "AXCell":
                // Rows and cells might be clickable in lists
                return true
            case "AXImage":
                // Images might be clickable (profile pictures, avatars, thumbnails)
                return true
            case "AXStaticText":
                // Text might be clickable (links, timestamps, status indicators)
                if let text = accData?.description?.lowercased() ?? accData?.title?.lowercased() {
                    let clickableTextKeywords = ["link", "clickable", "timestamp"]
                    if clickableTextKeywords.contains(where: { text.contains($0) }) {
                        return true
                    }
                }
                return false
            case "AXGroup":
                // Groups might contain clickable content (message bubbles, contact cards)
                return true
            default:
                break
            }
        }
        
        // Check OCR text for clickable indicators - MUCH MORE RESTRICTIVE
        if let text = ocrData?.text.lowercased() {
            // Only match exact button-like words, not partial matches in sentences
            let exactButtonKeywords = ["click here", "press", "tap", "select", "save", "cancel", "submit", "login", "sign in", "sign up"]
            if exactButtonKeywords.contains(where: { text.contains($0) }) {
                return true
            }
            
            // Only match standalone action words (not embedded in sentences)
            let standaloneActionWords = ["click", "open", "close", "next", "back", "continue", "finish", "done"]
            for keyword in standaloneActionWords {
                // Check if the keyword appears as a standalone word (not part of a longer sentence)
                if text == keyword || text.hasPrefix("\(keyword) ") || text.hasSuffix(" \(keyword)") || text.contains(" \(keyword) ") {
                    return true
                }
            }
            
            // Time patterns might be clickable (message timestamps) - but only if short
            if text.count < 20 && text.range(of: "\\d{1,2}:\\d{2}", options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private static func calculateConfidence(accData: AccessibilityData?, ocrData: OCRData?) -> Double {
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
    
    private static func determineEnhancedClickability(
        ocrData: OCRData,
        accessibilityData: AccessibilityData?
    ) -> Bool {
        // Primary: Accessibility role-based detection (fast lookup)
        if let role = accessibilityData?.role {
            // Optimized role checking with early returns
            if role.hasPrefix("AXButton") || role.hasPrefix("AXMenuItem") || role.hasPrefix("AXPopUp") {
                return true
            }
            if role == "AXRow" || role == "AXCell" || role.hasPrefix("AXCheck") || role.hasPrefix("AXRadio") {
                return true
            }
        }
        
        // Secondary: OCR text-based detection (only if needed) - MUCH MORE RESTRICTIVE
        let text = ocrData.text
        if text.count > 3 { // Avoid processing very short text
            let lowercaseText = text.lowercased()
            
            // Only match exact button-like phrases
            let exactButtonKeywords = ["click here", "press", "tap", "select", "save", "cancel", "submit", "login", "sign in", "sign up"]
            if exactButtonKeywords.contains(where: { lowercaseText.contains($0) }) {
                return true
            }
            
            // Only match standalone action words (not embedded in sentences)
            let standaloneActionWords = ["click", "open", "close", "next", "back", "continue", "finish", "done"]
            for keyword in standaloneActionWords {
                // Check if the keyword appears as a standalone word (not part of a longer sentence)
                if lowercaseText == keyword || lowercaseText.hasPrefix("\(keyword) ") || lowercaseText.hasSuffix(" \(keyword)") || lowercaseText.contains(" \(keyword) ") {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func calculateEnhancedConfidence(
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
    
    private static func findOCRTextInButton(buttonCandidate: UIShapeCandidate, ocrElements: [OCRData]) -> String {
        var foundTexts: [String] = []
        
        for ocrElement in ocrElements {
            // Check if OCR text overlaps with button boundaries
            let ocrRect = ocrElement.boundingBox
            let buttonRect = buttonCandidate.boundingBox
            
            // Calculate intersection
            let intersection = ocrRect.intersection(buttonRect)
            if !intersection.isEmpty {
                let ocrArea = ocrRect.width * ocrRect.height
                let overlapArea = intersection.width * intersection.height
                let overlapPercentage = overlapArea / ocrArea
                
                // If significant overlap (>20%) and decent confidence, include the text
                if overlapPercentage > 0.2 && ocrElement.confidence > 0.5 {
                    foundTexts.append(ocrElement.text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        // Join multiple texts with space, remove duplicates
        let uniqueTexts = Array(Set(foundTexts)).filter { !$0.isEmpty }
        return uniqueTexts.joined(separator: " ")
    }
    
    // MARK: - Fusion Workflow Helper Methods
    
    /// Process accessibility elements and create fused elements with nearby OCR
    static func fuseAccessibilityWithNearbyOCR(
        accessibility: [AccessibilityData],
        ocr: [OCRData],
        coordinateSystem: CoordinateSystem
    ) -> (fused: [UIElement], usedAcc: Set<Int>, usedOCR: Set<Int>) {
        
        var fusedElements: [UIElement] = []
        var usedOCRIndices: Set<Int> = []
        var usedAccessibilityIndices: Set<Int> = []
        
        // For each accessibility element (button, text field, etc.)
        for (accIndex, accessibilityElement) in accessibility.enumerated() {
            
            // Skip if this element doesn't have a position
            guard let accessibilityPosition = accessibilityElement.position else { continue }
            
            // Look for the closest OCR text near this accessibility element
            let closestOCRMatch = SpatialOptimization.findClosestOCRTextNear(
                position: accessibilityPosition,
                in: ocr,
                excluding: usedOCRIndices,
                coordinateSystem: coordinateSystem
            )
            
            // If we found nearby text, combine them into one enhanced element
            if let ocrMatch = closestOCRMatch {
                let enhancedElement = ElementCreation.createUIElement(
                    from: accessibilityElement,
                    ocrData: ocrMatch.data,
                    position: accessibilityPosition
                )
                
                fusedElements.append(enhancedElement)
                usedAccessibilityIndices.insert(accIndex)
                usedOCRIndices.insert(ocrMatch.index)
            }
        }
        
        return (fusedElements, usedAccessibilityIndices, usedOCRIndices)
    }
    
    /// Create elements from remaining accessibility data (not used in fusion)
    static func addRemainingAccessibilityElements(
        accessibility: [AccessibilityData],
        alreadyUsed: Set<Int>
    ) -> [UIElement] {
        
        var accessibilityOnlyElements: [UIElement] = []
        
        // Go through all accessibility elements
        for (accIndex, accessibilityElement) in accessibility.enumerated() {
            // Skip if we already used this element in fusion
            guard !alreadyUsed.contains(accIndex) else { continue }
            // Skip if this element doesn't have a position
            guard let position = accessibilityElement.position else { continue }
            
            // Create a UI element from just the accessibility data
            let accessibilityOnlyElement = ElementCreation.createUIElement(
                from: accessibilityElement,
                ocrData: nil,
                position: position
            )
            accessibilityOnlyElements.append(accessibilityOnlyElement)
        }
        
        return accessibilityOnlyElements
    }
    
    /// Create elements from remaining OCR data (not used in fusion)
    static func addRemainingOCRElements(
        ocr: [OCRData],
        alreadyUsed: Set<Int>
    ) -> [UIElement] {
        
        var ocrOnlyElements: [UIElement] = []
        
        // Go through all OCR text elements
        for (ocrIndex, ocrElement) in ocr.enumerated() {
            // Skip if we already used this OCR text in fusion
            guard !alreadyUsed.contains(ocrIndex) else { continue }
            
                    // Calculate position (top-left corner of the text's bounding box)
        let ocrPosition = CGPoint(
            x: ocrElement.boundingBox.origin.x,
            y: ocrElement.boundingBox.origin.y
        )
            
            // Create a UI element from just the OCR data
            let ocrOnlyElement = ElementCreation.createUIElement(
                from: nil,
                ocrData: ocrElement,
                position: ocrPosition
            )
            ocrOnlyElements.append(ocrOnlyElement)
        }
        
        return ocrOnlyElements
    }
    
    /// Enhance OCR elements with nearby accessibility data for advanced fusion
    static func enhanceOCRWithAccessibilityData(
        ocrCache: [(position: CGPoint, data: OCRData)],
        accessibilityCache: [(position: CGPoint, data: AccessibilityData)],
        spatialGrid: SpatialOptimization.SpatialGrid,
        useGridOptimization: Bool
    ) -> (elements: [UIElement], usedAccessibilityIndices: Set<Int>) {
        
        var enhancedElements: [UIElement] = []
        var usedAccessibilityIndices: Set<Int> = []
        var usedOCRIndices: Set<Int> = []
        
        // Performance tracking
        var perfectMatches = 0
        let maxPerfectMatches = min(ocrCache.count / 2, 20) // Don't spend too much time on perfect matching
        
        // Reserve space for better performance
        enhancedElements.reserveCapacity(ocrCache.count + accessibilityCache.count / 4)
        
        // STEP 1: First pass - handle text field + placeholder text merging
        for (accessibilityIndex, accessibilityEntry) in accessibilityCache.enumerated() {
            // Skip if already used
            guard !usedAccessibilityIndices.contains(accessibilityIndex) else { continue }
            
            // Check if this is a text input field
            if isTextInputField(accessibilityEntry.data) {
                // Find OCR text inside this text field
                let containedOCRText = findOCRTextInsideTextField(
                    textField: accessibilityEntry,
                    ocrCache: ocrCache,
                    usedOCRIndices: usedOCRIndices
                )
                
                if let (ocrText, ocrIndex) = containedOCRText {
                    // Create merged text field element with placeholder format
                    let mergedElement = createTextFieldWithPlaceholder(
                        textFieldData: accessibilityEntry.data,
                        textFieldPosition: accessibilityEntry.position,
                        placeholderText: ocrText.text,
                        placeholderOCR: ocrText
                    )
                    
                    enhancedElements.append(mergedElement)
                    usedAccessibilityIndices.insert(accessibilityIndex)
                    usedOCRIndices.insert(ocrIndex)
                    continue
                }
            }
        }
        
        // STEP 2: Second pass - handle remaining OCR elements
        for (ocrIndex, ocrCacheEntry) in ocrCache.enumerated() {
            // Skip if already used in text field merging
            guard !usedOCRIndices.contains(ocrIndex) else { continue }
            
            // Find the closest accessibility element to this OCR text
            let (nearbyAccessibilityData, accessibilityIndex) = findNearbyAccessibilityElement(
                near: ocrCacheEntry.position,
                in: accessibilityCache,
                spatialGrid: spatialGrid,
                useGridOptimization: useGridOptimization
            )
            
            // Create an enhanced element (OCR + accessibility data if found)
            let enhancedElement = ElementCreation.createOCRPrimaryElement(
                ocrData: ocrCacheEntry.data,
                position: ocrCacheEntry.position, // Use OCR position (more accurate)
                accessibilityEnhancement: nearbyAccessibilityData
            )
            
            enhancedElements.append(enhancedElement)
            
            // Track which accessibility elements we've used
            if let index = accessibilityIndex {
                usedAccessibilityIndices.insert(index)
            }
            
            // Performance optimization: Track perfect matches
            if enhancedElement.confidence > 0.9 && nearbyAccessibilityData != nil {
                perfectMatches += 1
            }
            
            // Performance optimization: Skip low-quality OCR if we have enough good matches
            if perfectMatches >= maxPerfectMatches && ocrCacheEntry.data.confidence < 0.7 {
                continue
            }
        }
        
        return (enhancedElements, usedAccessibilityIndices)
    }
    
    /// Add only high-value accessibility elements for advanced fusion
    static func addHighValueAccessibilityElements(
        accessibilityCache: [(position: CGPoint, data: AccessibilityData)],
        alreadyUsed: Set<Int>
    ) -> [UIElement] {
        
        // Only add accessibility elements that are really valuable (buttons, text fields, etc.)
        let highValueElements = accessibilityCache.enumerated().compactMap { (index, cacheEntry) -> UIElement? in
            
            // Skip if we already used this accessibility element
            guard !alreadyUsed.contains(index) else { return nil }
            
            // Skip if this isn't a high-value element (like a button or text field)
            guard SpatialOptimization.isHighValueAccessibilityElementOptimized(cacheEntry.data) else { return nil }
            
            // Create element from accessibility data only
            return ElementCreation.createAccessibilityOnlyElement(
                accData: cacheEntry.data,
                position: cacheEntry.position
            )
        }
        
        return highValueElements
    }
    
    // MARK: - Text Field Merging Methods
    
    private static func isTextInputField(_ accessibilityData: AccessibilityData) -> Bool {
        let role = accessibilityData.role.lowercased()
        return role.contains("textfield") || 
               role.contains("textarea") || 
               role.contains("searchfield") ||
               role == "axtextfield" ||
               role == "axtextarea" ||
               role == "axsearchfield"
    }
    
    private static func findOCRTextInsideTextField(
        textField: (position: CGPoint, data: AccessibilityData),
        ocrCache: [(position: CGPoint, data: OCRData)],
        usedOCRIndices: Set<Int>
    ) -> (ocrData: OCRData, index: Int)? {
        
        // Get text field bounds
        guard let textFieldSize = textField.data.size else { return nil }
        
        // Accessibility positions are typically top-left corners, not centers
        let textFieldRect = CGRect(
            x: textField.position.x,
            y: textField.position.y,
            width: textFieldSize.width,
            height: textFieldSize.height
        )
        
        // Find OCR text that falls within the text field bounds
        for (ocrIndex, ocrEntry) in ocrCache.enumerated() {
            // Skip if already used
            guard !usedOCRIndices.contains(ocrIndex) else { continue }
            
            // Check if OCR position is inside text field
            if textFieldRect.contains(ocrEntry.position) {
                print("✅ Merged text field with placeholder: '\(ocrEntry.data.text)'")
                return (ocrEntry.data, ocrIndex)
            }
        }
        return nil
    }
    
    private static func createTextFieldWithPlaceholder(
        textFieldData: AccessibilityData,
        textFieldPosition: CGPoint,
        placeholderText: String,
        placeholderOCR: OCRData
    ) -> UIElement {
        
        // Get focus state
        let focusState = textFieldData.focused ? "[FOCUSED]" : "[UNFOCUSED]"
        
        // Create semantic meaning with placeholder format
        let semanticMeaning = textFieldData.description ?? textFieldData.role
        let enhancedSemanticMeaning = "\(semanticMeaning),plchldr:\(placeholderText)\(focusState)"
        
        // Create enhanced visual text for display
        let enhancedVisualText = "\(semanticMeaning),plchldr:\(placeholderText)\(focusState)"
        
        // Calculate confidence based on both accessibility and OCR
        let confidence = min(0.95, (placeholderOCR.confidence + 0.8) / 2.0)
        
        return UIElement(
            id: UUID().uuidString,
            type: "AXTextField+OCR",
            position: textFieldPosition,
            size: textFieldData.size ?? CGSize(width: 100, height: 30),
            accessibilityData: textFieldData,
            ocrData: placeholderOCR,
            isClickable: true,
            confidence: Double(confidence),
            semanticMeaning: enhancedSemanticMeaning,
            actionHint: "Text input with placeholder",
            visualText: enhancedVisualText,
            interactions: ["click", "type", "focus"],
            context: UIElement.ElementContext(
                purpose: "Text input field with placeholder text",
                region: "Input area",
                navigationPath: "",
                availableActions: ["click", "type", "focus", "clear"]
            )
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func findNearbyAccessibilityElement(
        near ocrPosition: CGPoint,
        in accessibilityCache: [(position: CGPoint, data: AccessibilityData)],
        spatialGrid: SpatialOptimization.SpatialGrid,
        useGridOptimization: Bool
    ) -> (data: AccessibilityData?, index: Int?) {
        
        // Choose the best search method based on dataset size
        if useGridOptimization {
            return SpatialOptimization.findNearbyAccessibilityElementWithGrid(
                for: ocrPosition,
                maxDistance: 30.0, // Look within 30 pixels
                in: accessibilityCache,
                spatialGrid: spatialGrid
            )
        } else {
            return SpatialOptimization.findNearbyAccessibilityElementLinear(
                for: ocrPosition,
                maxDistance: 30.0,
                in: accessibilityCache
            )
        }
    }
}