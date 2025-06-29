import Foundation
import AppKit

// MARK: - Pure UI Inspector Orchestrator
//
// This orchestrator follows clean architecture principles - it only coordinates
// and delegates to specialized services. All helper functions have been moved
// to their appropriate service classes.

// MARK: - Main Application

class UIInspectorApp {
    private let windowManager: WindowManager
    private let parallelCoordinator: ParallelDetectionCoordinator
    private let performanceMonitor: PerformanceMonitor
    private let outputManager: OutputManager
    
    init() {
        self.windowManager = WindowManager()
        self.parallelCoordinator = ParallelDetectionCoordinator()
        self.performanceMonitor = PerformanceMonitor()
        self.outputManager = OutputManager()
    }
    
    func run() {
        let overallStartTime = Date()
        
        print("🚀 UI Inspector - Clean Architecture")
        print("====================================")
        
        // Step 1: App Detection & Window Setup
        performanceMonitor.startTiming()
        performanceMonitor.startAppDetection()
        AppConfig.detectActiveApp()
        performanceMonitor.recordAppDetection()
        
        guard let windowInfo = windowManager.getActiveWindow() else {
            print("❌ Failed to get window info")
            return
        }
        
        performanceMonitor.startWindowCapture()
        guard let nsScreenshot = windowManager.captureWindow(windowInfo) else {
            print("❌ Failed to capture window")
            return
        }
        
        // Convert NSImage to CGImage for the parallel coordinator
        guard let cgScreenshot = nsScreenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to convert screenshot to CGImage")
            return
        }
        
        performanceMonitor.recordWindowCapture()
        
        print("📐 Target: \(windowInfo.title) (\(Int(windowInfo.frame.width))x\(Int(windowInfo.frame.height)))")
        
        // Step 2: Initialize coordinate system
        performanceMonitor.startCoordinateSystem()
        let coordinateSystem = CoordinateSystem(windowFrame: windowInfo.frame)
        performanceMonitor.recordCoordinateSystem()
        
        // Step 3: Parallel Detection
        print("\n⚡ PARALLEL DETECTION")
        print("====================")
        
        let detectionResults = parallelCoordinator.executeParallelDetection(
            screenshot: cgScreenshot,
            windowFrame: windowInfo.frame,
            visualConfig: VisualConfig.captureRichVisualElements,
            debugEnabled: DebugConfig.isEnabled
        )
        
        // Record individual detection times
        performanceMonitor.accessibilityTime = detectionResults.accessibilityTime
        performanceMonitor.ocrTime = detectionResults.ocrTime
        performanceMonitor.shapeDetectionTime = detectionResults.shapeDetectionTime
        performanceMonitor.menuBarTime = detectionResults.menuBarTime
        
        // Step 4: Data Processing & Fusion
        print("\n🔗 DATA FUSION")
        print("==============")
        performanceMonitor.startFusion()
        
        // Coordinate correction using CoordinateSystem extension
        performanceMonitor.startDataCorrection()
        let correctedOCRElements = coordinateSystem.correctOCRCoordinates(detectionResults.ocrElements, windowFrame: windowInfo.frame)
        let validatedAccessibilityElements = coordinateSystem.validateAccessibilityCoordinates(detectionResults.accessibilityElements)
        performanceMonitor.recordDataCorrection()
        
        // Data fusion with quality filtering
        let fusionEngine = ImprovedFusionEngine(coordinateSystem: coordinateSystem)
        let fusedElements = fusionEngine.fuse(
            accessibility: validatedAccessibilityElements,
            ocr: correctedOCRElements,
            coordinates: coordinateSystem
        )
        
        // Visual element integration with deduplication
        let finalElements = fusionEngine.integrateVisualElements(
            fusedElements: fusedElements,
            visualElements: detectionResults.shapeElements,
            ocrElements: correctedOCRElements,
            windowFrame: windowInfo.frame
        )
        
        // Element quality filtering
        performanceMonitor.startElementFiltering()
        let elementFilter = ElementQualityFilter()
        let filteredElements = elementFilter.filterMeaningfulElements(finalElements)
        performanceMonitor.recordElementFiltering()
        
        // Menu bar integration using CoordinateSystem extension
        let menuBarElements = coordinateSystem.convertMenuBarItemsToUIElements(detectionResults.menuItems)
        let allElements = filteredElements + menuBarElements
        
        performanceMonitor.recordFusion()
        
        // REMOVE THIS
        // Step 5: Browser Enhancement (Removed - requires dangerous permissions)
        print("\n🌐 BROWSER ENHANCEMENT")
        print("======================")
        print("🔍 Browser enhancement disabled for security")
        let enhancedElements = allElements
        
        // Step 6: Data Cleaning & Compression
        print("\n📊 DATA PROCESSING")
        print("==================")
        performanceMonitor.startCleaning()
        
        // Create complete UI map
        performanceMonitor.startMapCreation()
        let completeMap = CompleteUIMap(
            windowTitle: "activwndw: \(windowInfo.ownerName) - \(windowInfo.title)",
            windowFrame: windowInfo.frame,
            elements: enhancedElements,
            systemContext: detectionResults.menuBarContext,
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(overallStartTime),
            performance: CompleteUIMap.PerformanceMetrics(
                accessibilityTime: detectionResults.accessibilityTime,
                screenshotTime: performanceMonitor.getWindowCaptureTime(),
                ocrTime: detectionResults.ocrTime,
                fusionTime: performanceMonitor.fusionTime,
                totalElements: detectionResults.accessibilityElements.count + detectionResults.ocrElements.count,
                fusedElements: enhancedElements.count,
                memoryUsage: performanceMonitor.getMemoryUsage()
            ),
            summary: CompleteUIMap.UIMapSummary(from: enhancedElements)
        )
        performanceMonitor.recordMapCreation()
        
        // Generate outputs using services
        let jsonData = outputManager.toJSON(completeMap)
        let cleanedData = try! DataCleaningService.generateCleanedJSON(from: jsonData)
        let compressedFormat = try! CompressionService.generateCompressedFormat(from: cleanedData)
        
        performanceMonitor.recordCleaning()
        performanceMonitor.recordCompression()
        
        // Record final total time for performance analysis
        performanceMonitor.recordTotalTime()
        
        // Step 7: File Output
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: completeMap.timestamp)
        
        // Use FileManager as single source of truth for file operations
        let fileManager = UIInspectorFileManager()
        do {
            let filePaths = try fileManager.saveFiles(
                jsonData: jsonData,
                compressedFormat: compressedFormat,
                timestamp: timestamp
            )
            print("📄 Raw JSON saved: \(filePaths.rawPath)")
            print("✨ Cleaned JSON saved: \(filePaths.cleanedPath)")
            print("🗜️ Compressed output saved: \(filePaths.compressedPath)")
            
            // Save performance analysis to separate file
            let performanceAnalysis = performanceMonitor.generateDetailedReport()
            let performanceLogPath = "\(fileManager.getOutputDirectory())/latest_performance_logs.txt"
            try performanceAnalysis.write(to: URL(fileURLWithPath: performanceLogPath), atomically: false, encoding: .utf8)
            print("⚡ Performance analysis saved: \(performanceLogPath)")
            
        } catch {
            print("❌ Failed to save files: \(error)")
        }
        
        // Step 8: Results & Analysis
        print("\n📊 DETECTION SUMMARY")
        print("====================")
        let uiAnalyzer = UIElementAnalyzer()
        uiAnalyzer.printDetectionSummary(
            ocrOnlyCount: detectionResults.ocrElements.count,
            fusedCount: fusedElements.count,
            finalCount: enhancedElements.count,
            shapeCount: detectionResults.shapeElements.count
        )
        
        uiAnalyzer.printButtonSummary(elements: enhancedElements, shapeElements: detectionResults.shapeElements)
        
        // Performance reporting using PerformanceMonitor extension
        performanceMonitor.printSummary()
        print(performanceMonitor.generateDetailedReport())
        
        // Coordinate debugging
        if OutputConfig.printCoordinateDebugging {
            uiAnalyzer.printCoordinateDebugging(
                windowFrame: windowInfo.frame,
                accessibilityElements: validatedAccessibilityElements,
                ocrElements: correctedOCRElements,
                fusedElements: enhancedElements
            )
        }
        
        // Output JSON for GPT consumption
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("JSON_OUTPUT_START")
            print(jsonString)
            print("JSON_OUTPUT_END")
        }
        
        print("\n🚀 RESULTS:")
        print("===========")
        print("📱 Window: \(completeMap.windowTitle)")
        print("📏 Frame: \(completeMap.windowFrame)")
        print("🔢 Elements: \(completeMap.elements.count)")
        print("✅ Using clean architecture with service separation")
    }
    
}

// MARK: - Entry Point

@main
struct Main {
    static func main() {
        let app = UIInspectorApp()
        app.run()
    }
} 