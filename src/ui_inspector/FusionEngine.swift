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
        
        // Set visualText from accessibility value (for text fields) or OCR text
        if let accValue = accessibilityData?.value, !accValue.isEmpty {
            self.visualText = accValue  // Use accessibility value (e.g., URL in address bar)
        } else {
            self.visualText = ocrData?.text  // Fallback to OCR text
        }
        
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
    
    // Performance optimization: Pre-computed coordinate cache
    private var accessibilityPositionCache: [(position: CGPoint, data: AccessibilityData)] = []
    private var ocrPositionCache: [(position: CGPoint, data: OCRData)] = []
    
    // NEW: Spatial grid optimization for O(1) spatial lookups
    private struct SpatialGrid {
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
    
    private var spatialGrid = SpatialGrid()
    
    init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
    }
    
    func fuse(accessibility: [AccessibilityData], ocr: [OCRData], coordinates: CoordinateMapping) -> [UIElement] {
        var fusedElements: [UIElement] = []
        
        // Performance optimization: Pre-compute and cache all positions + build spatial grid
        buildPositionCaches(accessibility: accessibility, ocr: ocr)
        
        // Smart optimization: Only use spatial grid for larger datasets
        let useGridOptimization = accessibilityPositionCache.count > 100
        if useGridOptimization {
            spatialGrid.buildGrid(from: accessibilityPositionCache)
        }
        
        // Strategy: OCR-Primary Fusion with optimized spatial lookup
        // 1. Start with OCR elements (perfect coordinates)
        // 2. Enhance with nearby accessibility metadata (clickability, roles)
        // 3. Add only high-value accessibility-only elements
        
        // Phase 1: Create OCR-primary elements with accessibility enhancement
        var usedAccessibilityIndices: Set<Int> = []
        
        // Batch processing optimization
        fusedElements.reserveCapacity(ocrPositionCache.count + accessibilityPositionCache.count / 4)
        
        // Performance optimization: Early termination tracking
        var perfectMatches = 0
        let maxPerfectMatches = min(ocrPositionCache.count / 2, 20) // Limit perfect match processing
        
        for (_, cachedOCR) in ocrPositionCache.enumerated() {
            // Choose optimal spatial lookup method
            let (nearbyAccessibility, accIndex) = useGridOptimization ?
                findNearbyAccessibilityElementWithGrid(for: cachedOCR.position, maxDistance: 30.0) :
                findNearbyAccessibilityElementLinear(for: cachedOCR.position, maxDistance: 30.0)
            
            let enhancedElement = createOCRPrimaryElement(
                ocrData: cachedOCR.data,
                position: cachedOCR.position,
                accessibilityEnhancement: nearbyAccessibility
            )
            
            // Early termination: Track perfect matches (high confidence + accessibility enhancement)
            if enhancedElement.confidence > 0.9 && nearbyAccessibility != nil {
                perfectMatches += 1
            }
            
            fusedElements.append(enhancedElement)
            
            // Mark accessibility element as used
            if let index = accIndex {
                usedAccessibilityIndices.insert(index)
            }
            
            // Early termination: If we have enough high-quality elements, skip remaining low-value OCR
            if perfectMatches >= maxPerfectMatches && cachedOCR.data.confidence < 0.7 {
                continue // Skip low-confidence OCR when we have plenty of good matches
            }
        }
        
        // Phase 2: Add high-value accessibility-only elements (optimized batch processing)
        let highValueElements = accessibilityPositionCache.enumerated().compactMap { (accIndex, cachedAcc) -> UIElement? in
            // Early termination: Skip if already used for enhancement
            guard !usedAccessibilityIndices.contains(accIndex) else { return nil }
            
            // Early termination: Quick high-value check with optimized isHighValueAccessibilityElement
            guard isHighValueAccessibilityElementOptimized(cachedAcc.data) else { return nil }
            
            return createAccessibilityOnlyElement(
                accData: cachedAcc.data,
                position: cachedAcc.position
            )
        }
        
        fusedElements.append(contentsOf: highValueElements)
        
        // Optimized logging - compute counts without filters for performance
        let totalElements = fusedElements.count
        let ocrEnhanced = ocrPositionCache.count
        let accessibilityOnly = highValueElements.count
        
        print("🔗 Improved Fusion complete: \(totalElements) total elements")
        print("   • OCR-enhanced: \(ocrEnhanced)")
        print("   • High-value accessibility: \(accessibilityOnly)")
        print("   • Optimization: \(useGridOptimization ? "Grid-based" : "Linear") spatial lookup")
        
        return fusedElements
    }
    
    // MARK: - Helper Methods
    
    private func buildPositionCaches(accessibility: [AccessibilityData], ocr: [OCRData]) {
        // Pre-compute all OCR positions
        ocrPositionCache = ocr.map { ocrData in
            let position = CGPoint(
                x: ocrData.boundingBox.midX,
                y: ocrData.boundingBox.midY
            )
            return (position: position, data: ocrData)
        }
        
        // Pre-compute all accessibility positions (filter out nil positions)
        accessibilityPositionCache = accessibility.compactMap { accData in
            guard let position = accData.position else { return nil }
            return (position: position, data: accData)
        }
    }
    
    // NEW: Optimized linear search for small datasets
    private func findNearbyAccessibilityElementLinear(
        for ocrPosition: CGPoint,
        maxDistance: Double
    ) -> (AccessibilityData?, Int?) {
        var bestMatch: (data: AccessibilityData, distance: Double, index: Int)?
        let maxDistanceSquared = maxDistance * maxDistance
        
        for (index, cachedAcc) in accessibilityPositionCache.enumerated() {
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
    
    // NEW: Grid-based spatial lookup - O(1) instead of O(n)
    private func findNearbyAccessibilityElementWithGrid(
        for ocrPosition: CGPoint,
        maxDistance: Double
    ) -> (AccessibilityData?, Int?) {
        // Get candidate indices from spatial grid
        let candidateIndices = spatialGrid.getNearbyIndices(for: ocrPosition, radius: maxDistance)
        
        var bestMatch: (data: AccessibilityData, distance: Double, index: Int)?
        let maxDistanceSquared = maxDistance * maxDistance
        
        for index in candidateIndices {
            guard index < accessibilityPositionCache.count else { continue }
            
            let cachedAcc = accessibilityPositionCache[index]
            
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
    
    private func isHighValueAccessibilityElement(_ accData: AccessibilityData) -> Bool {
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
    
    // NEW: Ultra-optimized version for batch processing
    private func isHighValueAccessibilityElementOptimized(_ accData: AccessibilityData) -> Bool {
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
        
        // Secondary: OCR text-based detection (only if needed)
        let text = ocrData.text
        if text.count > 3 { // Avoid processing very short text
            let lowercaseText = text.lowercased()
            return lowercaseText.contains("button") || lowercaseText.contains("click") || 
                   lowercaseText.contains("open") || lowercaseText.contains("close") || 
                   lowercaseText.contains("save") || lowercaseText.contains("cancel")
        }
        
        return false
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