#!/usr/bin/env swift

import Foundation
import Vision
import AppKit
import ApplicationServices

// MARK: - Data Structures

struct UIElement {
    let id: String
    let type: String
    let position: CGPoint
    let size: CGSize
    let accessibilityData: AccessibilityData?
    let ocrData: OCRData?
    let isClickable: Bool
    let confidence: Double
    let semanticMeaning: String
    let actionHint: String?
    let visualText: String?
    let interactions: [String]
    let context: ElementContext?
    
    struct ElementContext {
        let purpose: String
        let region: String
        let navigationPath: String
        let availableActions: [String]
    }
    
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

struct AccessibilityData {
    let role: String
    let description: String?
    let title: String?
    let help: String?
    let enabled: Bool
    let focused: Bool
    let position: CGPoint?
    let size: CGSize?
    let element: AXUIElement?
    let subrole: String?
    let value: String?
    let selected: Bool
    let parent: String?
    let children: [String]
}

struct OCRData {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct CompleteUIMap {
    let windowTitle: String
    let windowFrame: CGRect
    let elements: [UIElement]
    let timestamp: Date
    let processingTime: TimeInterval
    let performance: PerformanceMetrics
    let summary: UIMapSummary
    
    struct PerformanceMetrics {
        let accessibilityTime: TimeInterval
        let screenshotTime: TimeInterval
        let ocrTime: TimeInterval
        let fusionTime: TimeInterval
        let totalElements: Int
        let fusedElements: Int
        let memoryUsage: UInt64
    }
    
    struct UIMapSummary {
        let clickableElements: [UIElement]
        let textContent: [String]
        let suggestedActions: [String]
        let confidence: Double
        
        init(from elements: [UIElement]) {
            self.clickableElements = elements.filter { $0.isClickable }
            self.textContent = elements.compactMap { $0.visualText }
            self.suggestedActions = elements.compactMap { $0.actionHint }
            self.confidence = elements.isEmpty ? 0.0 : elements.map { $0.confidence }.reduce(0, +) / Double(elements.count)
        }
    }
}

// MARK: - Vision OCR Handler

class VisionOCRHandler {
    
    func extractTextFromImage(_ image: NSImage, completion: @escaping ([OCRData]) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to convert NSImage to CGImage")
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("❌ VisionOCR Error: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let ocrResults = self?.processVisionResults(request.results) ?? []
            completion(ocrResults)
        }
        
        // PERFORMANCE: Configure for speed while maintaining completeness
        request.recognitionLevel = .fast  // 3x faster than .accurate
        request.usesLanguageCorrection = false  // Skip language correction for speed
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.005  // Detect even tiny text for completeness
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Failed to perform Vision request: \(error)")
            completion([])
        }
    }
    
    private func processVisionResults(_ results: [VNObservation]?) -> [OCRData] {
        guard let observations = results as? [VNRecognizedTextObservation] else {
            return []
        }
        
        var ocrData: [OCRData] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            let boundingBox = observation.boundingBox
            
            // Convert normalized coordinates to actual pixel coordinates
            // Note: VisionOCR uses normalized coordinates (0-1), we'll need screen dimensions
            let ocrItem = OCRData(
                text: text,
                confidence: confidence,
                boundingBox: boundingBox
            )
            
            ocrData.append(ocrItem)
        }
        
        return ocrData.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Accessibility Inspector

class AccessibilityInspector {
    private static var cachedWindowData: [String: Any] = [:]
    private static var cachedElements: [AccessibilityData] = []
    private static var lastCacheTime: Date = Date.distantPast
    private static let cacheTimeout: TimeInterval = 0.2 // 200ms cache for accessibility
    
    func inspectFinderWindow() -> (windowData: [String: Any], elements: [AccessibilityData]) {
        // PERFORMANCE: Ultra-fast caching for real-time performance
        let now = Date()
        if now.timeIntervalSince(Self.lastCacheTime) < Self.cacheTimeout,
           !Self.cachedElements.isEmpty {
            return (Self.cachedWindowData, Self.cachedElements)
        }
        var windowData: [String: Any] = [:]
        var elements: [AccessibilityData] = []
        
        // Get Finder application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let finderApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            print("❌ Finder not running")
            return ([:], [])
        }
        
        // Get accessibility element for Finder
        let finderElement = AXUIElementCreateApplication(finderApp.processIdentifier)
        
        // Get windows
        var windowsRef: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(finderElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard windowsResult == .success,
              let windows = windowsRef as? [AXUIElement],
              let firstWindow = windows.first else {
            print("❌ No Finder windows found")
            return ([:], [])
        }
        
        // Get window properties
        windowData = extractWindowData(firstWindow)
        
        // Get all UI elements in the window
        elements = extractUIElements(firstWindow)
        
        // Cache the results for performance
        Self.cachedWindowData = windowData
        Self.cachedElements = elements
        Self.lastCacheTime = now
        
        return (windowData, elements)
    }
    
    private func extractWindowData(_ window: AXUIElement) -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Title
        if let title = getStringAttribute(window, kAXTitleAttribute) {
            data["title"] = title
        }
        
        // Position
        if let position = getPointAttribute(window, kAXPositionAttribute) {
            data["position"] = ["x": position.x, "y": position.y]
        }
        
        // Size
        if let size = getSizeAttribute(window, kAXSizeAttribute) {
            data["size"] = ["width": size.width, "height": size.height]
        }
        
        // Role
        if let role = getStringAttribute(window, kAXRoleAttribute) {
            data["role"] = role
        }
        
        return data
    }
    
    private func extractUIElements(_ window: AXUIElement) -> [AccessibilityData] {
        var elements: [AccessibilityData] = []
        
        // Get all children recursively
        let allElements = getAllChildrenRecursively(window)
        
        for element in allElements {
            if let accessibilityData = createAccessibilityData(element) {
                elements.append(accessibilityData)
            }
        }
        
        return elements
    }
    
    private func getAllChildrenRecursively(_ element: AXUIElement) -> [AXUIElement] {
        var allElements: [AXUIElement] = []
        
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success, let children = childrenRef as? [AXUIElement] {
            for child in children {
                allElements.append(child)
                // Recursively get children of children
                allElements.append(contentsOf: getAllChildrenRecursively(child))
            }
        }
        
        return allElements
    }
    
    private func createAccessibilityData(_ element: AXUIElement) -> AccessibilityData? {
        guard let role = getStringAttribute(element, kAXRoleAttribute) else {
            return nil
        }
        
        // Include more element types for better coverage
        let relevantRoles = ["AXButton", "AXTextField", "AXStaticText", "AXImage", "AXGroup", 
                           "AXLink", "AXMenuItem", "AXCell", "AXRow", "AXColumn", "AXOutline",
                           "AXList", "AXTable", "AXScrollArea", "AXSplitGroup", "AXPopUpButton",
                           "AXCheckBox", "AXRadioButton", "AXSlider", "AXProgressIndicator"]
        guard relevantRoles.contains(role) else {
            return nil
        }
        
        let title = getStringAttribute(element, kAXTitleAttribute)
        let description = getStringAttribute(element, kAXDescriptionAttribute)
        let help = getStringAttribute(element, kAXHelpAttribute)
        let enabled = getBoolAttribute(element, kAXEnabledAttribute) ?? false
        let focused = getBoolAttribute(element, kAXFocusedAttribute) ?? false
        let position = getPointAttribute(element, kAXPositionAttribute)
        let size = getSizeAttribute(element, kAXSizeAttribute)
        let subrole = getStringAttribute(element, kAXSubroleAttribute)
        let value = getStringAttribute(element, kAXValueAttribute)
        let selected = getBoolAttribute(element, kAXSelectedAttribute) ?? false
        
        // Get parent and children info for hierarchy
        let parent = getParentInfo(element)
        let children = getChildrenInfo(element)
        
        return AccessibilityData(
            role: role,
            description: description,
            title: title,
            help: help,
            enabled: enabled,
            focused: focused,
            position: position,
            size: size,
            element: element,
            subrole: subrole,
            value: value,
            selected: selected,
            parent: parent,
            children: children
        )
    }
    
    // MARK: - Accessibility Attribute Helpers
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        return result == .success ? (valueRef as? String) : nil
    }
    
    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        return result == .success ? (valueRef as? Bool) : nil
    }
    
    private func getPointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        
        if result == .success, let value = valueRef {
            var point = CGPoint.zero
            let success = AXValueGetValue(value as! AXValue, .cgPoint, &point)
            return success ? point : nil
        }
        return nil
    }
    
    private func getSizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        
        if result == .success, let value = valueRef {
            var size = CGSize.zero
            let success = AXValueGetValue(value as! AXValue, .cgSize, &size)
            return success ? size : nil
        }
        return nil
    }
    
    private func getParentInfo(_ element: AXUIElement) -> String? {
        var parentRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef)
        
        if result == .success, let parentRef = parentRef {
            let parent = parentRef as! AXUIElement
            return getStringAttribute(parent, kAXRoleAttribute) ?? "UnknownParent"
        }
        return nil
    }
    
    private func getChildrenInfo(_ element: AXUIElement) -> [String] {
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success, let childrenRef = childrenRef {
            let children = childrenRef as! [AXUIElement]
            return children.compactMap { child in
                getStringAttribute(child, kAXRoleAttribute)
            }
        }
        return []
    }
}

// MARK: - UI Fusion Engine

class UIFusionEngine {
    
    // Enhanced fusion with intelligent spatial correlation
    func fuseAccessibilityWithOCR(
        accessibilityElements: [AccessibilityData],
        ocrElements: [OCRData],
        windowFrame: CGRect
    ) -> [UIElement] {
        
        var fusedElements: [UIElement] = []
        var usedOCRElements: Set<Int> = []
        
        // Step 1: Try to match accessibility elements with nearby OCR text
        for accElement in accessibilityElements {
            guard let accPosition = getAccessibilityElementPosition(accElement),
                  let accSize = getAccessibilityElementSize(accElement) else {
                // Create accessibility-only element if no position data
                let uiElement = UIElement(
                    type: accElement.role,
                    position: CGPoint.zero,
                    size: CGSize.zero,
                    accessibilityData: accElement,
                    ocrData: nil,
                    isClickable: isClickableRole(accElement.role),
                    confidence: 0.6 // Lower confidence without position
                )
                fusedElements.append(uiElement)
                continue
            }
            
            // Find best matching OCR text for this accessibility element
            let matchResult = findBestOCRMatch(
                for: accElement,
                position: accPosition,
                size: accSize,
                in: ocrElements,
                windowFrame: windowFrame,
                usedIndices: usedOCRElements
            )
            
            if let (ocrElement, ocrIndex) = matchResult {
                // Successfully matched - create fused element
                usedOCRElements.insert(ocrIndex)
                
                let fusedElement = UIElement(
                    type: "\(accElement.role)+OCR",
                    position: accPosition,
                    size: accSize,
                    accessibilityData: accElement,
                    ocrData: ocrElement,
                    isClickable: isClickableRole(accElement.role),
                    confidence: calculateFusionConfidence(accElement, ocrElement)
                )
                fusedElements.append(fusedElement)
            } else {
                // No OCR match - create accessibility-only element
                let accOnlyElement = UIElement(
                    type: accElement.role,
                    position: accPosition,
                    size: accSize,
                    accessibilityData: accElement,
                    ocrData: nil,
                    isClickable: isClickableRole(accElement.role),
                    confidence: 0.7
                )
                fusedElements.append(accOnlyElement)
            }
        }
        
        // Step 2: Add remaining OCR elements that weren't matched
        for (index, ocrElement) in ocrElements.enumerated() {
            if !usedOCRElements.contains(index) {
                let actualFrame = convertNormalizedToActual(ocrElement.boundingBox, windowFrame)
                
                let ocrOnlyElement = UIElement(
                    type: inferOCRElementType(ocrElement),
                    position: actualFrame.origin,
                    size: actualFrame.size,
                    accessibilityData: nil,
                    ocrData: ocrElement,
                    isClickable: inferClickability(from: ocrElement),
                    confidence: Double(ocrElement.confidence)
                )
                fusedElements.append(ocrOnlyElement)
            }
        }
        
        // Step 3: Sort by confidence and position for better organization
        fusedElements.sort { element1, element2 in
            if abs(element1.confidence - element2.confidence) > 0.1 {
                return element1.confidence > element2.confidence
            }
            return element1.position.y < element2.position.y // Top to bottom
        }
        
        return fusedElements
    }
    
    // MARK: - Spatial Correlation Algorithms
    
    private func findBestOCRMatch(
        for accElement: AccessibilityData,
        position: CGPoint,
        size: CGSize,
        in ocrElements: [OCRData],
        windowFrame: CGRect,
        usedIndices: Set<Int>
    ) -> (OCRData, Int)? {
        
        var bestMatch: (OCRData, Int, Double)? = nil // (element, index, score)
        
        for (index, ocrElement) in ocrElements.enumerated() {
            if usedIndices.contains(index) { continue }
            
            let score = calculateSpatialMatchScore(
                accPosition: position,
                accSize: size,
                ocrElement: ocrElement,
                windowFrame: windowFrame,
                accRole: accElement.role
            )
            
            if score > 0.3, // Minimum threshold
               bestMatch?.2 ?? 0 < score {
                bestMatch = (ocrElement, index, score)
            }
        }
        
        return bestMatch.map { ($0.0, $0.1) }
    }
    
    private func calculateSpatialMatchScore(
        accPosition: CGPoint,
        accSize: CGSize,
        ocrElement: OCRData,
        windowFrame: CGRect,
        accRole: String
    ) -> Double {
        
        let ocrFrame = convertNormalizedToActual(ocrElement.boundingBox, windowFrame)
        let accFrame = CGRect(origin: accPosition, size: accSize)
        
        // 1. Distance score (closer = better)
        let distance = distanceBetweenFrames(accFrame, ocrFrame)
        let maxDistance: CGFloat = 100 // pixels
        let distanceScore = max(0, 1.0 - Double(distance / maxDistance))
        
        // 2. Overlap score (overlapping = much better)
        let overlapScore = Double(calculateOverlapRatio(accFrame, ocrFrame)) * 2.0
        
        // 3. Size compatibility score
        let sizeScore = calculateSizeCompatibility(accFrame, ocrFrame)
        
        // 4. Semantic compatibility score
        let semanticScore = calculateSemanticCompatibility(accRole, ocrElement.text)
        
        // 5. OCR confidence score
        let confidenceScore = Double(ocrElement.confidence)
        
        // Weighted combination
        let totalScore = (
            distanceScore * 0.3 +
            overlapScore * 0.4 +
            sizeScore * 0.1 +
            semanticScore * 0.15 +
            confidenceScore * 0.05
        )
        
        return min(1.0, totalScore)
    }
    
    private func distanceBetweenFrames(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let center1 = CGPoint(x: frame1.midX, y: frame1.midY)
        let center2 = CGPoint(x: frame2.midX, y: frame2.midY)
        return sqrt(pow(center1.x - center2.x, 2) + pow(center1.y - center2.y, 2))
    }
    
    private func calculateOverlapRatio(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let intersection = frame1.intersection(frame2)
        if intersection.isNull || intersection.isEmpty {
            return 0.0
        }
        let unionArea = frame1.union(frame2).width * frame1.union(frame2).height
        let intersectionArea = intersection.width * intersection.height
        return intersectionArea / unionArea
    }
    
    private func calculateSizeCompatibility(_ accFrame: CGRect, _ ocrFrame: CGRect) -> Double {
        let accArea = accFrame.width * accFrame.height
        let ocrArea = ocrFrame.width * ocrFrame.height
        
        if accArea == 0 || ocrArea == 0 { return 0.5 }
        
        let ratio = min(accArea, ocrArea) / max(accArea, ocrArea)
        return Double(ratio)
    }
    
    private func calculateSemanticCompatibility(_ role: String, _ text: String) -> Double {
        let lowercaseText = text.lowercased()
        
        switch role {
        case "AXButton":
            // Buttons often have action words
            let buttonWords = ["click", "save", "cancel", "ok", "yes", "no", "submit", "send", "share", "edit", "delete", "add", "remove", "close", "open", "search", "find", "go", "back", "forward", "next", "previous", "play", "pause", "stop"]
            if buttonWords.contains(where: { lowercaseText.contains($0) }) {
                return 0.8
            }
            // Short text is often button text
            if text.count <= 20 && !text.contains(" ") {
                return 0.6
            }
            return 0.3
            
        case "AXStaticText":
            // Static text is usually longer descriptions
            if text.count > 10 {
                return 0.7
            }
            return 0.4
            
        case "AXTextField":
            // Text fields might have placeholder text or current values
            return 0.5
            
        default:
            return 0.3
        }
    }
    
    // MARK: - Helper Functions
    
    private func convertNormalizedToActual(_ normalizedRect: CGRect, _ windowFrame: CGRect) -> CGRect {
        return CGRect(
            x: normalizedRect.origin.x * windowFrame.width,
            y: normalizedRect.origin.y * windowFrame.height,
            width: normalizedRect.width * windowFrame.width,
            height: normalizedRect.height * windowFrame.height
        )
    }
    
    private func getAccessibilityElementPosition(_ element: AccessibilityData) -> CGPoint? {
        return element.position
    }
    
    private func getAccessibilityElementSize(_ element: AccessibilityData) -> CGSize? {
        return element.size
    }
    
    private func isClickableRole(_ role: String) -> Bool {
        let clickableRoles = ["AXButton", "AXTextField", "AXLink", "AXMenuItem", "AXPopUpButton",
                             "AXCheckBox", "AXRadioButton", "AXSlider", "AXCell", "AXRow",
                             "AXOutline", "AXImage", "AXGroup"]
        return clickableRoles.contains(role)
    }
    
    private func inferOCRElementType(_ ocrElement: OCRData) -> String {
        let text = ocrElement.text.lowercased()
        
        // Infer type based on text content and characteristics
        if text.count <= 3 && (text.contains("×") || text.contains("−") || text.contains("⚫")) {
            return "WindowControl"
        } else if text.count <= 20 && !text.contains(" ") {
            return "PossibleButton"
        } else if text.contains(".") && (text.contains("txt") || text.contains("pdf") || text.contains("jpg")) {
            return "FileName"
        } else if text.contains("/") || text.contains("\\") {
            return "FilePath"
        } else {
            return "TextContent"
        }
    }
    
    private func inferClickability(from ocrElement: OCRData) -> Bool {
        let type = inferOCRElementType(ocrElement)
        return ["WindowControl", "PossibleButton", "FileName"].contains(type)
    }
    
    private func calculateFusionConfidence(_ accElement: AccessibilityData, _ ocrElement: OCRData) -> Double {
        let baseConfidence = Double(ocrElement.confidence) * 0.7 + 0.3 // OCR confidence + accessibility presence
        let semanticBonus = calculateSemanticCompatibility(accElement.role, ocrElement.text) * 0.2
        return min(1.0, baseConfidence + semanticBonus)
    }
}

// MARK: - Screenshot Capture

class ScreenshotCapture {
    private static var cachedImage: NSImage?
    private static var lastCacheTime: Date = Date.distantPast
    private static let cacheTimeout: TimeInterval = 0.1 // 100ms cache
    
    func captureFinderWindow() -> NSImage? {
        // Ultra-fast caching for real-time performance
        let now = Date()
        if now.timeIntervalSince(Self.lastCacheTime) < Self.cacheTimeout,
           let cached = Self.cachedImage {
            return cached
        }
        
        print("📸 Capturing Finder window bounds")
        
        // OPTIMIZATION: Capture only the active Finder window, not full screen
        let image = captureWindowBounds()
        
        // Cache for immediate reuse
        Self.cachedImage = image
        Self.lastCacheTime = now
        
        return image
    }
    
    private func captureWindowBounds() -> NSImage? {
        // Get the frontmost Finder window bounds
        guard let finderWindow = getFinderWindowBounds() else {
            print("⚠️ No Finder window found, falling back to full screen")
            return captureToMemoryDirect()
        }
        
        print("📐 Finder window bounds: \(finderWindow)")
        
        // Capture only the window region using screencapture with -R flag
        let tempPath = "/tmp/ui_window_\(Int(Date().timeIntervalSince1970)).png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // -R x,y,w,h captures specific region
        let x = Int(finderWindow.origin.x)
        let y = Int(finderWindow.origin.y)  
        let w = Int(finderWindow.size.width)
        let h = Int(finderWindow.size.height)
        
        task.arguments = ["-x", "-t", "png", "-R", "\(x),\(y),\(w),\(h)", tempPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                // Async cleanup
                DispatchQueue.global(qos: .utility).async {
                    try? FileManager.default.removeItem(atPath: tempPath)
                }
                return image
            }
        } catch {
            print("❌ Window capture failed: \(error)")
        }
        
        // Fallback to full screen if window capture fails
        return captureToMemoryDirect()
    }
    
    private func getFinderWindowBounds() -> CGRect? {
        // Get all windows using CGWindowList
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find the frontmost Finder window
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowBounds = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  ownerName == "Finder",
                  layer == 0 else { // layer 0 = normal windows
                continue
            }
            
            // Extract bounds
            guard let x = windowBounds["X"] as? CGFloat,
                  let y = windowBounds["Y"] as? CGFloat,
                  let width = windowBounds["Width"] as? CGFloat,
                  let height = windowBounds["Height"] as? CGFloat,
                  width > 100, height > 100 else { // Filter out tiny windows
                continue
            }
            
            return CGRect(x: x, y: y, width: width, height: height)
        }
        
        return nil
    }
    
    private func captureToMemoryDirect() -> NSImage? {
        // PERFORMANCE: Try direct capture first, fallback to temp file
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // OPTIMIZATION: Use lower resolution for faster capture (OCR still works well)
        // -m: capture main display only, -x: no sounds, -t png: PNG format
        task.arguments = ["-m", "-x", "-t", "png", "-"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 && !data.isEmpty {
                return NSImage(data: data)
            }
        } catch {
            // Fallback to temp file method
        }
        
        // Fallback: Fast temp file capture
        let tempPath = "/tmp/ui_fast_\(Int(Date().timeIntervalSince1970)).png"
        let fallbackTask = Process()
        fallbackTask.launchPath = "/usr/sbin/screencapture"
        fallbackTask.arguments = ["-m", "-x", "-t", "png", tempPath]
        
        do {
            try fallbackTask.run()
            fallbackTask.waitUntilExit()
            
            if fallbackTask.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                // Async cleanup
                DispatchQueue.global(qos: .utility).async {
                    try? FileManager.default.removeItem(atPath: tempPath)
                }
                return image
            }
        } catch {
            print("❌ Both capture methods failed: \(error)")
        }
        
        return nil
    }
    

}

// MARK: - Caching System

class UIMapCache {
    private var cache: [String: CompleteUIMap] = [:]
    private let maxCacheSize = 10
    private let cacheTimeout: TimeInterval = 30.0 // 30 seconds
    
    func getCachedMap(for key: String) -> CompleteUIMap? {
        guard let cachedMap = cache[key] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cachedMap.timestamp) > cacheTimeout {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cachedMap
    }
    
    func cacheMap(_ map: CompleteUIMap, for key: String) {
        // Remove oldest entries if cache is full
        if cache.count >= maxCacheSize {
            let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }
        
        cache[key] = map
    }
    
    func generateCacheKey(for app: NSRunningApplication, windowTitle: String?) -> String {
        let appName = app.localizedName ?? "unknown"
        let title = windowTitle ?? "main"
        return "\(appName)_\(title)"
    }
}

// MARK: - Adaptive Grid System

struct UniversalGrid {
    static let COLUMNS = 26         // A-Z (26 columns)
    static let ROWS = 30           // 1-30 (30 rows for full coverage)
    static let TOTAL_CELLS = 780   // 26 × 30 = 780 addressable positions
    
    static let COLUMN_RANGE = "A"..."Z"
    static let ROW_RANGE = 1...30
    
    static let TOP_LEFT = "A1"
    static let TOP_RIGHT = "Z1"
    static let BOTTOM_LEFT = "A30"
    static let BOTTOM_RIGHT = "Z30"
    static let CENTER = "M15"
}

struct AdaptiveGridPosition: Hashable, CustomStringConvertible {
    let column: Character  // A-Z
    let row: Int          // 1-30
    
    init(_ column: Character, _ row: Int) {
        precondition(column >= "A" && column <= "Z", "Column must be A-Z")
        precondition(row >= 1 && row <= 30, "Row must be 1-30")
        
        self.column = column
        self.row = row
    }
    
    init?(gridString: String) {
        guard gridString.count >= 2,
              let firstChar = gridString.first,
              firstChar >= "A" && firstChar <= "Z",
              let rowValue = Int(String(gridString.dropFirst())),
              rowValue >= 1 && rowValue <= 30 else {
            return nil
        }
        
        self.column = firstChar
        self.row = rowValue
    }
    
    var description: String {
        return "\(column)\(row)"
    }
    
    var columnIndex: Int {
        return Int(column.asciiValue! - 65)  // A=0, B=1, ..., Z=25
    }
    
    var rowIndex: Int {
        return row - 1  // 1-based to 0-based
    }
    
    var normalizedX: Double {
        return Double(columnIndex) / Double(UniversalGrid.COLUMNS - 1)
    }
    
    var normalizedY: Double {
        return Double(rowIndex) / Double(UniversalGrid.ROWS - 1)
    }
}

class AdaptiveDensityMapper {
    let windowSize: CGSize
    let windowOrigin: CGPoint
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    init(windowFrame: CGRect) {
        self.windowSize = windowFrame.size
        self.windowOrigin = windowFrame.origin
        
        self.cellWidth = windowSize.width / CGFloat(UniversalGrid.COLUMNS)
        self.cellHeight = windowSize.height / CGFloat(UniversalGrid.ROWS)
    }
    
    func gridPosition(for point: CGPoint) -> AdaptiveGridPosition {
        let relativeX = point.x - windowOrigin.x
        let relativeY = point.y - windowOrigin.y
        
        let colIndex = min(25, max(0, Int(relativeX / cellWidth)))
        let rowIndex = min(29, max(0, Int(relativeY / cellHeight)))
        
        let column = Character(UnicodeScalar(65 + colIndex)!)
        let row = rowIndex + 1
        
        return AdaptiveGridPosition(column, row)
    }
    
    func pixelPosition(for gridPos: AdaptiveGridPosition) -> CGPoint {
        let x = windowOrigin.x + (CGFloat(gridPos.columnIndex) * cellWidth) + (cellWidth / 2)
        let y = windowOrigin.y + (CGFloat(gridPos.rowIndex) * cellHeight) + (cellHeight / 2)
        
        return CGPoint(x: x, y: y)
    }
    
    func cellBounds(for gridPos: AdaptiveGridPosition) -> CGRect {
        let x = windowOrigin.x + (CGFloat(gridPos.columnIndex) * cellWidth)
        let y = windowOrigin.y + (CGFloat(gridPos.rowIndex) * cellHeight)
        
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }
    
    var gridDensity: GridDensityMetrics {
        return GridDensityMetrics(
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            pixelsPerCell: cellWidth * cellHeight,
            windowSize: windowSize
        )
    }
}

struct GridDensityMetrics {
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let pixelsPerCell: CGFloat
    let windowSize: CGSize
    
    var precision: GridPrecision {
        switch pixelsPerCell {
        case 0..<800:    return .high        // < 800 pixels per cell
        case 800..<1600: return .medium      // 800-1600 pixels per cell  
        case 1600..<3200: return .low        // 1600-3200 pixels per cell
        default:         return .veryLow     // > 3200 pixels per cell
        }
    }
    
    var recommendedMaxElements: Int {
        return UniversalGrid.TOTAL_CELLS  // Always show all elements for full visibility
    }
}

enum GridPrecision: String, CaseIterable {
    case high = "high"
    case medium = "medium" 
    case low = "low"
    case veryLow = "very_low"
}

enum GridRegion: String, CaseIterable {
    case toolbar = "TB"
    case sidebar = "SB"
    case main = "MC"
    case status = "ST"
    
    func contains(position: AdaptiveGridPosition) -> Bool {
        let x = position.normalizedX
        let y = position.normalizedY
        
        switch self {
        case .toolbar:  return y < 0.2  // Top 20%
        case .sidebar:  return x < 0.25 // Left 25%
        case .status:   return y > 0.85 // Bottom 15%
        case .main:     return x >= 0.25 && y >= 0.2 && y <= 0.85 // Main content area
        }
    }
}

struct GridMappedElement {
    let originalElement: UIElement
    let gridPosition: AdaptiveGridPosition
    let mappingConfidence: Double
    let importance: Int
    
    init(element: UIElement, mapper: AdaptiveDensityMapper) {
        self.originalElement = element
        self.gridPosition = mapper.gridPosition(for: element.position)
        self.mappingConfidence = Self.calculateMappingConfidence(element, mapper)
        self.importance = Self.calculateImportance(element)
    }
    
    var compressedRepresentation: String {
        let name = Self.compressElementName(originalElement)
        let readablePosition = makePositionReadable(gridPosition)
        return "\(name)@\(readablePosition)"
    }
    
    private func makePositionReadable(_ position: AdaptiveGridPosition) -> String {
        let x = position.normalizedX
        let y = position.normalizedY
        
        // ENHANCED: More precise region mapping for better toolbar detection
        let xRegion: Int
        if x < 0.2 { xRegion = 0 }      // Left 20%
        else if x < 0.7 { xRegion = 1 } // Center 50% 
        else { xRegion = 2 }            // Right 30%
        
        let yRegion: Int  
        if y < 0.2 { yRegion = 0 }      // Top 20% (toolbar area)
        else if y < 0.8 { yRegion = 1 } // Middle 60%
        else { yRegion = 2 }            // Bottom 20%
        
        let regions = [
            ["TopLeft", "TopCenter", "TopRight"],
            ["MidLeft", "Center", "MidRight"],
            ["BotLeft", "BotCenter", "BotRight"]
        ]
        
        return regions[yRegion][xRegion]
    }
    
    private static func calculateMappingConfidence(_ element: UIElement, _ mapper: AdaptiveDensityMapper) -> Double {
        let cellBounds = mapper.cellBounds(for: mapper.gridPosition(for: element.position))
        let elementBounds = CGRect(origin: element.position, size: element.size)
        
        let intersection = cellBounds.intersection(elementBounds)
        let intersectionArea = intersection.width * intersection.height
        let elementArea = elementBounds.width * elementBounds.height
        
        if elementArea == 0 { return 0.5 }
        
        let overlapRatio = intersectionArea / elementArea
        return min(1.0, max(0.0, overlapRatio))
    }
    
    private static func calculateImportance(_ element: UIElement) -> Int {
        var score = 0
        
        if element.isClickable { score += 10 }
        
        if let hint = element.actionHint {
            if hint.contains("search") || hint.contains("back") || hint.contains("close") {
                score += 5
            }
        }
        
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton": score += 8
            case "AXTextField": score += 7
            case "AXPopUpButton": score += 6
            default: break
            }
        }
        
        if let text = element.visualText, !text.isEmpty {
            if text.count > 2 && text.count < 20 { score += 3 }
        }
        
        // MAJOR boost for sidebar navigation elements
        if element.position.x < 200 { // Left sidebar area
            if let text = element.visualText, text.count > 3 {
                let navWords = ["downloads", "applications", "documents", "desktop", "airdrop", 
                               "recents", "favorites", "network", "macintosh", "icloud", "shared"]
                let lowercaseText = text.lowercased()
                if navWords.contains(where: { lowercaseText.contains($0) }) {
                    score += 25 // Highest priority for navigation items
                }
                else if !text.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                    score += 15 // High priority for any sidebar content
                }
            }
        }
        
        // Penalize noise elements
        if let text = element.visualText {
            if text.allSatisfy({ $0.isNumber }) || text.contains("//") || text.count <= 2 {
                score -= 10
            }
        }
        
        return score
    }
    
    private static func compressElementName(_ element: UIElement) -> String {
        var name = ""
        var elementType = ""
        
        // Determine element type first
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton": elementType = "btn:"
            case "AXTextField": elementType = "field:"
            case "AXImage": elementType = "img:"
            case "AXMenuItem": elementType = "menu:"
            case "AXPopUpButton": elementType = "popup:"
            case "AXStaticText": elementType = "text:"
            default: elementType = element.isClickable ? "click:" : ""
            }
        }
        
        // Get readable name
        if let visualText = element.visualText, !visualText.isEmpty {
            name = visualText
        } else if let accData = element.accessibilityData {
            name = accData.title ?? accData.description ?? accData.role
        } else {
            name = element.type
        }
        
        let cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        // AI-friendly symbol mapping (keep common icons but use fuller names)
        let symbolMap: [String: String] = [
            "search": "🔍Search", "back": "⬅Back", "forward": "➡Forward",
            "close": "✕Close", "add": "➕Add", "save": "💾Save", "share": "📤Share",
            "edit": "✏️Edit", "file": "📄File", "folder": "📁Folder", "image": "🖼️Image",
            "applications": "📱Apps", "downloads": "⬇Downloads", "documents": "📄Docs",
            "desktop": "🖥Desktop", "airdrop": "📡AirDrop", "recents": "🕒Recent",
            "icloud": "☁iCloud", "network": "🌐Network", "shared": "👥Shared"
        ]
        
        let lowerName = cleaned.lowercased()
        
        // Check for symbol mappings (fuller, AI-readable names)
        for (key, fullName) in symbolMap {
            if lowerName.contains(key) {
                return elementType + fullName
            }
        }
        
        // For navigation and file elements, use more descriptive names
        if elementType.isEmpty && lowerName.count > 2 {
            // Check if it's a file (has extension)
            if lowerName.contains(".") {
                let components = lowerName.components(separatedBy: ".")
                if components.count > 1 {
                    let ext = components.last ?? ""
                    let fileName = components.first ?? ""
                    return "file:\(fileName.prefix(8)).\(ext)"
                }
            }
            
            // For folders/navigation items, use full readable names
            if element.position.x < 200 { // Sidebar area
                return "nav:\(cleaned.prefix(12))"
            }
        }
        
        // Default: use type prefix + readable name (not cryptic abbreviation)
        let readableName = cleaned.isEmpty ? "Element" : String(cleaned.prefix(10))
        return elementType + readableName
    }
}

// MARK: - Collision Detection & Resolution

class GridCollisionDetector {
    private var gridOccupancy: [AdaptiveGridPosition: [GridMappedElement]] = [:]
    
    func detectCollisions(in elements: [GridMappedElement]) -> [GridCollision] {
        gridOccupancy.removeAll()
        
        // Build occupancy map
        for element in elements {
            if gridOccupancy[element.gridPosition] == nil {
                gridOccupancy[element.gridPosition] = []
            }
            gridOccupancy[element.gridPosition]!.append(element)
        }
        
        // Find collisions
        var collisions: [GridCollision] = []
        for (gridPos, occupants) in gridOccupancy {
            if occupants.count > 1 {
                collisions.append(GridCollision(
                    gridPosition: gridPos,
                    conflictingElements: occupants,
                    severity: calculateCollisionSeverity(occupants)
                ))
            }
        }
        
        return collisions.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }
    
    private func calculateCollisionSeverity(_ elements: [GridMappedElement]) -> CollisionSeverity {
        let maxConfidence = elements.map { $0.mappingConfidence }.max() ?? 0
        let maxImportance = elements.map { $0.importance }.max() ?? 0
        
        if maxImportance > 15 && maxConfidence > 0.8 {
            return .critical
        } else if maxImportance > 10 || maxConfidence > 0.6 {
            return .high
        } else if maxImportance > 5 {
            return .medium
        } else {
            return .low
        }
    }
}

struct GridCollision {
    let gridPosition: AdaptiveGridPosition
    let conflictingElements: [GridMappedElement]
    let severity: CollisionSeverity
    
    var primaryElement: GridMappedElement {
        return conflictingElements.max { $0.importance < $1.importance }!
    }
    
    var secondaryElements: [GridMappedElement] {
        return conflictingElements.filter { $0.originalElement.id != primaryElement.originalElement.id }
    }
}

enum CollisionSeverity: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

class GridCollisionResolver {
    
    func resolveCollisions(_ collisions: [GridCollision], mapper: AdaptiveDensityMapper) -> [GridMappedElement] {
        var resolvedElements: [GridMappedElement] = []
        var processedElements: Set<String> = []
        
        for collision in collisions {
            let resolution = selectResolutionStrategy(for: collision)
            let resolved = applyResolution(resolution, to: collision)
            
            for element in resolved {
                if !processedElements.contains(element.originalElement.id) {
                    resolvedElements.append(element)
                    processedElements.insert(element.originalElement.id)
                }
            }
        }
        
        return resolvedElements
    }
    
    private func selectResolutionStrategy(for collision: GridCollision) -> ResolutionStrategy {
        switch collision.severity {
        case .critical, .high:
            return .keepHighestImportance
        case .medium:
            return .spatialOffset
        case .low:
            return .mergeSimilar
        }
    }
    
    private func applyResolution(_ strategy: ResolutionStrategy, to collision: GridCollision) -> [GridMappedElement] {
        switch strategy {
        case .keepHighestImportance:
            return [collision.primaryElement]
            
        case .spatialOffset:
            return applySpatialOffset(to: collision)
            
        case .mergeSimilar:
            return mergeSimilarElements(in: collision)
        }
    }
    
    private func applySpatialOffset(to collision: GridCollision) -> [GridMappedElement] {
        var result: [GridMappedElement] = [collision.primaryElement]
        
        let adjacentPositions = getAdjacentPositions(to: collision.gridPosition)
        for (index, element) in collision.secondaryElements.enumerated() {
            if index < adjacentPositions.count {
                let newElement = GridMappedElement(
                    originalElement: element.originalElement,
                    gridPosition: adjacentPositions[index],
                    mappingConfidence: element.mappingConfidence * 0.8,
                    importance: element.importance
                )
                result.append(newElement)
            }
        }
        
        return result
    }
    
    private func mergeSimilarElements(in collision: GridCollision) -> [GridMappedElement] {
        // For now, just keep the primary element
        return [collision.primaryElement]
    }
    
    private func getAdjacentPositions(to position: AdaptiveGridPosition) -> [AdaptiveGridPosition] {
        var adjacent: [AdaptiveGridPosition] = []
        
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        
        for (dCol, dRow) in deltas {
            let newCol = position.columnIndex + dCol
            let newRow = position.rowIndex + dRow
            
            if newCol >= 0 && newCol < UniversalGrid.COLUMNS &&
               newRow >= 0 && newRow < UniversalGrid.ROWS {
                let newPosition = AdaptiveGridPosition(
                    Character(UnicodeScalar(65 + newCol)!),
                    newRow + 1
                )
                adjacent.append(newPosition)
            }
        }
        
        return adjacent
    }
}

extension GridMappedElement {
    init(originalElement: UIElement, gridPosition: AdaptiveGridPosition, mappingConfidence: Double, importance: Int) {
        self.originalElement = originalElement
        self.gridPosition = gridPosition
        self.mappingConfidence = mappingConfidence
        self.importance = importance
    }
}

enum ResolutionStrategy {
    case keepHighestImportance
    case spatialOffset
    case mergeSimilar
}

// MARK: - Grid-Sweep Mapping Engine

class GridSweepMapper {
    let mapper: AdaptiveDensityMapper
    let windowFrame: CGRect
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
        self.mapper = AdaptiveDensityMapper(windowFrame: windowFrame)
    }
    
    func mapAllGridCells(elements: [UIElement]) -> [GridMappedElement] {
        var gridCellMap: [AdaptiveGridPosition: UIElement] = [:]
        
        // Step 1: Sweep through all 780 grid positions (26 columns × 30 rows)
        for columnIndex in 0..<UniversalGrid.COLUMNS {
            for rowIndex in 0..<UniversalGrid.ROWS {
                let column = Character(UnicodeScalar(65 + columnIndex)!)
                let row = rowIndex + 1
                let gridPos = AdaptiveGridPosition(column, row)
                
                // Find the best element for this grid cell
                if let bestElement = findBestElementForCell(gridPos, elements: elements) {
                    gridCellMap[gridPos] = bestElement
                }
            }
        }
        
        // Step 2: Convert to GridMappedElements and deduplicate
        var uniqueElements: [String: GridMappedElement] = [:]
        
        for (gridPos, element) in gridCellMap {
            let gridElement = GridMappedElement(element: element, mapper: mapper)
            
            // Use element ID as key to deduplicate elements that span multiple cells
            if let existing = uniqueElements[element.id] {
                // Keep the element with higher importance or better position
                if gridElement.importance > existing.importance ||
                   (gridElement.importance == existing.importance && 
                    isMoreCentralPosition(gridPos, vs: existing.gridPosition)) {
                    uniqueElements[element.id] = gridElement
                }
            } else {
                uniqueElements[element.id] = gridElement
            }
        }
        
        return Array(uniqueElements.values).sorted { $0.importance > $1.importance }
    }
    
    private func findBestElementForCell(_ gridPos: AdaptiveGridPosition, elements: [UIElement]) -> UIElement? {
        let cellBounds = mapper.cellBounds(for: gridPos)
        let cellCenter = CGPoint(x: cellBounds.midX, y: cellBounds.midY)
        
        var candidates: [(element: UIElement, score: Double)] = []
        
        for element in elements {
            let elementBounds = CGRect(origin: element.position, size: element.size)
            
            // Check if element intersects with this grid cell
            if cellBounds.intersects(elementBounds) {
                let score = calculateCellElementScore(element, cellBounds: cellBounds, cellCenter: cellCenter)
                candidates.append((element, score))
            }
        }
        
        // Return the highest scoring element for this cell
        return candidates.max { $0.score < $1.score }?.element
    }
    
    private func calculateCellElementScore(_ element: UIElement, cellBounds: CGRect, cellCenter: CGPoint) -> Double {
        let elementBounds = CGRect(origin: element.position, size: element.size)
        
        // Base score from element importance
        var score = Double(calculateElementImportance(element))
        
        // Intersection area bonus (how much of the cell does this element cover?)
        let intersection = cellBounds.intersection(elementBounds)
        let intersectionRatio = (intersection.width * intersection.height) / (cellBounds.width * cellBounds.height)
        score += intersectionRatio * 10.0
        
        // Distance penalty (prefer elements closer to cell center)
        let distance = sqrt(pow(element.position.x - cellCenter.x, 2) + pow(element.position.y - cellCenter.y, 2))
        let maxDistance = sqrt(pow(cellBounds.width/2, 2) + pow(cellBounds.height/2, 2))
        let distanceRatio = distance / maxDistance
        score -= distanceRatio * 5.0
        
        // Size appropriateness bonus (elements that fit well in the cell)
        let sizeRatio = min(elementBounds.width / cellBounds.width, elementBounds.height / cellBounds.height)
        if sizeRatio > 0.3 && sizeRatio < 2.0 {
            score += 3.0
        }
        
        return score
    }
    
    private func calculateElementImportance(_ element: UIElement) -> Int {
        var importance = 0
        
        // Role-based scoring
        let role = element.accessibilityData?.role ?? "Unknown"
        switch role {
        case "AXButton": importance += 15
        case "AXMenuItem": importance += 12
        case "AXTextField": importance += 10
        case "AXStaticText": importance += 5
        case "AXImage": importance += 3
        case "AXRow": importance += 2
        case "AXCell": importance += 1
        default: importance += 1
        }
        
        // Interactivity bonus
        if element.isClickable { importance += 10 }
        
        // Size bonus for prominent elements
        let area = element.size.width * element.size.height
        if area > 5000 { importance += 5 }
        else if area > 2000 { importance += 3 }
        
        // Text content bonus
        if let text = element.visualText, !text.isEmpty {
            importance += min(text.count / 10, 5)
        }
        
        return importance
    }
    
    private func isMoreCentralPosition(_ pos1: AdaptiveGridPosition, vs pos2: AdaptiveGridPosition) -> Bool {
        let center = AdaptiveGridPosition("M", 15) // Middle of 26x30 grid
        
        let dist1 = abs(pos1.columnIndex - center.columnIndex) + abs(pos1.rowIndex - center.rowIndex)
        let dist2 = abs(pos2.columnIndex - center.columnIndex) + abs(pos2.rowIndex - center.rowIndex)
        
        return dist1 < dist2
    }
}

// MARK: - Advanced Compression Engine

class AdaptiveGridCompressionEngine {
    let maxTokens: Int
    let densityMetrics: GridDensityMetrics
    
    init(maxTokens: Int = 50, densityMetrics: GridDensityMetrics) {
        self.maxTokens = maxTokens
        self.densityMetrics = densityMetrics
    }
    
    func compress(_ elements: [GridMappedElement], windowContext: WindowContext) -> AdaptiveCompressedUI {
        // Step 1: Keep ALL elements for full window visibility
        let allElements = elements.sorted { $0.importance > $1.importance }
        
        // Step 2: Group by regions
        let regionGroups = groupByRegions(allElements)
        
        // Step 3: Generate compressed representation
        let compressed = generateCompressedRepresentation(regionGroups, context: windowContext)
        
        return compressed
    }
    
    func compressWithGridSweep(_ elements: [UIElement], windowContext: WindowContext) -> AdaptiveCompressedUI {
        let gridSweeper = GridSweepMapper(windowFrame: windowContext.windowFrame)
        let gridMappedElements = gridSweeper.mapAllGridCells(elements: elements)
        
        // Apply additional filtering to remove noise
        let filteredElements = filterNoiseElements(gridMappedElements)
        
        // Group by regions for better organization
        let regionGroups = groupByRegions(filteredElements)
        
        // Generate compressed representation with enhanced content detection
        let compressed = generateEnhancedCompressedRepresentation(regionGroups, context: windowContext)
        
        return compressed
    }
    
    private func filterNoiseElements(_ elements: [GridMappedElement]) -> [GridMappedElement] {
        var filteredElements: [GridMappedElement] = []
        
        for element in elements {
            let originalElement = element.originalElement
            
            // Filter out generic rows/cells without meaningful content
            let role = originalElement.accessibilityData?.role ?? "Unknown"
            if role == "AXRow" || role == "AXCell" {
                // Keep only if it has meaningful text or is in an important region
                if let text = originalElement.visualText, !text.isEmpty, text.count > 2 {
                    filteredElements.append(element)
                    continue
                }
                if let title = originalElement.accessibilityData?.title, !title.isEmpty, title.count > 2 {
                    filteredElements.append(element)
                    continue
                }
                // Keep if in sidebar (likely navigation)
                if GridRegion.sidebar.contains(position: element.gridPosition) {
                    filteredElements.append(element)
                }
                continue
            }
            
            // Filter out elements with very low importance
            if element.importance < 3 {
                continue
            }
            
            // Keep everything else
            filteredElements.append(element)
        }
        
        return filteredElements
    }
    
    private func generateEnhancedCompressedRepresentation(_ regionGroups: [GridRegion: [GridMappedElement]], context: WindowContext) -> AdaptiveCompressedUI {
        var sections: [String] = []
        
        // App context
        let appSection = "F:\(extractLastPathComponent(context.windowTitle))"
        sections.append(appSection)
        
        // Content summary with better main content detection
        let contentSection = generateEnhancedContentSummary(regionGroups)
        sections.append(contentSection)
        
        // Actions with better element detection
        let actionsSection = generateEnhancedActions(regionGroups)
        sections.append(actionsSection)
        
        // State
        let stateSection = generateState(regionGroups)
        sections.append(stateSection)
        
        let format = sections.joined(separator: "|")
        
        return AdaptiveCompressedUI(
            format: format,
            tokenCount: estimateTokenCount(format),
            windowContext: context,
            regionMapping: regionGroups,
            densityMetrics: densityMetrics
        )
    }
    
    private func generateEnhancedContentSummary(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        let allElements = regionGroups.values.flatMap { $0 }
        let totalElements = allElements.count
        
        // Better main content detection
        let mainContentElements = allElements.filter({ element in
            let originalElement = element.originalElement
            
            // Look for file/folder content in main area
            if GridRegion.main.contains(position: element.gridPosition) {
                // Files with extensions
                if let text = originalElement.visualText, text.contains(".") {
                    return true
                }
                // Folders or drives (large clickable elements in main area)
                if originalElement.isClickable && originalElement.size.width > 100 && originalElement.size.height > 20 {
                    return true
                }
            }
            
            return false
        })
        
        return "\(totalElements)e,\(mainContentElements.count)f"
    }
    
    private func generateEnhancedActions(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        let allElements = regionGroups.values.flatMap { $0 }
        
        // Separate navigation elements (highest priority)
        let navElements = allElements.filter({ element in
            let originalElement = element.originalElement
            
            // Sidebar navigation elements
            if GridRegion.sidebar.contains(position: element.gridPosition) && originalElement.isClickable {
                return true
            }
            
            // Toolbar elements
            if GridRegion.toolbar.contains(position: element.gridPosition) && originalElement.isClickable {
                return true
            }
            
            return false
        })
        
        // Main content elements (files, folders, drives)
        let mainElements = allElements.filter({ element in
            let originalElement = element.originalElement
            
            if GridRegion.main.contains(position: element.gridPosition) && originalElement.isClickable {
                // Large elements likely to be main content
                if originalElement.size.width > 100 || originalElement.size.height > 30 {
                    return true
                }
                // Elements with file-like text
                if let text = originalElement.visualText, (text.contains(".") || text.count > 5) {
                    return true
                }
            }
            
            return false
        })
        
        // Combine and prioritize
        let prioritizedElements = (navElements.sorted { $0.importance > $1.importance } + 
                                  mainElements.sorted { $0.importance > $1.importance })
                                  .prefix(maxTokens)
        
        let actions = prioritizedElements.map { $0.compressedRepresentation }
        return actions.joined(separator: ",")
    }
    
    private func groupByRegions(_ elements: [GridMappedElement]) -> [GridRegion: [GridMappedElement]] {
        var regionGroups: [GridRegion: [GridMappedElement]] = [:]
        
        for element in elements {
            let region = GridRegion.allCases.first { region in
                region.contains(position: element.gridPosition)
            } ?? .main
            
            if regionGroups[region] == nil {
                regionGroups[region] = []
            }
            regionGroups[region]!.append(element)
        }
        
        return regionGroups
    }
    
    private func generateCompressedRepresentation(_ regionGroups: [GridRegion: [GridMappedElement]], context: WindowContext) -> AdaptiveCompressedUI {
        var sections: [String] = []
        
        // App context
        let appSection = "F:\(extractLastPathComponent(context.windowTitle))"
        sections.append(appSection)
        
        // Content summary
        let contentSection = generateContentSummary(regionGroups)
        sections.append(contentSection)
        
        // Actions
        let actionsSection = generateActions(regionGroups)
        sections.append(actionsSection)
        
        // State
        let stateSection = generateState(regionGroups)
        sections.append(stateSection)
        
        let format = sections.joined(separator: "|")
        
        return AdaptiveCompressedUI(
            format: format,
            tokenCount: estimateTokenCount(format),
            windowContext: context,
            regionMapping: regionGroups,
            densityMetrics: densityMetrics
        )
    }
    
    private func extractLastPathComponent(_ title: String) -> String {
        let components = title.components(separatedBy: "/")
        return components.last?.prefix(8).description ?? title.prefix(8).description
    }
    
    private func generateContentSummary(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        let totalElements = regionGroups.values.flatMap { $0 }.count
        let fileElements = regionGroups.values.flatMap { $0 }.filter { 
            $0.originalElement.visualText?.contains(".") == true 
        }.count
        
        return "\(totalElements)e,\(fileElements)f"
    }
    
    private func generateActions(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        let allElements = regionGroups.values.flatMap { $0 }
        
        // Separate navigation elements (highest priority)
        let navElements = allElements.filter({ element in
            guard let text = element.originalElement.visualText?.lowercased() else { return false }
            let navWords = ["downloads", "applications", "documents", "desktop", "airdrop", 
                           "recents", "favorites", "network", "macintosh", "icloud", "shared"]
            let isNav = navWords.contains { text.contains($0) }
            // Navigation element found
            return isNav
        })
        
        // Get remaining elements, sorted by importance
        let otherElements = allElements.filter({ element in
            !navElements.contains { $0.originalElement.id == element.originalElement.id }
        }).sorted { $0.importance > $1.importance }
        
        // Combine: navigation first, then other important elements
        let prioritizedElements = navElements.sorted { $0.importance > $1.importance } + 
                                 Array(otherElements.prefix(20)) // Limit others to keep string manageable
        
        let actions = prioritizedElements.map { $0.compressedRepresentation }
        return actions.joined(separator: ",")
    }
    
    private func generateState(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        let selectedElements = regionGroups.values
            .flatMap { $0 }
            .filter({ element in
                element.originalElement.accessibilityData?.selected == true ||
                element.originalElement.accessibilityData?.focused == true
            })
        
        return selectedElements.isEmpty ? "sel:none" : "sel:active"
    }
}

struct AdaptiveCompressedUI {
    let format: String
    let tokenCount: Int
    let windowContext: WindowContext
    let regionMapping: [GridRegion: [GridMappedElement]]
    let densityMetrics: GridDensityMetrics
    
    var compressionRatio: Double {
        let originalSize = regionMapping.values.flatMap { $0 }.count * 150
        return Double(originalSize) / Double(format.count)
    }
    
    var costEstimate: Double {
        return Double(tokenCount) * 0.00001
    }
    
    var qualityScore: Double {
        let avgConfidence = regionMapping.values.flatMap { $0 }
            .map { $0.mappingConfidence }
            .reduce(0, +) / Double(max(1, regionMapping.values.flatMap { $0 }.count))
        
        let precisionValue = densityMetrics.precision == .high ? 1 : 
                            densityMetrics.precision == .medium ? 2 :
                            densityMetrics.precision == .low ? 3 : 4
        let densityScore = min(1.0, 1.0 / Double(precisionValue))
        
        return (avgConfidence + densityScore) / 2.0
    }
}

struct WindowContext {
    let appName: String
    let windowTitle: String
    let windowFrame: CGRect
}

func estimateTokenCount(_ text: String) -> Int {
    return max(1, text.count / 4)
}

// MARK: - Ultra-Compressed UI System

struct GridPosition {
    let column: Character  // A-L
    let row: Int          // 1-8
    
    init(_ column: Character, _ row: Int) {
        self.column = column
        self.row = row
    }
    
    var gridString: String {
        return "\(column)\(row)"
    }
    
    func toPixel(screenWidth: CGFloat = 1000, screenHeight: CGFloat = 720) -> CGPoint {
        let col = Int(column.asciiValue! - 65)  // A=0, B=1, etc.
        let x = CGFloat(col) * (screenWidth / 12) + (screenWidth / 24)
        let y = CGFloat(row - 1) * (screenHeight / 8) + (screenHeight / 16)
        return CGPoint(x: x, y: y)
    }
    
    static func fromPixel(_ point: CGPoint, screenWidth: CGFloat = 1000, screenHeight: CGFloat = 720) -> GridPosition {
        let col = Int(point.x / (screenWidth / 12))
        let row = Int(point.y / (screenHeight / 8)) + 1
        let colChar = Character(UnicodeScalar(65 + min(max(col, 0), 11))!)
        return GridPosition(colChar, min(max(row, 1), 8))
    }
}

struct CompressedElement {
    let symbol: String
    let grid: GridPosition
    let action: String
    let importance: Int
    
    var compressed: String {
        return "\(symbol)@\(grid.gridString)"
    }
}

struct CompressedUI {
    let app: String
    let context: String
    let content: String
    let actions: [CompressedElement]
    let state: String
    
    var format: String {
        let actionString = actions.map { $0.compressed }.joined(separator: ",")
        return "\(app):\(context)|\(content)|\(actionString)|\(state)"
    }
    
    var tokenCount: Int {
        return format.count / 4  // Rough token estimate
    }
}

class UICompressor {
    
    private let symbolMap: [String: String] = [
        "back": "<",
        "forward": ">",
        "search": "🔍",
        "add": "+",
        "delete": "×",
        "close": "✕",
        "folder": "📁",
        "file": "📄",
        "image": "🖼️",
        "menu": "☰",
        "save": "💾",
        "share": "📤",
        "edit": "✏️",
        "view": "👁️",
        "refresh": "🔄"
    ]
    
    func compress(_ uiMap: CompleteUIMap) -> AdaptiveCompressedUI {
        // NEW: Use grid-sweep approach instead of filtering
        let gridSweeper = GridSweepMapper(windowFrame: uiMap.windowFrame)
        
        // Apply compression with grid-sweep results
        let compressionEngine = AdaptiveGridCompressionEngine(
            maxTokens: 50, // Reduce to focus on most important elements
            densityMetrics: gridSweeper.mapper.gridDensity
        )
        
        let windowContext = WindowContext(
            appName: "Finder",
            windowTitle: uiMap.windowTitle,
            windowFrame: uiMap.windowFrame
        )
        
        let compressed = compressionEngine.compressWithGridSweep(uiMap.elements, windowContext: windowContext)
        
        return compressed
    }
    
    private func filterCriticalElements(_ elements: [UIElement]) -> [UIElement] {
        let filtered = elements.filter({ element in
            // Priority 1: Always keep navigation elements
            if isNavigationElement(element) {
                return true
            }
            
            // Priority 1: Always keep window controls
            if isWindowControl(element) { return true }
            
            // Priority 1: Always keep toolbar elements
            if isToolbarElement(element) { return true }
            
            // Priority 1: Always keep file/folder content
            if isFileOrFolderContent(element) { return true }
            
            // Priority 1: Always keep interactive buttons
            if element.isClickable && hasMeaningfulContent(element) { return true }
            
            // Filter out noise: generic roles, numbers, empty elements
            if isNoiseElement(element) { return false }
            
            // Keep meaningful text content
            if hasReadableText(element) { return true }
            
            // Keep sidebar accessibility elements (likely navigation)
            if element.position.x < 200 && element.isClickable {
                return true
            }
            
            // Keep main content area clickable elements
            if element.position.x > 200 && element.isClickable && hasMeaningfulContent(element) {
                return true
            }
            
            return false
        })
        
        return filtered
    }
    
    private func isNavigationElement(_ element: UIElement) -> Bool {
        // Universal position-based navigation detection
        let windowWidth: CGFloat = 920.0  // Could get from window bounds
        let windowHeight: CGFloat = 436.0
        
        // Sidebar navigation (left 25% of window)
        if element.position.x < windowWidth * 0.25 && element.isClickable {
            return true
        }
        
        // Top toolbar area (top 15% of window)
        if element.position.y < windowHeight * 0.15 && element.isClickable {
            return true
        }
        
        // Right toolbar area (right 15% of window) - search, controls
        if element.position.x > windowWidth * 0.85 && element.isClickable {
            return true
        }
        
        // Navigation-like accessibility roles in key areas
        if let accData = element.accessibilityData {
            let navRoles = ["AXRow", "AXCell", "AXButton", "AXPopUpButton"]
            if navRoles.contains(accData.role) {
                // In sidebar or toolbar areas
                if element.position.x < windowWidth * 0.25 || element.position.y < windowHeight * 0.15 {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isWindowControl(_ element: UIElement) -> Bool {
        if let accData = element.accessibilityData {
            let role = accData.role
            let desc = accData.description?.lowercased() ?? ""
            return role == "AXButton" && (desc.contains("close") || desc.contains("minimize") || desc.contains("zoom"))
        }
        return false
    }
    
    private func isToolbarElement(_ element: UIElement) -> Bool {
        if let accData = element.accessibilityData {
            let desc = accData.description?.lowercased() ?? ""
            return desc.contains("back") || desc.contains("forward") || desc.contains("search") || 
                   desc.contains("share") || desc.contains("view") || desc.contains("edit tags")
        }
        return false
    }
    
    private func isFileOrFolderContent(_ element: UIElement) -> Bool {
        guard let text = element.visualText else { return false }
        // Files have extensions, folders are single words
        return text.contains(".") || (text.count > 2 && text.count < 30 && !text.contains(" "))
    }
    
    private func hasMeaningfulContent(_ element: UIElement) -> Bool {
        if let text = element.visualText, !text.isEmpty {
            // Not just numbers or single characters
            return text.count > 1 && !text.allSatisfy { $0.isNumber }
        }
        if let accData = element.accessibilityData {
            return accData.description != nil || accData.title != nil
        }
        return false
    }
    
    private func isNoiseElement(_ element: UIElement) -> Bool {
        // Filter out pure numbers, empty elements, generic roles
        if let text = element.visualText {
            if text.allSatisfy({ $0.isNumber }) { return true }  // Pure numbers like "1398"
            if text.isEmpty { return true }                       // Empty text
            if text.count <= 1 { return true }                   // Single characters
        }
        
        // ENHANCED: Filter out generic accessibility roles without meaningful content
        if let accData = element.accessibilityData {
            let genericRoles = ["AXGroup", "AXRow", "AXCell", "AXColumn"]
            if genericRoles.contains(accData.role) {
                // Always filter if completely empty
                if accData.description == nil && 
                   accData.title == nil && 
                   element.visualText == nil {
                    return true
                }
                
                // Filter generic rows/cells unless they're in important areas with content
                if accData.role == "AXRow" || accData.role == "AXCell" {
                    let hasUsefulText = hasInterestingText(element)
                    let isInKeyArea = element.position.x < 230 || // Sidebar
                                     element.position.y < 100    // Toolbar
                    
                    // Filter if no useful text AND not in key interactive areas
                    if !hasUsefulText && (!isInKeyArea || !element.isClickable) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func hasReadableText(_ element: UIElement) -> Bool {
        guard let text = element.visualText, text.count > 2 else { return false }
        // Must contain letters and be readable
        return text.contains(where: { $0.isLetter }) && text.count < 50
    }
    
    private func calculateVisualImportance(_ element: UIElement) -> Int {
        var score = 0
        let windowWidth: CGFloat = 920.0
        let windowHeight: CGFloat = 436.0
        
        // Size importance - larger elements are more prominent
        let area = element.size.width * element.size.height
        if area > 4000 { 
            score += 15      // Very large elements
        } else if area > 2000 { 
            score += 10      // Large elements
        } else if area > 800 { 
            score += 5       // Medium elements
        } else if area > 200 {
            score += 2       // Small but visible elements
        }
        
        // Position prominence scoring
        if element.position.x < windowWidth * 0.25 { 
            score += 8   // Sidebar - high prominence
        }
        if element.position.y < windowHeight * 0.15 { 
            score += 6   // Top toolbar - high prominence  
        }
        if element.position.x > windowWidth * 0.85 { 
            score += 5   // Right side controls - medium prominence
        }
        
        // Center area gets moderate boost (main content)
        if element.position.x > windowWidth * 0.25 && element.position.x < windowWidth * 0.85 {
            score += 3
        }
        
        // Interaction affordance boost
        if element.isClickable { 
            score += 12  // Interactive elements are prominent
        }
        
        return score
    }
    
    private func hasInterestingText(_ element: UIElement) -> Bool {
        guard let text = element.visualText?.trimmingCharacters(in: .whitespacesAndNewlines) else { 
            return false 
        }
        
        // Filter out noise text
        if text.isEmpty || text.count <= 1 { return false }
        if text.allSatisfy({ $0.isNumber }) { return false }  // Pure numbers
        if text.contains("//") || text.contains("->") { return false }  // Code fragments
        
        // Short, meaningful text is good for UI elements
        if text.count >= 2 && text.count <= 25 && text.contains(where: { $0.isLetter }) {
            return true
        }
        
        return false
    }
    
    private func deduplicateElements(_ elements: [UIElement]) -> [UIElement] {
        var seen: Set<String> = []
        var deduplicated: [UIElement] = []
        
        for element in elements {
            let key = generateDeduplicationKey(element)
            if !seen.contains(key) {
                seen.insert(key)
                deduplicated.append(element)
            }
        }
        
        // NO LIMITS - Return ALL deduplicated elements for complete window visibility
        let final = deduplicated.sorted { getImportanceScore($0) > getImportanceScore($1) }
        return final
    }
    
    private func generateDeduplicationKey(_ element: UIElement) -> String {
        var key = ""
        
        if let accData = element.accessibilityData {
            key += accData.role
            if let desc = accData.description { key += desc }
        }
        
        if let ocrData = element.ocrData {
            key += ocrData.text
        }
        
        // Add rough position to avoid merging elements that are far apart
        let roughX = Int(element.position.x / 100) * 100
        let roughY = Int(element.position.y / 100) * 100
        key += "\(roughX),\(roughY)"
        
        return key
    }
    
    private func getImportanceScore(_ element: UIElement) -> Int {
        var score = 0
        let windowWidth: CGFloat = 920.0  // Declare at top for reuse
        
        // Boost interactive elements
        if element.isClickable { score += 10 }
        
        // Boost elements with clear actions
        if let hint = element.actionHint {
            if hint.contains("save") || hint.contains("close") || hint.contains("search") {
                score += 5
            }
        }
        
        // Smart accessibility role pattern scoring
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton": 
                score += 15  // Always important - primary interactions
            case "AXPopUpButton": 
                score += 12  // View controls, dropdowns
            case "AXTextField": 
                score += 10  // Input fields
            case "AXRow", "AXCell":
                // Context-dependent scoring
                if element.position.x < 230 {  // Sidebar area
                    score += 12  // Navigation rows/cells
                } else {
                    score += 3   // Content area rows/cells
                }
            case "AXStaticText":
                if hasInterestingText(element) {
                    score += 6   // Meaningful labels
                } else {
                    score += 1   // Generic text
                }
            case "AXImage":
                if element.isClickable {
                    score += 8   // Clickable icons
                } else {
                    score += 2   // Decorative images
                }
            default: 
                score += 1       // Unknown roles get minimal score
            }
        }
        
        // Visual importance scoring (size + prominence)
        let visualScore = calculateVisualImportance(element)
        score += visualScore
        
        // Boost elements with meaningful text
        if let text = element.visualText, !text.isEmpty {
            if text.count > 2 && text.count < 20 { score += 3 }
        }
        
        // UNIVERSAL: Boost large, prominent main content elements
        if element.position.x > windowWidth * 0.25 && element.position.x < windowWidth * 0.85 {
            let area = element.size.width * element.size.height
            if area > 3000 && element.isClickable { 
                score += 18  // Large clickable main content (likely important destinations)
            }
        }
        
        // UNIVERSAL: Boost elements that have both visual text AND accessibility info
        if element.visualText != nil && 
           element.accessibilityData?.description != nil && 
           element.isClickable {
            score += 12  // Rich, interactive elements are usually important
        }
        
        // Universal sidebar element boost (no hardcoded words)
        if element.position.x < windowWidth * 0.25 { // Left sidebar area (dynamic)
            if hasInterestingText(element) {
                score += 20 // High priority for meaningful sidebar content
            } else if element.isClickable {
                score += 15 // Clickable sidebar elements (even without text)
            }
        }
        
        // Penalize noise elements heavily
        if let text = element.visualText {
            if text.allSatisfy({ $0.isNumber }) || // Pure numbers like "1539"
               text.contains("//") ||               // Code comments
               text.count <= 2 ||                   // Very short text
               text == "elem" {                     // Generic placeholders
                score -= 10
            }
        }
        
        return score
    }
    
    private func mapToGrid(_ elements: [UIElement], windowFrame: CGRect) -> [UIElement] {
        // Use actual window dimensions for accurate grid mapping
        return elements
    }
    
    private func applySymbolicEncoding(_ elements: [UIElement]) -> [CompressedElement] {
        return elements.map { element in
            let symbol = findSymbol(for: element)
            let grid = GridPosition.fromPixel(element.position)
            let action = inferAction(for: element)
            let importance = getImportanceScore(element)
            
            return CompressedElement(
                symbol: symbol,
                grid: grid,
                action: action,
                importance: importance
            )
        }
    }
    
    private func findSymbol(for element: UIElement) -> String {
        // Check for specific button types
        if let accData = element.accessibilityData {
            if let desc = accData.description {
                for (key, symbol) in self.symbolMap {
                    if desc.lowercased().contains(key) {
                        return symbol
                    }
                }
            }
        }
        
        // Check OCR text
        if let ocrData = element.ocrData {
            let text = ocrData.text.lowercased()
            for (key, symbol) in self.symbolMap {
                if text.contains(key) {
                    return symbol
                }
            }
            
            // Return abbreviated text for unrecognized content
            if text.count <= 5 {
                return text
            } else {
                return String(text.prefix(3))
            }
        }
        
        // Default based on role
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton": return "🔘"
            case "AXTextField": return "📝"
            case "AXImage": return "🖼️"
            default: return String(accData.role.prefix(3))
            }
        }
        
        // Fallback - always return something valid
        return "elem"
    }
    
    private func inferAction(for element: UIElement) -> String {
        if let hint = element.actionHint {
            if hint.contains("close") { return "close" }
            if hint.contains("save") { return "save" }
            if hint.contains("search") { return "search" }
        }
        
        if element.isClickable {
            return "click"
        }
        
        return "view"
    }
    
    private func generateAppContext(_ uiMap: CompleteUIMap) -> (app: String, context: String, content: String, state: String) {
        let app = "F"  // Finder
        
        // Extract context from window title
        let context = extractPath(from: uiMap.windowTitle)
        
        // Count file types
        let content = generateContentSummary(uiMap.elements)
        
        // Generate state info
        let state = generateState(uiMap.elements)
        
        return (app, context, content, state)
    }
    
    private func extractPath(from title: String) -> String {
        // Simplify path - just get the last component
        let components = title.components(separatedBy: "/")
        return components.last ?? title
    }
    
    private func generateContentSummary(_ elements: [UIElement]) -> String {
        var fileCount = 0
        var folderCount = 0
        
        for element in elements {
            if let text = element.visualText {
                if text.contains(".") && text.count < 30 {
                    fileCount += 1
                } else if element.type.contains("folder") {
                    folderCount += 1
                }
            }
        }
        
        if fileCount > 0 || folderCount > 0 {
            return "\(fileCount)f,\(folderCount)d"
        }
        
        return "mixed"
    }
    
    private func generateState(_ elements: [UIElement]) -> String {
        // Check for focused/selected elements
        let hasSelection = elements.contains { element in
            element.accessibilityData?.selected == true ||
            element.accessibilityData?.focused == true
        }
        
        return hasSelection ? "sel:active" : "sel:none"
    }
}

// MARK: - Enhanced OCR Processing

extension VisionOCRHandler {
    
    func performEnhancedOCR(on image: NSImage, completion: @escaping ([OCRData]) -> Void) {
        let startTime = Date()
        
        // Perform multiple OCR passes with different settings
        let group = DispatchGroup()
        var allResults: [[OCRData]] = []
        
        // Standard OCR
        group.enter()
        extractTextFromImage(image) { results in
            allResults.append(results)
            group.leave()
        }
        
        // Enhanced OCR with accurate recognition
        group.enter()
        extractTextWithAccurateRecognition(image) { results in
            allResults.append(results)
            group.leave()
        }
        
        group.notify(queue: .main) {
            let mergedResults = self.mergeOCRResults(allResults)
            let processingTime = Date().timeIntervalSince(startTime)
            print("🔍 Enhanced OCR completed in \(String(format: "%.2f", processingTime))s")
            completion(mergedResults)
        }
    }
    
    private func extractTextWithAccurateRecognition(_ image: NSImage, completion: @escaping ([OCRData]) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("❌ Enhanced OCR failed: \(error)")
                completion([])
                return
            }
            
            let ocrData = request.results?.compactMap { observation -> OCRData? in
                guard let observation = observation as? VNRecognizedTextObservation,
                      let topCandidate = observation.topCandidates(1).first else { return nil }
                
                return OCRData(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: observation.boundingBox
                )
            } ?? []
            
            completion(ocrData)
        }
        
        // Enhanced settings
        request.recognitionLevel = .accurate
        request.minimumTextHeight = 0.008 // Smaller text
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ Enhanced OCR request failed: \(error)")
                completion([])
            }
        }
    }
    
    private func mergeOCRResults(_ resultSets: [[OCRData]]) -> [OCRData] {
        var mergedResults: [OCRData] = []
        var processedTexts: Set<String> = []
        
        // Prioritize high-confidence results
        for resultSet in resultSets {
            for result in resultSet where result.confidence > 0.8 {
                let normalizedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                // Avoid duplicates based on text and position
                let isDuplicate = mergedResults.contains { existing in
                    let existingNormalized = existing.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let distance = distanceBetweenCenters(existing.boundingBox, result.boundingBox)
                    return existingNormalized == normalizedText && distance < 0.05
                }
                
                if !isDuplicate && !processedTexts.contains(normalizedText) {
                    mergedResults.append(result)
                    processedTexts.insert(normalizedText)
                }
            }
        }
        
        // Add medium-confidence results that don't conflict
        for resultSet in resultSets {
            for result in resultSet where result.confidence > 0.5 && result.confidence <= 0.8 {
                let normalizedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                let isDuplicate = mergedResults.contains { existing in
                    let existingNormalized = existing.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let distance = distanceBetweenCenters(existing.boundingBox, result.boundingBox)
                    return existingNormalized == normalizedText && distance < 0.1
                }
                
                if !isDuplicate && !processedTexts.contains(normalizedText) {
                    mergedResults.append(result)
                    processedTexts.insert(normalizedText)
                }
            }
        }
        
        return mergedResults.sorted { $0.confidence > $1.confidence }
    }
    
    private func distanceBetweenCenters(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let center1 = CGPoint(x: rect1.midX, y: rect1.midY)
        let center2 = CGPoint(x: rect2.midX, y: rect2.midY)
        return sqrt(pow(center1.x - center2.x, 2) + pow(center1.y - center2.y, 2))
    }
}

// MARK: - Performance Monitor

class PerformanceMonitor {
    static func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try operation()
        let endTime = Date()
        return (result, endTime.timeIntervalSince(startTime))
    }
    
    static func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Main Application

class UIInspectorApp {
    
    private let accessibilityInspector = AccessibilityInspector()
    private let visionOCRHandler = VisionOCRHandler()
    private let fusionEngine = UIFusionEngine()
    private let screenshotCapture = ScreenshotCapture()
    
    func run() {
        // Print compilation completion timestamp  
        print("SWIFT_COMPILATION_FINISHED")
        
        print("🔍 Starting ULTRA-FAST UI Inspector")
        print(String(repeating: "=", count: 60))
        
        let overallStartTime = Date()
        var stepTimes: [(String, TimeInterval)] = []
        
        // Step 1: Ensure Finder is active and has a window
        let finderSetupStart = Date()
        ensureFinderWindow()
        let finderSetupTime = Date().timeIntervalSince(finderSetupStart)
        stepTimes.append(("Finder window setup", finderSetupTime))
        
        // PERFORMANCE: Parallel execution of expensive operations
        print("⚡ Running parallel capture and analysis...")
        
        var windowData: [String: Any] = [:]
        var accessibilityElements: [AccessibilityData] = []
        var screenshot: NSImage?
        var ocrElements: [OCRData] = []
        
        let group = DispatchGroup()
        var accessibilityTime: TimeInterval = 0
        var screenshotTime: TimeInterval = 0
        
        // Parallel Task 1: Accessibility data
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let accessibilityStart = Date()
            let (data, elements) = self.accessibilityInspector.inspectFinderWindow()
            accessibilityTime = Date().timeIntervalSince(accessibilityStart)
            windowData = data
            accessibilityElements = elements
            group.leave()
        }
        
        // Parallel Task 2: Screenshot capture
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let screenshotStart = Date()
            screenshot = self.screenshotCapture.captureFinderWindow()
            screenshotTime = Date().timeIntervalSince(screenshotStart)
            group.leave()
        }
        
        // Wait for both to complete
        group.wait()
        stepTimes.append(("Accessibility tree traversal", accessibilityTime))
        stepTimes.append(("Screen capture", screenshotTime))
        
        // Step 3: OCR processing (depends on screenshot)
        guard let capturedScreenshot = screenshot else {
            print("❌ Failed to capture screenshot")
            return
        }
        
        let ocrStart = Date()
        let semaphore = DispatchSemaphore(value: 0)
        visionOCRHandler.extractTextFromImage(capturedScreenshot) { results in
            ocrElements = results
            semaphore.signal()
        }
        
        semaphore.wait()
        let ocrTime = Date().timeIntervalSince(ocrStart)
        stepTimes.append(("OCR text extraction", ocrTime))
        
        // Step 4: Fuse the data
        print("🔗 Fusing accessibility and OCR data...")
        let fusionStart = Date()
        let windowFrame = CGRect(
            x: (windowData["position"] as? [String: Double])?["x"] ?? 0,
            y: (windowData["position"] as? [String: Double])?["y"] ?? 0,
            width: (windowData["size"] as? [String: Double])?["width"] ?? 800,
            height: (windowData["size"] as? [String: Double])?["height"] ?? 600
        )
        
        let fusedElements = fusionEngine.fuseAccessibilityWithOCR(
            accessibilityElements: accessibilityElements,
            ocrElements: ocrElements,
            windowFrame: windowFrame
        )
        let fusionTime = Date().timeIntervalSince(fusionStart)
        stepTimes.append(("Element fusion", fusionTime))
        
        // Step 5: Create complete UI map
        let mapCreationStart = Date()
        let performanceMetrics = CompleteUIMap.PerformanceMetrics(
            accessibilityTime: accessibilityTime,
            screenshotTime: screenshotTime,
            ocrTime: ocrTime,
            fusionTime: fusionTime,
            totalElements: accessibilityElements.count + ocrElements.count,
            fusedElements: fusedElements.count,
            memoryUsage: PerformanceMonitor.getMemoryUsage()
        )
        
        let completeMap = CompleteUIMap(
            windowTitle: windowData["title"] as? String ?? "Unknown",
            windowFrame: windowFrame,
            elements: fusedElements,
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(overallStartTime),
            performance: performanceMetrics,
            summary: CompleteUIMap.UIMapSummary(from: fusedElements)
        )
        let mapCreationTime = Date().timeIntervalSince(mapCreationStart)
        stepTimes.append(("UI map creation", mapCreationTime))
        
        // Step 6: Compression
        let compressionStart = Date()
        let compressor = UICompressor()
        let compressed = compressor.compress(completeMap)
        let compressionTime = Date().timeIntervalSince(compressionStart)
        stepTimes.append(("UI compression", compressionTime))
        
        // Step 7: JSON serialization
        let jsonStart = Date()
        let jsonData = createJSONRepresentation(completeMap)
        let jsonTime = Date().timeIntervalSince(jsonStart)
        stepTimes.append(("JSON serialization", jsonTime))
        
        // Step 8: File I/O
        let fileIOStart = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let compressedFilename = "ui_compressed_\(dateFormatter.string(from: completeMap.timestamp)).txt"
        let compressedPath = "./\(compressedFilename)"
        let jsonFilename = "ui_map_\(dateFormatter.string(from: completeMap.timestamp)).json"
        let jsonPath = "./\(jsonFilename)"
        
        do {
            try compressed.format.write(to: URL(fileURLWithPath: compressedPath), atomically: false, encoding: .utf8)
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))
        } catch {
            print("❌ Failed to save files: \(error)")
        }
        let fileIOTime = Date().timeIntervalSince(fileIOStart)
        stepTimes.append(("File I/O (save)", fileIOTime))
        
        let totalTime = Date().timeIntervalSince(overallStartTime)
        
        // Print detailed timing results FIRST
        print("\n⏱️  PERFORMANCE BREAKDOWN:")
        print(String(repeating: "=", count: 50))
        for (step, time) in stepTimes {
            let percentage = (time / totalTime) * 100
            print("  • \(step): \(String(format: "%.3f", time))s (\(String(format: "%.1f", percentage))%)")
        }
        print(String(repeating: "-", count: 50))
        print("  🏁 TOTAL TIME: \(String(format: "%.3f", totalTime))s")
        print("")
        
        // Step 9: Print results (detailed UI analysis)
        printResults(completeMap, accessibilityElements, ocrElements)
        
        // Print compression stats
        let originalSize = jsonData.count
        let compressedSize = compressed.format.count
        let ratio = Double(originalSize) / Double(compressedSize)
        
        print("\n🚀 ULTRA-COMPRESSED UI FORMAT:")
        print("Format: \(compressed.format)")
        print("Length: \(compressed.format.count) characters")
        print("Tokens: ~\(compressed.tokenCount)")
        print("Cost reduction: ~100x cheaper than image")
        
        print("\n📊 COMPRESSION STATS:")
        print("Original JSON: \(originalSize) bytes")
        print("Compressed: \(compressedSize) bytes")
        print("Compression ratio: \(String(format: "%.0f", ratio))x smaller")
        
        // Print file save confirmation
        print("💾 Compressed UI saved to: \(compressedPath)")
        print("📄 Full JSON saved to: \(jsonPath)")
    }
    
    private func ensureFinderWindow() {
        // OPTIMIZATION: Universal app activation using NSWorkspace (much faster than AppleScript)
        let bundleID = "com.apple.finder"
        let appName = "Finder"
        
        // Quick check if already active and has windows
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID && hasAppWindows(bundleIdentifier: bundleID) {
            print("⚡ Finder already active with windows, skipping setup")
            return
        }
        
        print("🔄 Activating Finder using NSWorkspace...")
        
        // Use fast NSWorkspace APIs instead of slow AppleScript
        let workspace = NSWorkspace.shared
        
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            // App is running - just activate it
            app.activate(options: .activateIgnoringOtherApps)
            print("⚡ Activated existing Finder process")
        } else {
            // App not running - launch it
            let success = workspace.launchApplication(appName)
            if success {
                print("🚀 Launched Finder application")
            } else {
                print("❌ Failed to launch Finder")
                return
            }
        }
        
        // OPTIMIZATION: Smart polling for any app windows
        waitForAppWindow(bundleIdentifier: bundleID, appName: appName, maxWait: 2.0)
    }
    
    private func waitForAppWindow(bundleIdentifier: String, appName: String, maxWait: TimeInterval = 2.0) {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWait {
            if hasAppWindows(bundleIdentifier: bundleIdentifier) {
                let actualWait = Date().timeIntervalSince(startTime)
                print("⚡ \(appName) window ready in \(String(format: "%.3f", actualWait))s")
                return
            }
            Thread.sleep(forTimeInterval: 0.05) // Poll every 50ms
        }
        
        let actualWait = Date().timeIntervalSince(startTime)
        print("⚠️  \(appName) window not ready after \(String(format: "%.3f", actualWait))s (timeout)")
    }
    
    private func hasAppWindows(bundleIdentifier: String) -> Bool {
        // Universal window detection using fast CGWindowList API
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Get the app name from bundle identifier
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              let appName = app.localizedName else {
            return false
        }
        
        // Look for windows from this specific app that are actually visible
        let appWindows = windowList.filter({ window in
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  ownerName == appName,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  windowLayer == 0, // Normal window layer (not background/overlay)
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                return false
            }
            
            // Window must have reasonable size (not just tiny UI elements)
            return width > 200 && height > 150
        })
        
        return !appWindows.isEmpty
    }

    
    private func printResults(_ completeMap: CompleteUIMap, _ accessibilityElements: [AccessibilityData], _ ocrElements: [OCRData]) {
        print("\n🎯 COMPLETE UI ANALYSIS RESULTS")
        print(String(repeating: "=", count: 60))
        
        // Window info
        print("📱 WINDOW INFORMATION:")
        print("  Title: \(completeMap.windowTitle)")
        print("  Frame: \(completeMap.windowFrame)")
        print("  Processing Time: \(String(format: "%.3f", completeMap.processingTime))s")
        
        // Accessibility summary
        print("\n🔧 ACCESSIBILITY DATA:")
        print("  Elements found: \(accessibilityElements.count)")
        for (index, element) in accessibilityElements.enumerated() {
            print("  [\(index + 1)] \(element.role)")
            if let title = element.title { print("      Title: '\(title)'") }
            if let description = element.description { print("      Description: '\(description)'") }
            if let help = element.help { print("      Help: '\(help)'") }
            print("      Enabled: \(element.enabled), Focused: \(element.focused)")
        }
        
        // OCR summary
        print("\n🔤 VISION OCR DATA:")
        print("  Text elements found: \(ocrElements.count)")
        for (index, element) in ocrElements.enumerated() {
            print("  [\(index + 1)] '\(element.text)' (confidence: \(String(format: "%.2f", element.confidence)))")
            print("      Bounding box: \(element.boundingBox)")
        }
        
        // Fused results
        print("\n🔗 FUSED UI ELEMENTS:")
        print("  Combined elements: \(completeMap.elements.count)")
        for (index, element) in completeMap.elements.enumerated() {
            print("  [\(index + 1)] \(element.type) at \(element.position)")
            print("      Clickable: \(element.isClickable), Confidence: \(String(format: "%.2f", element.confidence))")
            
            if let accData = element.accessibilityData {
                print("      Accessibility: \(accData.role) - '\(accData.description ?? "nil")'")
            }
            
            if let ocrData = element.ocrData {
                print("      OCR Text: '\(ocrData.text)' (\(String(format: "%.2f", ocrData.confidence)))")
            }
        }
        
        // Analysis summary
        print("\n📊 ANALYSIS SUMMARY:")
        let accessibilityOnly = completeMap.elements.filter { $0.accessibilityData != nil && $0.ocrData == nil }.count
        let ocrOnly = completeMap.elements.filter { $0.accessibilityData == nil && $0.ocrData != nil }.count
        let fused = completeMap.elements.filter { $0.accessibilityData != nil && $0.ocrData != nil }.count
        
        print("  Accessibility-only elements: \(accessibilityOnly)")
        print("  OCR-only elements: \(ocrOnly)")
        print("  Successfully fused elements: \(fused)")
        print("  Gap-filling effectiveness: \(String(format: "%.1f", Double(fused + ocrOnly) / Double(completeMap.elements.count) * 100))%")
        
        print("\n✅ UI Inspection Complete!")
    }
    

    
    private func createJSONRepresentation(_ completeMap: CompleteUIMap) -> Data {
        var jsonDict: [String: Any] = [:]
        
        // Window information
        jsonDict["window"] = [
            "title": completeMap.windowTitle,
            "frame": [
                "x": completeMap.windowFrame.origin.x,
                "y": completeMap.windowFrame.origin.y,
                "width": completeMap.windowFrame.size.width,
                "height": completeMap.windowFrame.size.height
            ],
            "timestamp": ISO8601DateFormatter().string(from: completeMap.timestamp)
        ]
        
        // Performance metrics
        jsonDict["performance"] = [
            "processingTime": completeMap.processingTime,
            "accessibilityTime": completeMap.performance.accessibilityTime,
            "screenshotTime": completeMap.performance.screenshotTime,
            "ocrTime": completeMap.performance.ocrTime,
            "fusionTime": completeMap.performance.fusionTime,
            "totalElements": completeMap.performance.totalElements,
            "fusedElements": completeMap.performance.fusedElements,
            "memoryUsage": completeMap.performance.memoryUsage
        ]
        
        // Summary
        jsonDict["summary"] = [
            "totalElements": completeMap.elements.count,
            "clickableElements": completeMap.summary.clickableElements.count,
            "averageConfidence": completeMap.summary.confidence,
            "textContent": completeMap.summary.textContent,
            "suggestedActions": completeMap.summary.suggestedActions
        ]
        
        // Detailed elements
        jsonDict["elements"] = completeMap.elements.map { element in
            var elementDict: [String: Any] = [
                "id": element.id,
                "type": element.type,
                "position": ["x": element.position.x, "y": element.position.y],
                "size": ["width": element.size.width, "height": element.size.height],
                "isClickable": element.isClickable,
                "confidence": element.confidence,
                "semanticMeaning": element.semanticMeaning,
                "interactions": element.interactions
            ]
            
            if let actionHint = element.actionHint {
                elementDict["actionHint"] = actionHint
            }
            
            if let visualText = element.visualText {
                elementDict["visualText"] = visualText
            }
            
            if let accData = element.accessibilityData {
                var accessibilityDict: [String: Any] = [
                    "role": accData.role,
                    "description": accData.description ?? NSNull(),
                    "title": accData.title ?? NSNull(),
                    "help": accData.help ?? NSNull(),
                    "enabled": accData.enabled,
                    "focused": accData.focused,
                    "selected": accData.selected
                ]
                
                if let subrole = accData.subrole {
                    accessibilityDict["subrole"] = subrole
                }
                
                if let value = accData.value {
                    accessibilityDict["value"] = value
                }
                
                if let parent = accData.parent {
                    accessibilityDict["parent"] = parent
                }
                
                if !accData.children.isEmpty {
                    accessibilityDict["children"] = accData.children
                }
                
                elementDict["accessibility"] = accessibilityDict
            }
            
            if let context = element.context {
                elementDict["context"] = [
                    "purpose": context.purpose,
                    "region": context.region,
                    "navigationPath": context.navigationPath,
                    "availableActions": context.availableActions
                ]
            }
            
            if let ocrData = element.ocrData {
                elementDict["ocr"] = [
                    "text": ocrData.text,
                    "confidence": ocrData.confidence,
                    "boundingBox": [
                        "x": ocrData.boundingBox.origin.x,
                        "y": ocrData.boundingBox.origin.y,
                        "width": ocrData.boundingBox.size.width,
                        "height": ocrData.boundingBox.size.height
                    ]
                ]
            }
            
            return elementDict
        }
        
        // Analysis insights
        jsonDict["insights"] = generateInsights(completeMap)
        
        do {
            return try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted])
        } catch {
            print("❌ JSON serialization failed: \(error)")
            return Data()
        }
    }
    
    private func generateInsights(_ completeMap: CompleteUIMap) -> [String: Any] {
        let elements = completeMap.elements
        
        // Categorize elements
        let buttons = elements.filter { $0.type.contains("Button") || $0.accessibilityData?.role == "AXButton" }
        let textFields = elements.filter { $0.accessibilityData?.role == "AXTextField" }
        let images = elements.filter { $0.accessibilityData?.role == "AXImage" }
        let staticTexts = elements.filter { $0.accessibilityData?.role == "AXStaticText" }
        
        // Analyze spatial distribution
        let topHalf = elements.filter { $0.position.y < completeMap.windowFrame.height / 2 }
        let bottomHalf = elements.filter { $0.position.y >= completeMap.windowFrame.height / 2 }
        
        // Confidence analysis
        let highConfidence = elements.filter { $0.confidence > 0.8 }
        let mediumConfidence = elements.filter { $0.confidence > 0.5 && $0.confidence <= 0.8 }
        let lowConfidence = elements.filter { $0.confidence <= 0.5 }
        
        return [
            "elementTypes": [
                "buttons": buttons.count,
                "textFields": textFields.count,
                "images": images.count,
                "staticTexts": staticTexts.count,
                "other": elements.count - buttons.count - textFields.count - images.count - staticTexts.count
            ],
            "spatialDistribution": [
                "topHalf": topHalf.count,
                "bottomHalf": bottomHalf.count
            ],
            "confidenceDistribution": [
                "high": highConfidence.count,
                "medium": mediumConfidence.count,
                "low": lowConfidence.count
            ],
            "actionableElements": elements.filter { $0.isClickable }.map { element in
                [
                    "id": element.id,
                    "type": element.type,
                    "position": ["x": element.position.x, "y": element.position.y],
                    "actionHint": element.actionHint ?? "Click element",
                    "visualText": element.visualText ?? ""
                ]
            },
            "recommendations": generateRecommendations(completeMap)
        ]
    }
    
    private func generateRecommendations(_ completeMap: CompleteUIMap) -> [String] {
        var recommendations: [String] = []
        
        let elements = completeMap.elements
        let lowConfidenceCount = elements.filter { $0.confidence < 0.5 }.count
        let unfusedCount = elements.filter { ($0.accessibilityData == nil) != ($0.ocrData == nil) }.count
        
        if lowConfidenceCount > elements.count / 4 {
            recommendations.append("Consider improving OCR accuracy - \(lowConfidenceCount) elements have low confidence")
        }
        
        if unfusedCount > elements.count / 3 {
            recommendations.append("Spatial correlation could be improved - \(unfusedCount) elements remain unfused")
        }
        
        if completeMap.performance.ocrTime > 1.0 {
            recommendations.append("OCR processing is slow (\(String(format: "%.2f", completeMap.performance.ocrTime))s) - consider optimizing image preprocessing")
        }
        
        if completeMap.summary.clickableElements.isEmpty {
            recommendations.append("No clickable elements detected - accessibility data may be incomplete")
        }
        
        if completeMap.summary.confidence < 0.6 {
            recommendations.append("Overall confidence is low (\(String(format: "%.2f", completeMap.summary.confidence))) - consider multiple OCR passes")
        }
        
        return recommendations
    }
}

// MARK: - Entry Point

let app = UIInspectorApp()
app.run() 