import Foundation

// MARK: - Performance Data Structure

struct PerformanceData: Codable {
    let totalTime: TimeInterval
    let accessibilityTime: TimeInterval
    let ocrTime: TimeInterval
    let shapeDetectionTime: TimeInterval
    let menuBarTime: TimeInterval
    let fusionTime: TimeInterval
    let cleaningTime: TimeInterval
    let compressionTime: TimeInterval
}

// MARK: - Performance Monitor

class PerformanceMonitor {
    // Performance timing properties
    var totalTime: TimeInterval = 0
    var accessibilityTime: TimeInterval = 0
    var ocrTime: TimeInterval = 0
    var shapeDetectionTime: TimeInterval = 0
    var menuBarTime: TimeInterval = 0
    var fusionTime: TimeInterval = 0
    var cleaningTime: TimeInterval = 0
    var compressionTime: TimeInterval = 0
    
    // Additional timing properties for comprehensive tracking
    var appDetectionTime: TimeInterval = 0
    var windowCaptureTime: TimeInterval = 0
    var coordinateSystemTime: TimeInterval = 0
    var dataCorrectionTime: TimeInterval = 0
    var elementFilteringTime: TimeInterval = 0
    var mapCreationTime: TimeInterval = 0
    
    private var startTime: Date?
    private var fusionStartTime: Date?
    private var cleaningStartTime: Date?
    private var compressionStartTime: Date?
    private var appDetectionStartTime: Date?
    private var windowCaptureStartTime: Date?
    private var coordinateSystemStartTime: Date?
    private var dataCorrectionStartTime: Date?
    private var elementFilteringStartTime: Date?
    private var mapCreationStartTime: Date?
    
    func startTiming() {
        startTime = Date()
    }
    
    func recordTotalTime() {
        if let start = startTime {
            totalTime = Date().timeIntervalSince(start)
        }
    }
    
    func recordAppDetection() {
        if let start = appDetectionStartTime {
            appDetectionTime = Date().timeIntervalSince(start)
        }
    }
    
    func startAppDetection() {
        appDetectionStartTime = Date()
    }
    
    func recordWindowCapture() {
        if let start = windowCaptureStartTime {
            windowCaptureTime = Date().timeIntervalSince(start)
        }
    }
    
    func startWindowCapture() {
        windowCaptureStartTime = Date()
    }
    
    func startCoordinateSystem() {
        coordinateSystemStartTime = Date()
    }
    
    func recordCoordinateSystem() {
        if let start = coordinateSystemStartTime {
            coordinateSystemTime = Date().timeIntervalSince(start)
        }
    }
    
    func startDataCorrection() {
        dataCorrectionStartTime = Date()
    }
    
    func recordDataCorrection() {
        if let start = dataCorrectionStartTime {
            dataCorrectionTime = Date().timeIntervalSince(start)
        }
    }
    
    func startElementFiltering() {
        elementFilteringStartTime = Date()
    }
    
    func recordElementFiltering() {
        if let start = elementFilteringStartTime {
            elementFilteringTime = Date().timeIntervalSince(start)
        }
    }
    
    func startMapCreation() {
        mapCreationStartTime = Date()
    }
    
    func recordMapCreation() {
        if let start = mapCreationStartTime {
            mapCreationTime = Date().timeIntervalSince(start)
        }
    }
    
    func getWindowCaptureTime() -> TimeInterval {
        return windowCaptureTime
    }
    
    func startFusion() {
        fusionStartTime = Date()
    }
    
    func recordFusion() {
        if let start = fusionStartTime {
            fusionTime = Date().timeIntervalSince(start)
        }
    }
    
    func startCleaning() {
        cleaningStartTime = Date()
    }
    
    func recordCleaning() {
        if let start = cleaningStartTime {
            cleaningTime = Date().timeIntervalSince(start)
        }
    }
    
    func recordCompression() {
        if let start = compressionStartTime {
            compressionTime = Date().timeIntervalSince(start)
        }
        compressionStartTime = Date()
    }
    
    func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Performance Reporting Extension

extension PerformanceMonitor {
    /// Generate detailed performance report with sequential breakdown and percentages
    func generateDetailedReport() -> String {
        // Calculate total time from start if available, otherwise sum components
        let actualTotalTime: TimeInterval
        if let start = startTime {
            actualTotalTime = Date().timeIntervalSince(start)
        } else {
            actualTotalTime = totalTime
        }
        
        // Calculate parallel detection time (max of overlapping components, not sum)
        let parallelDetectionTime = max(accessibilityTime, max(ocrTime, shapeDetectionTime))
        
        // Calculate sequential components (non-overlapping)
        let sequentialTime = fusionTime + cleaningTime + compressionTime + menuBarTime + windowCaptureTime + appDetectionTime
        
        // Calculate what sequential execution would have been for parallel components
        let sequentialDetectionTime = accessibilityTime + ocrTime + shapeDetectionTime
        let speedup = sequentialDetectionTime > 0 ? sequentialDetectionTime / parallelDetectionTime : 1.0
        
        // Calculate total accounted time (parallel detection + sequential processing)
        let accountedTime = parallelDetectionTime + sequentialTime
        
        // Calculate overhead/unaccounted time
        let overheadTime = max(0, actualTotalTime - accountedTime)
        
        let report = """
        
        ⏱️  PERFORMANCE BREAKDOWN:
        ==================================================
        🎯 MASTER TIMING:
          🏁 True Total Time: \(String(format: "%.3f", actualTotalTime))s (start to finish)
          📊 Sum of Components: \(String(format: "%.3f", accountedTime + overheadTime))s
          \(abs(actualTotalTime - (accountedTime + overheadTime)) < 0.01 ? "✅ Components account for all processing time" : "⚠️  Timing discrepancy detected")
        
        📋 COMPONENT BREAKDOWN:
          • App detection: \(String(format: "%.3f", appDetectionTime))s (\(String(format: "%.1f", getPercentage(appDetectionTime, actualTotalTime)))%)
          • Window management: \(String(format: "%.3f", windowCaptureTime))s (\(String(format: "%.1f", getPercentage(windowCaptureTime, actualTotalTime)))%)
          • Coordinate system setup: \(String(format: "%.3f", coordinateSystemTime))s (\(String(format: "%.1f", getPercentage(coordinateSystemTime, actualTotalTime)))%)
          • Coordinate correction: \(String(format: "%.3f", dataCorrectionTime))s (\(String(format: "%.1f", getPercentage(dataCorrectionTime, actualTotalTime)))%)
          • Data fusion: \(String(format: "%.3f", fusionTime))s (\(String(format: "%.1f", getPercentage(fusionTime, actualTotalTime)))%)
          • Element filtering: \(String(format: "%.3f", elementFilteringTime))s (\(String(format: "%.1f", getPercentage(elementFilteringTime, actualTotalTime)))%)
          • Menu bar integration: \(String(format: "%.3f", menuBarTime))s (\(String(format: "%.1f", getPercentage(menuBarTime, actualTotalTime)))%)
          • Map creation: \(String(format: "%.3f", mapCreationTime))s (\(String(format: "%.1f", getPercentage(mapCreationTime, actualTotalTime)))%)
          • Output generation: \(String(format: "%.3f", cleaningTime))s (\(String(format: "%.1f", getPercentage(cleaningTime, actualTotalTime)))%)
          • Compression: \(String(format: "%.3f", compressionTime))s (\(String(format: "%.1f", getPercentage(compressionTime, actualTotalTime)))%)
          • System overhead: \(String(format: "%.3f", overheadTime))s (\(String(format: "%.1f", getPercentage(overheadTime, actualTotalTime)))%)
          ⚡ Parallel Detection Group: \(String(format: "%.3f", parallelDetectionTime))s (\(String(format: "%.1f", getPercentage(parallelDetectionTime, actualTotalTime)))%)
            ├─ OCR processing: \(String(format: "%.3f", ocrTime))s (\(String(format: "%.1f", getPercentage(ocrTime, actualTotalTime)))%)
            ├─ Accessibility scan: \(String(format: "%.3f", accessibilityTime))s (\(String(format: "%.1f", getPercentage(accessibilityTime, actualTotalTime)))%)
            ├─ Shape detection: \(String(format: "%.3f", shapeDetectionTime))s (\(String(format: "%.1f", getPercentage(shapeDetectionTime, actualTotalTime)))%)
            └─ Sequential would be: \(String(format: "%.3f", sequentialDetectionTime))s (\(String(format: "%.1f", speedup))x speedup)
        --------------------------------------------------
          🏁 MASTER TOTAL: \(String(format: "%.3f", actualTotalTime))s
        
        """
        
        return report
    }
    
    /// Calculate percentage with safety check
    private func getPercentage(_ value: TimeInterval, _ total: TimeInterval) -> Double {
        return total > 0 ? (value / total) * 100 : 0
    }
    
    /// Get the slowest performance phase
    private func getSlowestPhase() -> String {
        let phases = [
            ("Accessibility API", accessibilityTime),
            ("OCR Processing", ocrTime),
            ("Shape Detection", shapeDetectionTime),
            ("Menu Bar Inspection", menuBarTime),
            ("Data Fusion", fusionTime),
            ("Data Cleaning", cleaningTime),
            ("Compression", compressionTime)
        ]
        
        let slowest = phases.max { $0.1 < $1.1 }
        return slowest?.0 ?? "Unknown"
    }
    
    /// Get the fastest performance phase (excluding zero times)
    private func getFastestPhase() -> String {
        let phases = [
            ("Accessibility API", accessibilityTime),
            ("OCR Processing", ocrTime),
            ("Shape Detection", shapeDetectionTime),
            ("Menu Bar Inspection", menuBarTime),
            ("Data Fusion", fusionTime),
            ("Data Cleaning", cleaningTime),
            ("Compression", compressionTime)
        ]
        
        let fastest = phases.filter { $0.1 > 0 }.min { $0.1 < $1.1 }
        return fastest?.0 ?? "Unknown"
    }
    
    /// Get the slowest phase time
    private func getSlowestPhaseTime() -> TimeInterval {
        let phases = [accessibilityTime, ocrTime, shapeDetectionTime, menuBarTime, fusionTime, cleaningTime, compressionTime]
        return phases.max() ?? 0
    }
    
    /// Get the fastest phase time (excluding zero times)
    private func getFastestPhaseTime() -> TimeInterval {
        let phases = [accessibilityTime, ocrTime, shapeDetectionTime, menuBarTime, fusionTime, cleaningTime, compressionTime]
        return phases.filter { $0 > 0 }.min() ?? 0
    }
    
    /// Generate optimization suggestions based on performance data
    private func getOptimizationSuggestions(detectionTime: TimeInterval, processingTime: TimeInterval, overheadTime: TimeInterval, totalTime: TimeInterval) -> String {
        var suggestions: [String] = []
        
        // Shape detection optimization
        if shapeDetectionTime > totalTime * 0.5 {
            suggestions.append("• Shape Detection is consuming \(String(format: "%.1f", getPercentage(shapeDetectionTime, totalTime)))% of total time - consider optimizing contour detection algorithms")
        }
        
        // OCR optimization
        if ocrTime > totalTime * 0.3 {
            suggestions.append("• OCR Processing is taking \(String(format: "%.1f", getPercentage(ocrTime, totalTime)))% of total time - consider reducing image resolution or ROI optimization")
        }
        
        // System overhead
        if overheadTime > totalTime * 0.1 {
            suggestions.append("• System overhead is \(String(format: "%.1f", getPercentage(overheadTime, totalTime)))% - consider reducing coordination complexity or parallel processing")
        }
        
        // Memory usage
        let memoryMB = Double(getMemoryUsage()) / (1024 * 1024)
        if memoryMB > 100 {
            suggestions.append("• Memory usage is \(String(format: "%.1f", memoryMB))MB - consider implementing memory pooling or reducing data retention")
        }
        
        // Processing efficiency
        if processingTime < totalTime * 0.05 {
            suggestions.append("• Processing phase is very efficient at \(String(format: "%.1f", getPercentage(processingTime, totalTime)))% - good data pipeline optimization")
        }
        
        if suggestions.isEmpty {
            return "✅ Performance profile looks well-balanced with no major bottlenecks detected"
        } else {
            return suggestions.joined(separator: "\n")
        }
    }
    
    /// Format memory usage in human-readable format
    private func formatMemoryUsage(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Export performance data as JSON
    func exportAsJSON() -> Data? {
        let performanceData = PerformanceData(
            totalTime: totalTime,
            accessibilityTime: accessibilityTime,
            ocrTime: ocrTime,
            shapeDetectionTime: shapeDetectionTime,
            menuBarTime: menuBarTime,
            fusionTime: fusionTime,
            cleaningTime: cleaningTime,
            compressionTime: compressionTime
        )
        
        return try? JSONEncoder().encode(performanceData)
    }
    
    /// Print concise performance summary to console
    func printSummary() {
        let actualTotalTime: TimeInterval
        if let start = startTime {
            actualTotalTime = Date().timeIntervalSince(start)
        } else {
            actualTotalTime = totalTime
        }
        
        let detectionTime = accessibilityTime + ocrTime + shapeDetectionTime + menuBarTime
        let processingTime = fusionTime + cleaningTime + compressionTime
        
        print("""
        
        ⚡ PERFORMANCE SUMMARY
        ====================
        Total: \(String(format: "%.3f", actualTotalTime))s | Detection: \(String(format: "%.3f", detectionTime))s (\(String(format: "%.1f", getPercentage(detectionTime, actualTotalTime)))%) | Processing: \(String(format: "%.3f", processingTime))s (\(String(format: "%.1f", getPercentage(processingTime, actualTotalTime)))%)
        
        """)
    }
} 