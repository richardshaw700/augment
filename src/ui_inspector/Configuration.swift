import Foundation

// MARK: - UI Inspector Configuration

/// Central configuration for the UI Inspector system
/// Contains all configurable parameters for debugging, performance, and visual detection

// MARK: - Debug Configuration
struct DebugConfig {
    /// Master debug flag - enables detailed logging throughout the system
    static let isEnabled = false  // Set to false for production logs
    
    /// Debug specific subsystems
    static let debugAccessibility = false
    static let debugOCR = false
    static let debugShapeDetection = false
    static let debugFusion = false
    static let debugPerformance = false
}

// MARK: - Visual Elements Configuration
struct VisualConfig {
    /// Master flag for rich visual element detection
    static let captureRichVisualElements = false  // Set to true to capture avatars, thumbnails, window controls, etc.
    
     /// Specific visual detection toggles
    static let detectShapes = captureRichVisualElements // turn off shape detection engine entirely
    static let detectWindowControls = captureRichVisualElements
    static let detectThumbnails = captureRichVisualElements
    static let detectEmojis = captureRichVisualElements
    // PERFORMANCE IMPACT: ~0.58s difference (0.735s fast vs 1.315s full)
    // ELEMENT COUNT: ~11 element difference (82 fast vs 93 full)
    
    // When ENABLED (true): 1.315s, 93 elements
    // • OCR MODE: Accurate OCR - perfect timestamp parsing ("11:32" vs "11.'32")
    // • VISUAL DETECTION: Full visual element detection including:
    //   - Window control buttons (red/yellow/green traffic lights)
    //   - Profile pictures/avatars (circular elements)  
    //   - Message bubble backgrounds (rounded rectangles)
    //   - Car listing thumbnails and image previews
    //   - Enhanced emoji and reaction detection
    //   - Status indicator regions (delivery status, timestamps)
    
    // When DISABLED (false): 0.735s, 82 elements  
    // • OCR MODE: Fast OCR - good coverage but some parsing errors ("11.'32" instead of "11:32")
    // • VISUAL DETECTION: Basic shape detection (window controls only)
    // • STILL CAPTURES: Most timestamps, status text, all functional UI text
    
   
}

// MARK: - Performance Configuration
struct PerformanceConfig {
    /// Parallel detection timeouts
    static let maxDetectionTime: TimeInterval = 10.0
    static let maxAccessibilityTime: TimeInterval = 3.0
    static let maxOCRTime: TimeInterval = 4.0
    static let maxShapeDetectionTime: TimeInterval = 5.0
    
    /// Memory management
    static let enableMemoryOptimization = true
    static let maxMemoryUsage: Int = 1_000_000_000 // 1GB
    
    /// Caching configuration
    static let enableCaching = true
    static let maxCacheSize = 10
    static let cacheTimeout: TimeInterval = 30.0
    static let cacheExpirationTime: TimeInterval = 30.0
    
    /// Window and app management
    static let defaultWindowTimeout: TimeInterval = 0.2  // Reduced from 2.0s for faster performance
    static let gridSweepPollingInterval: TimeInterval = 0.01  // 10ms for faster app setup
    
    /// Processing thresholds
    static let maxProcessingTime: TimeInterval = 5.0
    static let minElementConfidence: Double = 0.05  // Lowered to capture more UI elements
    static let minTextHeight: Double = 0.005  // Lower threshold for small UI text
    
    /// Early termination thresholds
    static let maxElementsBeforeTermination = 200
    static let minElementsForEarlySuccess = 50
    
    /// Feature flags
    static let enableGridSweep = true
    static let enablePerformanceMonitoring = true
    
    // LEGACY: Grid configuration removed - now using percentage coordinates
    // Previously: gridColumns = 40, gridRows = 50
}

// MARK: - Output Configuration
struct OutputConfig {
    /// File output settings
    static let generateRawOutput = true
    static let generateCleanedOutput = true
    static let generateCompressedOutput = true
    
    /// JSON formatting
    static let prettyPrintJSON = false
    static let includeDebugInfo = DebugConfig.isEnabled
    
    /// Console output
    static let printDetailedSummary = true
    static let printPerformanceMetrics = true
    static let printCoordinateDebugging = DebugConfig.isEnabled
}

// MARK: - Coordinate System Configuration
struct CoordinateConfig {
    /// Coordinate system preferences
    static let usePercentageCoordinates = true
    static let validateCoordinates = true
    static let correctOCRCoordinates = true
    
    /// Tolerance settings
    static let coordinateTolerance: CGFloat = 5.0
    static let overlapTolerance: CGFloat = 0.1
}

// MARK: - Configuration Validation
extension DebugConfig {
    static func validateConfiguration() {
        if isEnabled {
            print("🔧 Debug mode enabled - performance will be impacted")
        }
        
        if VisualConfig.captureRichVisualElements {
            print("🎨 Rich visual elements enabled - expect ~0.6s additional processing time")
        }
        
        if PerformanceConfig.maxDetectionTime < 5.0 {
            print("⚠️  Warning: Detection timeout may be too low for complex interfaces")
        }
    }
}