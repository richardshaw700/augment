import Foundation
import CoreGraphics

// MARK: - Performance Optimization and Caching

class PerformanceOptimization {
    
    // MARK: - Caching System
    
    private static var detectionCache: [String: [ClassifiedShape]] = [:]
    private static var performanceMetrics: [String: TimeInterval] = [:]
    private static let cacheExpirationTime: TimeInterval = 30.0 // 30 seconds
    private static var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Detection Caching
    
    static func getCachedDetection(for imageHash: String) -> [ClassifiedShape]? {
        // Check if cache entry exists and is still valid
        guard let shapes = detectionCache[imageHash],
              let timestamp = cacheTimestamps[imageHash],
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        return shapes
    }
    
    static func cacheDetection(_ shapes: [ClassifiedShape], for imageHash: String) {
        detectionCache[imageHash] = shapes
        cacheTimestamps[imageHash] = Date()
        
        // Clean old cache entries periodically
        cleanExpiredCacheEntries()
    }
    
    // MARK: - Performance Monitoring
    
    static func recordPerformanceMetric(_ operation: String, time: TimeInterval) {
        performanceMetrics[operation] = time
    }
    
    static func getPerformanceMetric(_ operation: String) -> TimeInterval? {
        return performanceMetrics[operation]
    }
    
    static func generatePerformanceReport() -> String {
        var report = "🔥 SHAPE DETECTION PERFORMANCE REPORT\n"
        report += "=====================================\n"
        
        for (operation, time) in performanceMetrics.sorted(by: { $0.value > $1.value }) {
            let timeString = String(format: "%.3f", time)
            report += "   \(operation): \(timeString)s\n"
        }
        
        // Cache statistics
        report += "\n📦 CACHE STATISTICS\n"
        report += "==================\n"
        report += "   Active entries: \(detectionCache.count)\n"
        report += "   Cache hit rate: \(calculateCacheHitRate())%\n"
        
        return report
    }
    
    // MARK: - Optimization Strategies
    
    // MARK: - Configurable Performance Thresholds
    
    struct PerformanceThresholds {
        static var maxPixelCount: Double = 2_000_000      // Configurable: max pixels for expensive detection
        static var maxElementCount: Int = 100             // Configurable: max elements before skipping expensive detection
        static var maxExpensiveDetectionTime: Double = 5.0 // Configurable: max time for expensive detection
        static var adaptiveThresholds: Bool = true        // Enable adaptive thresholds based on device performance
    }
    
    static func shouldUseExpensiveDetection(_ imageSize: CGSize, elementCount: Int) -> Bool {
        // Skip expensive detection for very large images or when many elements already found
        let pixelCount = imageSize.width * imageSize.height
        
        // Use configurable thresholds
        var currentMaxPixels = PerformanceThresholds.maxPixelCount
        var currentMaxElements = PerformanceThresholds.maxElementCount
        var currentMaxTime = PerformanceThresholds.maxExpensiveDetectionTime
        
        // Adaptive thresholds based on device performance
        if PerformanceThresholds.adaptiveThresholds {
            let memoryPressure = getMemoryPressure()
            if memoryPressure > 0.8 {
                currentMaxPixels *= 0.5  // Reduce threshold under memory pressure
                currentMaxElements = Int(Double(currentMaxElements) * 0.7)
                currentMaxTime *= 0.6
            }
        }
        
        // Don't use expensive detection if:
        // 1. Image is very large (configurable threshold)
        // 2. We already found many elements (configurable threshold)
        // 3. Performance metrics show it's too slow (configurable threshold)
        
        if Double(pixelCount) > currentMaxPixels {
            return false
        }
        
        if elementCount > currentMaxElements {
            return false
        }
        
        // Check if expensive detection historically takes too long
        if let expensiveTime = performanceMetrics["expensive_detection"],
           expensiveTime > currentMaxTime {
            return false
        }
        
        return true
    }
    
    static func optimizeContourDetection(_ contours: [ShapeContour]) -> [ShapeContour] {
        // Pre-filter contours to reduce processing time
        return contours.filter { contour in
            let bounds = contour.boundingBox
            let area = contour.area
            
            // Skip very small or very large contours
            guard area > 50 && area < 100000 else { return false }
            
            // Skip contours that are likely noise (very thin lines)
            guard bounds.width > 5 && bounds.height > 5 else { return false }
            
            // Skip extremely wide or tall contours (likely artifacts)
            let aspectRatio = contour.aspectRatio
            guard aspectRatio > 0.05 && aspectRatio < 20.0 else { return false }
            
            return true
        }
    }
    
    static func getOptimalDetectionStrategy(imageSize: CGSize, debugEnabled: Bool) -> DetectionStrategy {
        let pixelCount = imageSize.width * imageSize.height
        
        if debugEnabled {
            return .full // Always use full detection in debug mode
        }
        
        // Use configurable thresholds instead of hardcoded values
        let smallImageThreshold = PerformanceThresholds.maxPixelCount * 0.25  // 25% of max
        let mediumImageThreshold = PerformanceThresholds.maxPixelCount * 0.75 // 75% of max
        
        if Double(pixelCount) < smallImageThreshold {
            return .full // Small images can handle full detection
        } else if Double(pixelCount) < mediumImageThreshold {
            return .balanced // Medium images use balanced approach
        } else {
            return .fast // Large images use fast detection only
        }
    }
    
    // MARK: - Early Termination
    
    static func shouldTerminateEarly(shapesFound: Int, timeElapsed: TimeInterval) -> Bool {
        // Stop processing if we've found enough shapes or taken too long
        
        // If we found many shapes quickly, we can stop
        if shapesFound > 50 && timeElapsed < 1.0 {
            return true
        }
        
        // If we're taking too long, stop to prevent delays
        if timeElapsed > 10.0 {
            return true
        }
        
        // If we found reasonable number of shapes and taken moderate time
        if shapesFound > 30 && timeElapsed > 3.0 {
            return true
        }
        
        return false
    }
    
    // MARK: - Cache Management
    
    private static func cleanExpiredCacheEntries() {
        let now = Date()
        let expiredKeys = cacheTimestamps.compactMap { (key, timestamp) in
            now.timeIntervalSince(timestamp) > cacheExpirationTime ? key : nil
        }
        
        for key in expiredKeys {
            detectionCache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        }
    }
    
    private static func calculateCacheHitRate() -> Int {
        // This would need to be tracked with actual hit/miss counters
        // For now, return estimated based on cache size
        return min(75, detectionCache.count * 10)
    }
    
    // MARK: - Memory Pressure Detection
    
    private static func getMemoryPressure() -> Double {
        // Simple memory pressure estimation
        // In a real implementation, this would check system memory usage
        let memoryUsage = getMemoryUsage()
        
        // Estimate pressure based on memory usage (very rough approximation)
        if memoryUsage > 1_000_000_000 { // > 1GB
            return 0.9
        } else if memoryUsage > 500_000_000 { // > 500MB
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private static func getMemoryUsage() -> UInt64 {
        // Use the same memory usage calculation as PerformanceMonitor
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
    
    // MARK: - Image Hashing for Cache Keys
    
    static func generateImageHash(_ image: CGImage) -> String {
        // Generate a simple hash based on image properties
        // In production, you might want a more sophisticated hash
        let width = image.width
        let height = image.height
        let bitsPerComponent = image.bitsPerComponent
        let timestamp = Int(Date().timeIntervalSince1970 / 10) // 10-second buckets
        
        return "img_\(width)x\(height)_\(bitsPerComponent)_\(timestamp)"
    }
}

// MARK: - Detection Strategy Enum

enum DetectionStrategy {
    case fast       // Only basic contour detection
    case balanced   // Contour + some specialized detection
    case full      // All detection methods including expensive ones
}

// MARK: - Performance Monitoring Extension

extension PerformanceOptimization {
    
    static func measureTime<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        recordPerformanceMetric(operation, time: elapsedTime)
        return result
    }
    
    static func measureTimeAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await block()
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        recordPerformanceMetric(operation, time: elapsedTime)
        return result
    }
}