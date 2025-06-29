import Foundation
import AppKit

/// Coordinates parallel execution of accessibility, OCR, and shape detection
class ParallelDetectionCoordinator {
    private let accessibilityEngine: AccessibilityEngine
    private let ocrEngine: OCREngine
    
    init() {
        self.accessibilityEngine = AccessibilityEngine()
        self.ocrEngine = OCREngine()
    }
    
    /// Execute accessibility, OCR, and shape detection in parallel
    func executeParallelDetection(
        screenshot: CGImage, 
        windowFrame: CGRect, 
        visualConfig: Bool, 
        debugEnabled: Bool
    ) -> DetectionResults {
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
        var menuBarContext: [String: Any] = [:]
        var menuItems: [[String: Any]] = []
        var accessibilityTime: TimeInterval = 0
        var ocrTime: TimeInterval = 0
        var shapeDetectionTime: TimeInterval = 0
        var menuBarTime: TimeInterval = 0
        
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
            // Convert CGImage to NSImage for OCR engine
            let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))
            let rawOCRElements = self.ocrEngine.extractText(from: nsImage, useAccurateMode: visualConfig)
            let filtered = self.ocrEngine.filterTextElements(rawOCRElements)
            let taskTime = Date().timeIntervalSince(taskStart)
            
            resultsQueue.async {
                filteredOCRElements = filtered
                ocrTime = taskTime
                print("🔤 OCR processing completed: \(filtered.count) elements (\(String(format: "%.3f", taskTime))s)")
                dispatchGroup.leave()
            }
        }
        
        // Parallel Task 3: Shape Detection (conditional based on configuration)
        if VisualConfig.detectShapes {
            dispatchGroup.enter()
            detectionQueue.async {
                let taskStart = Date()
                let elements = ShapeOrchestrator.detectShapes(
                    in: screenshot, 
                    windowFrame: windowFrame, 
                    visualConfig: visualConfig,
                    debug: debugEnabled
                )
                let taskTime = Date().timeIntervalSince(taskStart)
                
                resultsQueue.async {
                    shapeElements = elements
                    shapeDetectionTime = taskTime
                    print("🔍 Shape detection completed: \(elements.count) elements (\(String(format: "%.3f", taskTime))s)")
                    dispatchGroup.leave()
                }
            }
        } else {
            // Shape detection disabled - skip entirely
            print("🔍 Shape detection DISABLED by configuration")
            shapeElements = []
            shapeDetectionTime = 0.0
        }
        
        // Parallel Task 4: Menu Bar Detection
        dispatchGroup.enter()
        detectionQueue.async {
            let taskStart = Date()
            let context = MenuBarInspector.inspectMenuBar()
            let taskTime = Date().timeIntervalSince(taskStart)
            
            resultsQueue.async {
                menuBarContext = context
                if let items = context["menuItems"] as? [[String: Any]] {
                    menuItems = items
                }
                menuBarTime = taskTime
                print("🖥️ Menu bar inspection completed: \(menuItems.count) items (\(String(format: "%.3f", taskTime))s)")
                dispatchGroup.leave()
            }
        }
        
        // Wait for all parallel tasks to complete
        dispatchGroup.wait()
        
        let parallelTime = Date().timeIntervalSince(parallelStart)
        let sequentialTime = accessibilityTime + ocrTime + shapeDetectionTime + menuBarTime
        let speedup = sequentialTime / parallelTime
        
        print("⚡ Parallel detection completed in \(String(format: "%.3f", parallelTime))s")
        print("   └─ Speedup: \(String(format: "%.1f", speedup))x faster than sequential")
        
        return DetectionResults(
            accessibilityElements: accessibilityElements,
            ocrElements: filteredOCRElements,
            shapeElements: shapeElements,
            menuBarContext: menuBarContext,
            menuItems: menuItems,
            accessibilityTime: accessibilityTime,
            ocrTime: ocrTime,
            shapeDetectionTime: shapeDetectionTime,
            menuBarTime: menuBarTime
        )
    }
}

// MARK: - Detection Results

extension ParallelDetectionCoordinator {
    struct DetectionResults {
        let accessibilityElements: [AccessibilityData]
        let ocrElements: [OCRData]
        let shapeElements: [UIShapeCandidate]
        let menuBarContext: [String: Any]
        let menuItems: [[String: Any]]
        let accessibilityTime: TimeInterval
        let ocrTime: TimeInterval
        let shapeDetectionTime: TimeInterval
        let menuBarTime: TimeInterval
    }
} 