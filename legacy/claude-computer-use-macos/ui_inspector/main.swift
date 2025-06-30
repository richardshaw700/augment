#!/usr/bin/env swift

import Foundation
import AppKit

// MARK: - Debug Configuration
struct DebugConfig {
    static let isEnabled = false  // Set to false for production logs
}

// MARK: - App Configuration
// Change these values to test different applications
struct AppConfig {
    // Current configuration - Safari
    static let bundleID = "com.apple.Safari"
    static let appName = "Safari"
    static let displayName = "Safari"
    
    // Other popular app configurations (uncomment to use):
    
    // Finder
    // static let bundleID = "com.apple.finder"
    // static let appName = "Finder"
    // static let displayName = "Finder"
    
    // Chrome
    // static let bundleID = "com.google.Chrome"
    // static let appName = "Google Chrome"
    // static let displayName = "Chrome"
    
    // Firefox
    // static let bundleID = "org.mozilla.firefox"
    // static let appName = "Firefox"
    // static let displayName = "Firefox"
    
    // VS Code
    // static let bundleID = "com.microsoft.VSCode"
    // static let appName = "Visual Studio Code"
    // static let displayName = "VS Code"
    
    // Terminal
    // static let bundleID = "com.apple.Terminal"
    // static let appName = "Terminal"
    // static let displayName = "Terminal"
    
    // TextEdit
    // static let bundleID = "com.apple.TextEdit"
    // static let appName = "TextEdit"
    // static let displayName = "TextEdit"
}

// MARK: - Main Application

class UIInspectorApp {
    private let windowManager: WindowManager
    private let accessibilityEngine: AccessibilityEngine
    private let ocrEngine: OCREngine
    private let performanceMonitor: PerformanceMonitor
    private let browserInspector: BrowserInspector
    private let shapeDetectionEngine: ShapeDetectionEngine
    
    init() {
        self.windowManager = WindowManager()
        self.accessibilityEngine = AccessibilityEngine()
        self.ocrEngine = OCREngine()
        self.performanceMonitor = PerformanceMonitor()
        self.browserInspector = BrowserInspector()
        self.shapeDetectionEngine = ShapeDetectionEngine()
    }
    
    func run() {
        let overallStartTime = Date()
        var stepTimes: [(String, TimeInterval)] = []
        
        print("🚀 UI Inspector - Refactored Architecture")
        print("==========================================")
        
        // Step 1: App Setup & Window Capture
        print("\n📱 WINDOW SETUP")
        print("================")
        let setupStart = Date()
        windowManager.ensureAppWindow()
        let setupTime = Date().timeIntervalSince(setupStart)
        stepTimes.append(("App setup", setupTime))
        
        let windowStart = Date()
        guard let windowInfo = windowManager.getActiveWindow() else {
            print("❌ No active window found")
            return
        }
        
        guard let screenshot = windowManager.captureWindow(windowInfo) else {
            print("❌ Failed to capture window")
            return
        }
        let windowTime = Date().timeIntervalSince(windowStart)
        stepTimes.append(("Window capture", windowTime))
        
        print("📐 Target: \(windowInfo.title) (\(Int(windowInfo.frame.width))x\(Int(windowInfo.frame.height)))")
        
        // Step 2: Initialize coordinate system
        let coordinateSystem = CoordinateSystem(windowFrame: windowInfo.frame)
        
        // Step 3-5: Parallel Detection (Accessibility + OCR + Shape Detection)
        print("\n⚡ PARALLEL DETECTION")
        print("====================")
        print("🔄 Running Accessibility, OCR, and Shape Detection in parallel...")
        
        let parallelStart = Date()
        
        // Create dispatch group for parallel execution
        let dispatchGroup = DispatchGroup()
        let detectionQueue = DispatchQueue(label: "com.uiinspector.detection", attributes: .concurrent)
        
        // Results storage with thread-safe access
        var accessibilityElements: [AccessibilityData] = []
        var filteredOCRElements: [OCRData] = []
        var shapeElements: [UIShapeCandidate] = []
        var accessibilityTime: TimeInterval = 0
        var ocrTime: TimeInterval = 0
        var shapeDetectionTime: TimeInterval = 0
        
        let resultsQueue = DispatchQueue(label: "com.uiinspector.results")
        
        // Parallel Task 1: Accessibility Detection
        dispatchGroup.enter()
        detectionQueue.async {
            let taskStart = Date()
            let elements = self.accessibilityEngine.scanElements()
            let taskTime = Date().timeIntervalSince(taskStart)
            
            resultsQueue.async {
                accessibilityElements = elements
                accessibilityTime = taskTime
                print("♿ Accessibility scan completed: \(elements.count) elements (\(String(format: "%.3f", taskTime))s)")
                dispatchGroup.leave()
            }
        }
        
        // Parallel Task 2: OCR Text Detection
        dispatchGroup.enter()
        detectionQueue.async {
            let taskStart = Date()
            let rawOCRElements = self.ocrEngine.extractText(from: screenshot)
            let filtered = self.ocrEngine.filterTextElements(rawOCRElements)
            let taskTime = Date().timeIntervalSince(taskStart)
            
            resultsQueue.async {
                filteredOCRElements = filtered
                ocrTime = taskTime
                print("🔤 OCR processing completed: \(filtered.count) elements (\(String(format: "%.3f", taskTime))s)")
                dispatchGroup.leave()
            }
        }
        
        // Parallel Task 3: Shape Detection
        dispatchGroup.enter()
        detectionQueue.async {
            let taskStart = Date()
            let elements = self.shapeDetectionEngine.detectUIShapes(in: screenshot, windowFrame: windowInfo.frame, debug: DebugConfig.isEnabled)
            let taskTime = Date().timeIntervalSince(taskStart)
            
            resultsQueue.async {
                shapeElements = elements
                shapeDetectionTime = taskTime
                print("🔍 Shape detection completed: \(elements.count) elements (\(String(format: "%.3f", taskTime))s)")
                dispatchGroup.leave()
            }
        }
        
        // Wait for all parallel tasks to complete
        dispatchGroup.wait()
        
        let parallelTime = Date().timeIntervalSince(parallelStart)
        print("⚡ Parallel detection completed in \(String(format: "%.3f", parallelTime))s")
        print("   └─ Speedup: \(String(format: "%.1f", (accessibilityTime + ocrTime + shapeDetectionTime) / parallelTime))x faster than sequential")
        
        // Record individual times for performance analysis
        stepTimes.append(("Accessibility scan", accessibilityTime))
        stepTimes.append(("OCR processing", ocrTime))
        stepTimes.append(("Shape detection", shapeDetectionTime))
        
        // Record parallel execution time for performance display
        stepTimes.append(("Parallel detection group", parallelTime))
        
        if DebugConfig.isEnabled {
            print("------------------------")
            print("🔍 DEBUG")
            print("------------------------")
            // Debug info is printed inside ShapeDetectionEngine
        }
        
        // Step 6: Data Fusion & Integration
        print("\n🔗 DATA FUSION")
        print("==============")
        let fusionStart = Date()
        let correctedOCRElements = correctOCRCoordinates(filteredOCRElements, windowFrame: windowInfo.frame)
        let validatedAccessibilityElements = validateAccessibilityCoordinates(accessibilityElements, coordinateSystem: coordinateSystem)
        
        let fusionEngine = ImprovedFusionEngine(coordinateSystem: coordinateSystem)
        let ocrOnlyElements = correctedOCRElements.map { ocrData in
            UIElement(
                type: "TextContent",
                position: ocrData.boundingBox.origin,
                size: ocrData.boundingBox.size,
                accessibilityData: nil,
                ocrData: ocrData,
                isClickable: false,
                confidence: Double(ocrData.confidence)
            )
        }
        let fusedElements = fusionEngine.fuse(
            accessibility: validatedAccessibilityElements,
            ocr: correctedOCRElements,
            coordinates: coordinateSystem
        )
        
        // Integrate Visual Elements (Shape Detection)
        let fusedWithVisualElements = integrateVisualElements(
            fusedElements: fusedElements,
            visualElements: shapeElements,
            ocrElements: correctedOCRElements,
            windowFrame: windowInfo.frame
        )
        
        // Step 7: Browser Enhancement
        print("\n🌐 BROWSER ENHANCEMENT")
        print("======================")
        let enhancedElements: [UIElement]
        if BrowserInspector.isBrowserApp(AppConfig.bundleID),
           let browserType = BrowserInspector.getBrowserType(AppConfig.bundleID) {
            print("🔍 Browser: \(browserType.rawValue)")
            enhancedElements = browserInspector.enhanceBrowserElements(fusedWithVisualElements, browserType: browserType)
        } else {
            print("🔍 Browser: Not detected")
            enhancedElements = fusedWithVisualElements
        }
        
        print("\n📊 DETECTION SUMMARY")
        print("====================")
        print("📈 Element Count Progression:")
        print("   OCR-only: \(ocrOnlyElements.count)")
        print("   + Accessibility: \(fusedElements.count) (+\(fusedElements.count - ocrOnlyElements.count))")
        print("   + Shapes: \(fusedWithVisualElements.count) (+\(shapeElements.count))")
        print("   + Browser: \(enhancedElements.count) (+\(enhancedElements.count - fusedWithVisualElements.count))")
        
        // Filter out low-quality elements before final processing
        let filteredElements = filterMeaningfulElements(enhancedElements)
        print("🧹 Filtered out \(enhancedElements.count - filteredElements.count) low-quality elements")
        
        // Use filtered elements as final result
        let finalElements = filteredElements
        let fusionTime = Date().timeIntervalSince(fusionStart)
        stepTimes.append(("Data fusion", fusionTime))
        
        // Step 8: Grid Mapping
        print("\n🗂️ GRID MAPPING")
        print("===============")
        let gridStart = Date()
        let gridMapper = GridSweepMapper(windowFrame: windowInfo.frame)
        let gridMappedElements = gridMapper.mapToGrid(finalElements)
        let gridTime = Date().timeIntervalSince(gridStart)
        stepTimes.append(("Grid mapping", gridTime))
        
        // Step 8: Compression
        let compressionStart = Date()
        let compressionEngine = CompressionEngine()
        let compressed = compressionEngine.compress(gridMappedElements)
        let compressionTime = Date().timeIntervalSince(compressionStart)
        stepTimes.append(("Compression", compressionTime))
        
        // Step 9: Create complete UI map
        let mapCreationStart = Date()
        let windowContext = WindowContext(
            windowFrame: windowInfo.frame,
            windowTitle: windowInfo.title,
            appName: windowInfo.ownerName,
            timestamp: Date()
        )
        
        let completeMap = CompleteUIMap(
            windowTitle: windowInfo.title,
            windowFrame: windowInfo.frame,
            elements: finalElements,
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(overallStartTime),
            performance: CompleteUIMap.PerformanceMetrics(
                accessibilityTime: accessibilityTime,
                screenshotTime: windowTime,
                ocrTime: ocrTime,
                fusionTime: fusionTime,
                totalElements: accessibilityElements.count + filteredOCRElements.count,
                fusedElements: finalElements.count,
                memoryUsage: performanceMonitor.getMemoryUsage()
            ),
            summary: CompleteUIMap.UIMapSummary(from: finalElements)
        )
        let mapCreationTime = Date().timeIntervalSince(mapCreationStart)
        stepTimes.append(("Map creation", mapCreationTime))
        
        // Step 10: Output generation
        let outputStart = Date()
        let outputManager = OutputManager()
        let jsonData = outputManager.toJSON(completeMap)
        let compressedFormat = outputManager.toCompressed(completeMap)
        
        // Save files
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: completeMap.timestamp)
        
        let compressedPath = "./ui_compressed_\(timestamp).txt"
        let jsonPath = "./ui_map_\(timestamp).json"
        
        do {
            try compressedFormat.write(to: URL(fileURLWithPath: compressedPath), atomically: false, encoding: String.Encoding.utf8)
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))
        } catch {
            print("❌ Failed to save files: \(error)")
        }
        let outputTime = Date().timeIntervalSince(outputStart)
        stepTimes.append(("Output generation", outputTime))
        
        let totalTime = Date().timeIntervalSince(overallStartTime)
        
        // Extract shape elements from filtered final elements for button summary
        let filteredShapeElements = extractShapeElementsFromFiltered(finalElements)
        
        // Print button summary
        printButtonSummary(elements: finalElements, shapeElements: filteredShapeElements)
        
        // Print performance results
        printPerformanceResults(stepTimes: stepTimes, totalTime: totalTime)
        
        // Print window capture diagnostics
        WindowManager.printCaptureStats()
        
        // Print coordinate debugging info
        printCoordinateDebugging(
            windowFrame: windowInfo.frame,
            accessibilityElements: validatedAccessibilityElements,
            ocrElements: correctedOCRElements,
            fusedElements: finalElements,
            gridElements: gridMappedElements
        )
        
        // Print results
        printResults(completeMap: completeMap, compressed: compressed)
        
        print("💾 Files saved:")
        print("  📄 JSON: \(jsonPath)")
        print("  🗜️  Compressed: \(compressedPath)")
    }
    
    // MARK: - Coordinate Correction
    
    private func correctOCRCoordinates(_ ocrElements: [OCRData], windowFrame: CGRect) -> [OCRData] {
        return ocrElements.map { ocrData in
            // Convert Vision's normalized coordinates to window-relative coordinates
            let bbox = ocrData.boundingBox
            
            // Vision coordinates: (0,0) at bottom-left, normalized
            // Convert to: window-relative absolute coordinates with (0,0) at top-left
            let absoluteX = windowFrame.origin.x + (bbox.origin.x * windowFrame.width)
            let absoluteY = windowFrame.origin.y + ((1.0 - bbox.origin.y - bbox.height) * windowFrame.height)
            let absoluteWidth = bbox.width * windowFrame.width
            let absoluteHeight = bbox.height * windowFrame.height
            
            let correctedBounds = CGRect(
                x: absoluteX,
                y: absoluteY,
                width: absoluteWidth,
                height: absoluteHeight
            )
            
            return OCRData(
                text: ocrData.text,
                confidence: ocrData.confidence,
                boundingBox: correctedBounds
            )
        }
    }
    
    private func validateAccessibilityCoordinates(_ accessibilityElements: [AccessibilityData], coordinateSystem: CoordinateSystem) -> [AccessibilityData] {
        return accessibilityElements.map { coordinateSystem.validateAccessibilityCoordinates($0) }
    }
    
    // MARK: - Debug Output
    
    private func printCoordinateDebugging(
        windowFrame: CGRect,
        accessibilityElements: [AccessibilityData],
        ocrElements: [OCRData],
        fusedElements: [UIElement],
        gridElements: [GridMappedElement]
    ) {
        print("\n🎯 COORDINATE DEBUGGING:")
        print("========================")
        print("Window Frame: \(windowFrame)")
        print("Grid: \(UniversalGrid.COLUMNS) columns × \(UniversalGrid.ROWS) rows = \(UniversalGrid.COLUMNS * UniversalGrid.ROWS) cells")
        
        // Show sample grid positions for key elements
        let keywordElements = fusedElements.filter { element in
            guard let text = element.visualText else { return false }
            return ["macintosh", "network", "drive", "downloads", "desktop", "applications"].contains(where: { text.lowercased().contains($0) })
        }
        
        print("\n📍 Key Elements Grid Positions:")
        let coordinateSystem = CoordinateSystem(windowFrame: windowFrame)
        for element in keywordElements.prefix(5) {
            let debugInfo = coordinateSystem.debugCoordinateInfo(for: element.position)
            print("   '\(element.visualText ?? "Unknown")' -> \(debugInfo["grid"] ?? "?")")
        }
        
        // Grid cell occupancy
        var occupiedCells = Set<String>()
        for element in gridElements {
            occupiedCells.insert(element.gridPosition.description)
        }
        
        print("\n📊 Grid Coverage:")
        print("   Occupied cells: \(occupiedCells.count)/\(UniversalGrid.COLUMNS * UniversalGrid.ROWS)")
        print("   Coverage: \(String(format: "%.1f", Double(occupiedCells.count) / Double(UniversalGrid.COLUMNS * UniversalGrid.ROWS) * 100))%")
        print("   Elements after deduplication: \(gridElements.count)")
    }
    
    // MARK: - Visual Element Integration
    
    private func integrateVisualElements(
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
                    let enhancedElement = enhanceElementWithButtonContext(
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
                let newUIElement = createUIElementFromVisual(
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
    
    private func enhanceElementWithButtonContext(
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
    
    private func filterMeaningfulElements(_ elements: [UIElement]) -> [UIElement] {
        return elements.filter { element in
            // Keep all non-button elements
            guard element.type.contains("Button") || element.isClickable else {
                return true
            }
            
            // Filter criteria for buttons
            return hasMeaningfulContext(element)
        }
    }
    
    private func hasMeaningfulContext(_ element: UIElement) -> Bool {
        let size = element.size
        let area = size.width * size.height
        
        // Filter out tiny buttons (likely UI artifacts)
        if area < 400 { // Less than 20x20 pixels
            return false
        }
        
        // Check for meaningful text content
        let hasGoodText = hasQualityText(element)
        
        // Check for meaningful accessibility description
        let hasGoodAccessibility = hasQualityAccessibility(element)
        
        // Check for meaningful action hint
        let hasGoodAction = hasQualityActionHint(element)
        
        // Must have at least one meaningful piece of context
        return hasGoodText || hasGoodAccessibility || hasGoodAction
    }
    
    private func hasQualityText(_ element: UIElement) -> Bool {
        guard let text = element.visualText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        
        // Filter out empty or very short text
        if text.isEmpty || text.count < 2 {
            return false
        }
        
        // Filter out generic/meaningless text
        let lowercased = text.lowercased()
        let meaninglessTexts = ["no text", "button", "click", "element", "ui", "icon"]
        
        return !meaninglessTexts.contains(lowercased)
    }
    
    private func hasQualityAccessibility(_ element: UIElement) -> Bool {
        guard let accessibility = element.accessibilityData else {
            return false
        }
        
        // Check for meaningful description
        if let description = accessibility.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty && description.count > 2 {
            let lowercased = description.lowercased()
            let meaninglessDescs = ["button", "element", "ui", "icon", "click"]
            return !meaninglessDescs.contains(lowercased)
        }
        
        // Check for meaningful title
        if let title = accessibility.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty && title.count > 2 {
            let lowercased = title.lowercased()
            let meaninglessTitles = ["button", "element", "ui", "icon", "click"]
            return !meaninglessTitles.contains(lowercased)
        }
        
        return false
    }
    
    private func extractShapeElementsFromFiltered(_ elements: [UIElement]) -> [UIShapeCandidate] {
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
    
    private func hasQualityActionHint(_ element: UIElement) -> Bool {
        guard let actionHint = element.actionHint?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        
        // Filter out generic action hints
        let genericHints = [
            "clickable element",
            "click element", 
            "button button",
            "click button",
            "click ui",
            "click icon"
        ]
        
        let lowercased = actionHint.lowercased()
        return !genericHints.contains(lowercased) && actionHint.count > 10
    }
    
    private func findOCRTextInButton(buttonCandidate: UIShapeCandidate, ocrElements: [OCRData]) -> String {
        let buttonRect = buttonCandidate.boundingBox
        var foundTexts: [String] = []
        
        for ocrElement in ocrElements {
            let ocrRect = ocrElement.boundingBox
            
            // Check if OCR text overlaps with button area (with some tolerance)
            let expandedButtonRect = buttonRect.insetBy(dx: -5, dy: -5) // 5px tolerance
            
            if expandedButtonRect.intersects(ocrRect) {
                // Calculate overlap percentage
                let intersection = expandedButtonRect.intersection(ocrRect)
                let overlapArea = intersection.width * intersection.height
                let ocrArea = ocrRect.width * ocrRect.height
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
    
    private func createUIElementFromVisual(
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
    
    private func printButtonSummary(elements: [UIElement], shapeElements: [UIShapeCandidate]) {
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
    
    private func printPerformanceResults(stepTimes: [(String, TimeInterval)], totalTime: TimeInterval) {
        print("\n⏱️  PERFORMANCE BREAKDOWN:")
        print(String(repeating: "=", count: 50))
        
        // Find parallel detection group time
        var parallelGroupTime: TimeInterval = 0
        var parallelSteps: [(String, TimeInterval)] = []
        var otherSteps: [(String, TimeInterval)] = []
        
        for (step, time) in stepTimes {
            switch step {
            case "Parallel detection group":
                parallelGroupTime = time
            case "Accessibility scan", "OCR processing", "Shape detection":
                parallelSteps.append((step, time))
            default:
                otherSteps.append((step, time))
            }
        }
        
        // Print non-parallel steps first
        for (step, time) in otherSteps {
            let percentage = (time / totalTime) * 100
            print("  • \(step): \(String(format: "%.3f", time))s (\(String(format: "%.1f", percentage))%)")
        }
        
        // Print parallel detection group
        if parallelGroupTime > 0 {
            let percentage = (parallelGroupTime / totalTime) * 100
            print("  ⚡ Parallel Detection Group: \(String(format: "%.3f", parallelGroupTime))s (\(String(format: "%.1f", percentage))%)")
            
            // Calculate sequential time for comparison
            let sequentialTime = parallelSteps.reduce(0) { $0 + $1.1 }
            let speedup = sequentialTime / parallelGroupTime
            
            // Print individual parallel tasks with indentation
            for (step, time) in parallelSteps.sorted(by: { $0.1 > $1.1 }) {
                let percentage = (time / totalTime) * 100
                print("    ├─ \(step): \(String(format: "%.3f", time))s (\(String(format: "%.1f", percentage))%)")
            }
            print("    └─ Sequential would be: \(String(format: "%.3f", sequentialTime))s (\(String(format: "%.1f", speedup))x speedup)")
        }
        
        print(String(repeating: "-", count: 50))
        print("  🏁 TOTAL TIME: \(String(format: "%.3f", totalTime))s")
    }
    
    private func printResults(completeMap: CompleteUIMap, compressed: AdaptiveCompressedUI) {
        print("\n🚀 RESULTS:")
        print("===========")
        print("📱 Window: \(completeMap.windowTitle)")
        print("📏 Frame: \(completeMap.windowFrame)")
        print("🔢 Elements: \(completeMap.elements.count)")
        print("🗜️  Compressed: \(compressed.format)")
        print("📊 Compression: \(String(format: "%.1f", compressed.compressionRatio))x smaller")
        print("🎯 Confidence: \(String(format: "%.1f", compressed.confidence * 100))%")
    }
}

// MARK: - Entry Point

let app = UIInspectorApp()
app.run() 