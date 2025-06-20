#!/usr/bin/env swift

import Foundation
import AppKit

// MARK: - Main Application

class UIInspectorApp {
    private let windowManager: WindowManager
    private let accessibilityEngine: AccessibilityEngine
    private let ocrEngine: OCREngine
    private let performanceMonitor: PerformanceMonitor
    
    init() {
        self.windowManager = WindowManager()
        self.accessibilityEngine = AccessibilityEngine()
        self.ocrEngine = OCREngine()
        self.performanceMonitor = PerformanceMonitor()
    }
    
    func run() {
        let overallStartTime = Date()
        var stepTimes: [(String, TimeInterval)] = []
        
        print("🚀 UI Inspector - Refactored Architecture")
        print("==========================================")
        
        // Step 1: Ensure Finder window is available
        let setupStart = Date()
        windowManager.ensureFinderWindow()
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
        
        // Step 6: Coordinate correction and fusion
        let fusionStart = Date()
        let correctedOCRElements = correctOCRCoordinates(filteredOCRElements, windowFrame: windowInfo.frame)
        let validatedAccessibilityElements = validateAccessibilityCoordinates(accessibilityElements, coordinateSystem: coordinateSystem)
        
        let fusionEngine = FusionEngine(coordinateSystem: coordinateSystem)
        let fusedElements = fusionEngine.fuse(
            accessibility: validatedAccessibilityElements,
            ocr: correctedOCRElements,
            coordinates: coordinateSystem
        )
        let fusionTime = Date().timeIntervalSince(fusionStart)
        stepTimes.append(("Data fusion", fusionTime))
        
        // Step 7: Grid mapping
        let gridStart = Date()
        let gridMapper = GridSweepMapper(windowFrame: windowInfo.frame)
        let gridMappedElements = gridMapper.mapToGrid(fusedElements)
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
            elements: fusedElements,
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(overallStartTime),
            performance: CompleteUIMap.PerformanceMetrics(
                accessibilityTime: accessibilityTime,
                screenshotTime: windowTime,
                ocrTime: ocrTime,
                fusionTime: fusionTime,
                totalElements: accessibilityElements.count + filteredOCRElements.count,
                fusedElements: fusedElements.count,
                memoryUsage: performanceMonitor.getMemoryUsage()
            ),
            summary: CompleteUIMap.UIMapSummary(from: fusedElements)
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
            try compressedFormat.write(to: URL(fileURLWithPath: compressedPath), atomically: false, encoding: .utf8)
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
            fusedElements: fusedElements,
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
        
        // Check for main content elements
        let mainContentKeywords = ["macintosh", "network", "drive"]
        var mainContentFound = false
        
        for element in fusedElements {
            if let text = element.visualText,
               mainContentKeywords.contains(where: { text.lowercased().contains($0) }) {
                let coordinateSystem = CoordinateSystem(windowFrame: windowFrame)
                let debugInfo = coordinateSystem.debugCoordinateInfo(for: element.position)
                
                print("\n📍 Main Content Element: '\(text)'")
                print("   Debug Info: \(debugInfo)")
                mainContentFound = true
            }
        }
        
        if !mainContentFound {
            print("⚠️  No main content elements found - coordinate system may need adjustment")
        }
        
        // Region distribution
        let coordinateSystem = CoordinateSystem(windowFrame: windowFrame)
        var regionCounts: [GridRegion: Int] = [:]
        
        for element in gridElements {
            let region = coordinateSystem.classifyRegion(for: element.gridPosition)
            regionCounts[region, default: 0] += 1
        }
        
        print("\n📊 Element Distribution by Region:")
        for (region, count) in regionCounts {
            print("   \(region.rawValue): \(count) elements")
        }
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