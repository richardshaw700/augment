#!/usr/bin/env swift

import Foundation
import AppKit

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
    private let edgeDetectionEngine: EdgeDetectionEngine
    
    init() {
        self.windowManager = WindowManager()
        self.accessibilityEngine = AccessibilityEngine()
        self.ocrEngine = OCREngine()
        self.performanceMonitor = PerformanceMonitor()
        self.browserInspector = BrowserInspector()
        self.edgeDetectionEngine = EdgeDetectionEngine()
    }
    
    func run() {
        let overallStartTime = Date()
        var stepTimes: [(String, TimeInterval)] = []
        
        print("🚀 UI Inspector - Refactored Architecture")
        print("==========================================")
        
        // Step 1: Ensure app window is available
        let setupStart = Date()
        windowManager.ensureAppWindow()
        let setupTime = Date().timeIntervalSince(setupStart)
        stepTimes.append(("App setup", setupTime))
        
        // Step 2: Get window information and capture screenshot
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
        
        print("📐 Window: \(windowInfo.title) (\(windowInfo.frame.width)x\(windowInfo.frame.height))")
        
        // Step 3: Initialize coordinate system with ACTUAL window bounds
        let coordinateSystem = CoordinateSystem(windowFrame: windowInfo.frame)
        
        // Step 4: Collect accessibility data
        let accessibilityStart = Date()
        let accessibilityElements = accessibilityEngine.scanElements()
        let accessibilityTime = Date().timeIntervalSince(accessibilityStart)
        stepTimes.append(("Accessibility scan", accessibilityTime))
        
        // Step 5: Perform OCR
        let ocrStart = Date()
        let rawOCRElements = ocrEngine.extractText(from: screenshot)
        let filteredOCRElements = ocrEngine.filterTextElements(rawOCRElements)
        let ocrTime = Date().timeIntervalSince(ocrStart)
        stepTimes.append(("OCR processing", ocrTime))
        
        // Step 5.5: Edge Detection for Input Fields
        let edgeDetectionStart = Date()
        let visualElements = edgeDetectionEngine.detectVisualElements(in: screenshot)
        let edgeDetectionTime = Date().timeIntervalSince(edgeDetectionStart)
        stepTimes.append(("Edge detection", edgeDetectionTime))
        
        // Step 6: Coordinate correction and fusion
        let fusionStart = Date()
        let correctedOCRElements = correctOCRCoordinates(filteredOCRElements, windowFrame: windowInfo.frame)
        let validatedAccessibilityElements = validateAccessibilityCoordinates(accessibilityElements, coordinateSystem: coordinateSystem)
        
        let fusionEngine = ImprovedFusionEngine(coordinateSystem: coordinateSystem)
        // COMPARISON: Test OCR-only vs Fusion
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
        
        // Step 6a: Integrate Visual Elements (Edge Detection)
        let fusedWithVisualElements = integrateVisualElements(
            fusedElements: fusedElements,
            visualElements: visualElements,
            windowFrame: windowInfo.frame
        )
        
        // Step 6b: Browser Enhancement (if in browser context)
        let enhancedElements: [UIElement]
        if BrowserInspector.isBrowserApp(AppConfig.bundleID),
           let browserType = BrowserInspector.getBrowserType(AppConfig.bundleID) {
            print("🌐 Browser detected: \(browserType.rawValue)")
            enhancedElements = browserInspector.enhanceBrowserElements(fusedWithVisualElements, browserType: browserType)
        } else {
            enhancedElements = fusedWithVisualElements
        }
        
        print("\n🔍 COMPARISON - OCR-only vs Fusion vs Visual vs Enhanced:")
        print("   OCR-only elements: \(ocrOnlyElements.count)")
        print("   Fused elements: \(fusedElements.count)")
        print("   + Visual elements: \(fusedWithVisualElements.count)")
        print("   Final enhanced: \(enhancedElements.count)")
        print("   Visual contribution: \(visualElements.count)")
        print("   Accessibility contribution: \(fusedElements.count - ocrOnlyElements.count)")
        print("   Browser enhancement: \(enhancedElements.count - fusedWithVisualElements.count)")
        
        // Use enhanced elements as final result
        let finalElements = enhancedElements
        let fusionTime = Date().timeIntervalSince(fusionStart)
        stepTimes.append(("Data fusion", fusionTime))
        
        // Step 7: Grid mapping
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
        
        let compressedPath = "/Users/richardshaw/augment/ui_compressed_\(timestamp).txt"
        let jsonPath = "/Users/richardshaw/augment/ui_map_\(timestamp).json"
        
        do {
            try compressedFormat.write(to: URL(fileURLWithPath: compressedPath), atomically: false, encoding: String.Encoding.utf8)
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))
        } catch {
            print("❌ Failed to save files: \(error)")
        }
        let outputTime = Date().timeIntervalSince(outputStart)
        stepTimes.append(("Output generation", outputTime))
        
        let totalTime = Date().timeIntervalSince(overallStartTime)
        
        // Print performance results
        printPerformanceResults(stepTimes: stepTimes, totalTime: totalTime)
        
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
        visualElements: [VisualElement], 
        windowFrame: CGRect
    ) -> [UIElement] {
        var integratedElements = fusedElements
        let spatialThreshold: CGFloat = 30.0  // Distance threshold for avoiding duplicates
        
        print("🎨 Integrating \(visualElements.count) visual elements...")
        
        for visualElement in visualElements {
            // Check if this visual element overlaps significantly with existing elements
            let hasSignificantOverlap = integratedElements.contains { existing in
                let existingRect = CGRect(origin: existing.position, size: existing.size)
                let visualRect = visualElement.boundingBox
                
                // Calculate intersection
                let intersection = existingRect.intersection(visualRect)
                let overlapArea = intersection.width * intersection.height
                let visualArea = visualRect.width * visualRect.height
                
                // If more than 50% of the visual element overlaps with existing, skip it
                return overlapArea > (visualArea * 0.5)
            }
            
            if !hasSignificantOverlap {
                // Convert visual element to UI element
                let newUIElement = createUIElementFromVisual(
                    visualElement: visualElement,
                    windowFrame: windowFrame
                )
                integratedElements.append(newUIElement)
                
                print("   ✅ Added visual element: \(visualElement.elementType) at (\(Int(visualElement.boundingBox.origin.x)), \(Int(visualElement.boundingBox.origin.y)))")
            } else {
                print("   ⚠️ Skipped overlapping visual element: \(visualElement.elementType)")
            }
        }
        
        print("🎨 Visual integration complete: \(integratedElements.count - fusedElements.count) new elements added")
        return integratedElements
    }
    
    private func createUIElementFromVisual(
        visualElement: VisualElement,
        windowFrame: CGRect
    ) -> UIElement {
        // Adjust coordinates to be relative to window frame
        let adjustedPosition = CGPoint(
            x: windowFrame.origin.x + visualElement.boundingBox.origin.x,
            y: windowFrame.origin.y + visualElement.boundingBox.origin.y
        )
        
        return UIElement(
            type: "Visual_\(visualElement.elementType)",
            position: adjustedPosition,
            size: visualElement.boundingBox.size,
            accessibilityData: nil,
            ocrData: nil,
            isClickable: visualElement.isInteractive,
            confidence: visualElement.confidence
        )
    }
    
    private func printPerformanceResults(stepTimes: [(String, TimeInterval)], totalTime: TimeInterval) {
        print("\n⏱️  PERFORMANCE BREAKDOWN:")
        print(String(repeating: "=", count: 50))
        for (step, time) in stepTimes {
            let percentage = (time / totalTime) * 100
            print("  • \(step): \(String(format: "%.3f", time))s (\(String(format: "%.1f", percentage))%)")
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