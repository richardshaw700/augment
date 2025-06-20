import Foundation
import Vision
import AppKit
import ApplicationServices

// MARK: - Core Data Models

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
            self.confidence = elements.isEmpty ? 0.0 : elements.reduce(0) { $0 + $1.confidence } / Double(elements.count)
        }
    }
}

// MARK: - Window & Context Models

struct WindowContext {
    let windowFrame: CGRect
    let windowTitle: String
    let appName: String
    let timestamp: Date
    
    var windowSize: CGSize {
        return windowFrame.size
    }
    
    var aspectRatio: Double {
        return Double(windowFrame.width / windowFrame.height)
    }
}

struct WindowInfo {
    let title: String
    let frame: CGRect
    let ownerName: String
    let windowID: CGWindowID
    let layer: Int
}

// MARK: - Grid System Models

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
        return Int(column.asciiValue! - Character("A").asciiValue!)
    }
    
    var rowIndex: Int {
        return row - 1
    }
    
    var normalizedX: Double {
        return Double(columnIndex) / Double(UniversalGrid.COLUMNS - 1)
    }
    
    var normalizedY: Double {
        return Double(rowIndex) / Double(UniversalGrid.ROWS - 1)
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
    
    private static func compressElementName(_ element: UIElement) -> String {
        // Compress element names for UI representation
        if let text = element.visualText, !text.isEmpty {
            return String(text.prefix(8))
        } else if let accData = element.accessibilityData {
            return accData.role.replacingOccurrences(of: "AX", with: "")
        } else {
            return element.type
        }
    }
}

struct GridCollision {
    let elements: [GridMappedElement]
    let gridPosition: AdaptiveGridPosition
    let severity: CollisionSeverity
    let totalImportance: Int
}

enum CollisionSeverity: Int, CaseIterable {
    case low = 1      // 2-3 elements
    case medium = 2   // 4-6 elements  
    case high = 3     // 7+ elements
    case critical = 4 // 10+ elements
}

enum ResolutionStrategy {
    case keepHighestImportance
    case distributeAdjacent
    case mergeSimilar
}

// MARK: - Compression Models

struct AdaptiveCompressedUI {
    let format: String
    let tokenCount: Int
    let compressionRatio: Double
    let regionBreakdown: [String: Int]
    let confidence: Double
    
    var isHighQuality: Bool {
        return confidence > 0.8 && tokenCount < 100
    }
    
    var estimatedCost: Double {
        return Double(tokenCount) * 0.0001 // Rough token cost estimate
    }
}

struct GridPosition {
    let column: Character
    let row: Int
    
    init(column: Character, row: Int) {
        self.column = column
        self.row = row
    }
    
    var description: String {
        return "\(column)\(row)"
    }
    
    static func fromPixel(_ point: CGPoint, screenWidth: CGFloat = 1000, screenHeight: CGFloat = 720) -> GridPosition {
        let colIndex = min(7, max(0, Int(point.x / screenWidth * 8)))
        let colChar = Character(UnicodeScalar(65 + colIndex)!)
        let row = min(max(Int(point.y / screenHeight * 8) + 1, 1), 8)
        return GridPosition(column: colChar, row: min(max(row, 1), 8))
    }
}

struct CompressedElement {
    let name: String
    let grid: GridPosition
    let interactions: [String]
    let confidence: Double
}

struct CompressedUI {
    let format: String
    let elements: [CompressedElement]
    let totalElements: Int
    let compressionRatio: Double
    let tokenCount: Int
}

// MARK: - Coordinate System Models

struct NormalizedPoint {
    let x: Double  // 0.0 to 1.0
    let y: Double  // 0.0 to 1.0
    
    init(_ x: Double, _ y: Double) {
        self.x = max(0.0, min(1.0, x))
        self.y = max(0.0, min(1.0, y))
    }
    
    func toPixel(in frame: CGRect) -> CGPoint {
        return CGPoint(
            x: frame.origin.x + CGFloat(x) * frame.width,
            y: frame.origin.y + CGFloat(y) * frame.height
        )
    }
}

// MARK: - Protocol Definitions

protocol WindowDetecting {
    func getActiveWindow() -> WindowInfo?
    func captureWindow(_ window: WindowInfo) -> NSImage?
}

protocol CoordinateMapping {
    func normalize(_ point: CGPoint) -> NormalizedPoint
    func toGrid(_ point: NormalizedPoint) -> AdaptiveGridPosition
}

protocol AccessibilityScanning {
    func scanElements() -> [AccessibilityData]
}

protocol TextRecognition {
    func extractText(from image: NSImage) -> [OCRData]
}

protocol DataFusion {
    func fuse(accessibility: [AccessibilityData], 
              ocr: [OCRData], 
              coordinates: CoordinateMapping) -> [UIElement]
}

protocol GridMapping {
    func mapToGrid(_ elements: [UIElement]) -> [GridMappedElement]
}

protocol UICompression {
    func compress(_ elements: [GridMappedElement]) -> AdaptiveCompressedUI
}

protocol OutputFormatting {
    func toJSON(_ data: CompleteUIMap) -> Data
    func toCompressed(_ data: CompleteUIMap) -> String
}

// MARK: - Configuration

struct Config {
    static let maxCacheSize = 10
    static let cacheTimeout: TimeInterval = 30.0
    static let defaultWindowTimeout: TimeInterval = 2.0
    static let gridSweepPollingInterval: TimeInterval = 0.05
    
    // Grid configuration
    static let gridColumns = 26
    static let gridRows = 30
    
    // Performance thresholds
    static let maxProcessingTime: TimeInterval = 5.0
    static let minElementConfidence: Double = 0.3
    
    // Feature flags
    static let enableCaching = true
    static let enableGridSweep = true
    static let enablePerformanceMonitoring = true
} import Foundation
import AppKit
import ApplicationServices

// MARK: - Window Manager

class WindowManager: WindowDetecting {
    private static var cachedImage: NSImage?
    private static var lastCacheTime: Date?
    private static let cacheTimeout: TimeInterval = 0.5 // 500ms cache
    
    func getActiveWindow() -> WindowInfo? {
        return getFinderWindow()
    }
    
    func captureWindow(_ window: WindowInfo) -> NSImage? {
        return captureWindowBounds(window.frame)
    }
    
    // MARK: - Window Detection
    
    private func getFinderWindow() -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find the frontmost Finder window
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowBounds = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
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
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            let title = window[kCGWindowName as String] as? String ?? "Finder"
            
            return WindowInfo(
                title: title,
                frame: frame,
                ownerName: ownerName,
                windowID: windowID,
                layer: layer
            )
        }
        
        return nil
    }
    
    // MARK: - Screenshot Capture
    
    private func captureWindowBounds(_ windowFrame: CGRect) -> NSImage? {
        // Check cache first for performance
        let now = Date()
        if let cachedImage = Self.cachedImage,
           let lastCache = Self.lastCacheTime,
           now.timeIntervalSince(lastCache) < Self.cacheTimeout {
            return cachedImage
        }
        
        print("📐 Capturing window bounds: \(windowFrame)")
        
        // Capture only the window region using screencapture with -R flag
        let tempPath = "/tmp/ui_window_\(Int(Date().timeIntervalSince1970)).png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // -R x,y,w,h captures specific region
        let x = Int(windowFrame.origin.x)
        let y = Int(windowFrame.origin.y)  
        let w = Int(windowFrame.size.width)
        let h = Int(windowFrame.size.height)
        
        task.arguments = ["-x", "-t", "png", "-R", "\(x),\(y),\(w),\(h)", tempPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                // Cache for immediate reuse
                Self.cachedImage = image
                Self.lastCacheTime = now
                
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
        return captureFullScreen()
    }
    
    private func captureFullScreen() -> NSImage? {
        // PERFORMANCE: Try direct capture first, fallback to temp file
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
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
    
    // MARK: - App Management
    
    func ensureFinderWindow() {
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
        waitForAppWindow(bundleIdentifier: bundleID, appName: appName, maxWait: Config.defaultWindowTimeout)
    }
    
    private func waitForAppWindow(bundleIdentifier: String, appName: String, maxWait: TimeInterval) {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWait {
            if hasAppWindows(bundleIdentifier: bundleIdentifier) {
                let actualWait = Date().timeIntervalSince(startTime)
                print("⚡ \(appName) window ready in \(String(format: "%.3f", actualWait))s")
                return
            }
            Thread.sleep(forTimeInterval: Config.gridSweepPollingInterval) // Poll every 50ms
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
} import Foundation
import AppKit

// MARK: - Coordinate System

class CoordinateSystem: CoordinateMapping {
    private let windowFrame: CGRect
    private let gridMapper: AdaptiveDensityMapper
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
        self.gridMapper = AdaptiveDensityMapper(windowFrame: windowFrame)
    }
    
    // MARK: - Coordinate Normalization
    
    func normalize(_ point: CGPoint) -> NormalizedPoint {
        // Convert absolute screen coordinates to window-relative coordinates
        let relativeX = point.x - windowFrame.origin.x
        let relativeY = point.y - windowFrame.origin.y
        
        // Normalize to 0.0-1.0 range within the window bounds
        let normalizedX = Double(relativeX / windowFrame.width)
        let normalizedY = Double(relativeY / windowFrame.height)
        
        return NormalizedPoint(normalizedX, normalizedY)
    }
    
    func toGrid(_ point: NormalizedPoint) -> AdaptiveGridPosition {
        // Convert normalized coordinates to grid position
        let colIndex = min(25, max(0, Int(point.x * Double(UniversalGrid.COLUMNS))))
        let rowIndex = min(29, max(0, Int(point.y * Double(UniversalGrid.ROWS))))
        
        let column = Character(UnicodeScalar(65 + colIndex)!)
        let row = rowIndex + 1
        
        return AdaptiveGridPosition(column, row)
    }
    
    // MARK: - Grid Mapping
    
    func gridPosition(for point: CGPoint) -> AdaptiveGridPosition {
        let normalized = normalize(point)
        return toGrid(normalized)
    }
    
    func pixelPosition(for gridPos: AdaptiveGridPosition) -> CGPoint {
        let x = windowFrame.origin.x + (CGFloat(gridPos.columnIndex) * gridMapper.cellWidth) + (gridMapper.cellWidth / 2)
        let y = windowFrame.origin.y + (CGFloat(gridPos.rowIndex) * gridMapper.cellHeight) + (gridMapper.cellHeight / 2)
        
        return CGPoint(x: x, y: y)
    }
    
    func cellBounds(for gridPos: AdaptiveGridPosition) -> CGRect {
        let x = windowFrame.origin.x + (CGFloat(gridPos.columnIndex) * gridMapper.cellWidth)
        let y = windowFrame.origin.y + (CGFloat(gridPos.rowIndex) * gridMapper.cellHeight)
        
        return CGRect(x: x, y: y, width: gridMapper.cellWidth, height: gridMapper.cellHeight)
    }
    
    // MARK: - Region Classification
    
    func classifyRegion(for position: AdaptiveGridPosition) -> GridRegion {
        for region in GridRegion.allCases {
            if region.contains(position: position) {
                return region
            }
        }
        return .main // Default fallback
    }
    
    func classifyRegion(for point: CGPoint) -> GridRegion {
        let gridPos = gridPosition(for: point)
        return classifyRegion(for: gridPos)
    }
    
    // MARK: - Coordinate Validation
    
    func isValidCoordinate(_ point: CGPoint) -> Bool {
        return point.x >= windowFrame.minX &&
               point.x <= windowFrame.maxX &&
               point.y >= windowFrame.minY &&
               point.y <= windowFrame.maxY
    }
    
    func clampToWindow(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: max(windowFrame.minX, min(windowFrame.maxX, point.x)),
            y: max(windowFrame.minY, min(windowFrame.maxY, point.y))
        )
    }
    
    // MARK: - OCR Coordinate Correction
    
    func correctOCRCoordinates(_ ocrData: OCRData) -> OCRData {
        // OCR bounding box is in normalized coordinates (0.0-1.0)
        // Convert to absolute window coordinates
        let bbox = ocrData.boundingBox
        
        let absoluteX = windowFrame.origin.x + (bbox.origin.x * windowFrame.width)
        let absoluteY = windowFrame.origin.y + (bbox.origin.y * windowFrame.height)
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
    
    // MARK: - Accessibility Coordinate Validation
    
    func validateAccessibilityCoordinates(_ accData: AccessibilityData) -> AccessibilityData {
        guard let position = accData.position else { return accData }
        
        // Ensure accessibility coordinates are within window bounds
        let validatedPosition = clampToWindow(position)
        
        return AccessibilityData(
            role: accData.role,
            description: accData.description,
            title: accData.title,
            help: accData.help,
            enabled: accData.enabled,
            focused: accData.focused,
            position: validatedPosition,
            size: accData.size,
            element: accData.element,
            subrole: accData.subrole,
            value: accData.value,
            selected: accData.selected,
            parent: accData.parent,
            children: accData.children
        )
    }
    
    // MARK: - Spatial Correlation
    
    func spatialDistance(between point1: CGPoint, and point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    func isNearby(_ point1: CGPoint, _ point2: CGPoint, threshold: Double = 50.0) -> Bool {
        return spatialDistance(between: point1, and: point2) < threshold
    }
    
    // MARK: - Debug Information
    
    func debugCoordinateInfo(for point: CGPoint) -> [String: Any] {
        let normalized = normalize(point)
        let gridPos = gridPosition(for: point)
        let region = classifyRegion(for: point)
        
        return [
            "absolute": ["x": point.x, "y": point.y],
            "normalized": ["x": normalized.x, "y": normalized.y],
            "grid": gridPos.description,
            "region": region.rawValue,
            "windowFrame": [
                "x": windowFrame.origin.x,
                "y": windowFrame.origin.y,
                "width": windowFrame.width,
                "height": windowFrame.height
            ]
        ]
    }
}

// MARK: - Adaptive Density Mapper

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
} import Foundation
import AppKit
import ApplicationServices

// MARK: - Accessibility Engine

class AccessibilityEngine: AccessibilityScanning {
    private static var cachedWindowData: [String: Any] = [:]
    private static var lastCacheTime: Date?
    
    func scanElements() -> [AccessibilityData] {
        guard let (windowData, accessibilityElements) = getAccessibilityData() else {
            print("❌ Failed to get accessibility data")
            return []
        }
        
        print("🔧 Found \(accessibilityElements.count) accessibility elements")
        return accessibilityElements
    }
    
    // MARK: - Accessibility Data Collection
    
    private func getAccessibilityData() -> ([String: Any], [AccessibilityData])? {
        // Check cache first
        let now = Date()
        if let cachedData = Self.cachedWindowData,
           let lastCache = Self.lastCacheTime,
           now.timeIntervalSince(lastCache) < Config.cacheTimeout,
           !cachedData.isEmpty {
            
            let elements = cachedData["elements"] as? [AccessibilityData] ?? []
            var windowData = cachedData
            windowData.removeValue(forKey: "elements")
            return (windowData, elements)
        }
        
        // Get the frontmost window
        guard let app = NSWorkspace.shared.frontmostApplication else {
            print("❌ No frontmost application")
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Get the frontmost window
        guard let frontmostWindow = getFrontmostWindow(from: appElement) else {
            print("❌ No frontmost window found")
            return nil
        }
        
        // Extract window data
        var windowData: [String: Any] = [:]
        if let firstWindow = frontmostWindow.first {
            windowData = extractWindowData(firstWindow)
        } else {
            // Fallback window data
            windowData = createFallbackWindowData()
        }
        
        // Extract accessibility elements
        let accessibilityElements = frontmostWindow.flatMap { extractAccessibilityElements(from: $0) }
        
        // Cache the results
        var cacheData = windowData
        cacheData["elements"] = accessibilityElements
        Self.cachedWindowData = cacheData
        Self.lastCacheTime = now
        
        return (windowData, accessibilityElements)
    }
    
    private func getFrontmostWindow(from appElement: AXUIElement) -> [AXUIElement]? {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else {
            return nil
        }
        
        // Filter for main windows (exclude utility windows, dialogs, etc.)
        let mainWindows = windows.filter { window in
            var subroleRef: CFTypeRef?
            let subroleResult = AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
            
            if subroleResult == .success,
               let subrole = subroleRef as? String {
                // Include standard windows, exclude utility windows and dialogs
                return subrole == kAXStandardWindowSubrole
            }
            
            // If no subrole, assume it's a main window
            return true
        }
        
        return mainWindows.isEmpty ? [windows.first!] : mainWindows
    }
    
    private func extractWindowData(_ window: AXUIElement) -> [String: Any] {
        var windowData: [String: Any] = [:]
        
        // Extract window title
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String {
            windowData["title"] = title
        }
        
        // Extract window position and size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
                 if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
            let positionValue = positionRef {
             var position = CGPoint.zero
             if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) {
                 windowData["position"] = ["x": Double(position.x), "y": Double(position.y)]
             }
         }
         
         if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let sizeValue = sizeRef {
             var size = CGSize.zero
             if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                 windowData["size"] = ["width": Double(size.width), "height": Double(size.height)]
             }
         }
        
        return windowData
    }
    
    private func createFallbackWindowData() -> [String: Any] {
        return [
            "title": "Unknown Window",
            "position": ["x": 0.0, "y": 0.0],
            "size": ["width": 800.0, "height": 600.0]
        ]
    }
    
    // MARK: - Element Extraction
    
    private func extractAccessibilityElements(from window: AXUIElement) -> [AccessibilityData] {
        var allElements: [AccessibilityData] = []
        var processedElements: Set<String> = []
        
        // Recursively traverse the accessibility tree
        traverseAccessibilityTree(
            element: window,
            allElements: &allElements,
            processedElements: &processedElements,
            depth: 0,
            maxDepth: 10
        )
        
        return allElements
    }
    
    private func traverseAccessibilityTree(
        element: AXUIElement,
        allElements: inout [AccessibilityData],
        processedElements: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) {
        // Prevent infinite recursion
        guard depth < maxDepth else { return }
        
        // Create element identifier to prevent duplicates
        let elementPtr = Unmanaged.passUnretained(element).toOpaque()
        let elementId = String(describing: elementPtr)
        
        guard !processedElements.contains(elementId) else { return }
        processedElements.insert(elementId)
        
        // Extract data from current element
        if let accessibilityData = createAccessibilityData(from: element) {
            allElements.append(accessibilityData)
        }
        
        // Get children and recurse
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                traverseAccessibilityTree(
                    element: child,
                    allElements: &allElements,
                    processedElements: &processedElements,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
            }
        }
    }
    
    private func createAccessibilityData(from element: AXUIElement) -> AccessibilityData? {
        // Extract role (required)
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            return nil
        }
        
        // Extract optional attributes
        let description = getStringAttribute(element, kAXDescriptionAttribute)
        let title = getStringAttribute(element, kAXTitleAttribute)
        let help = getStringAttribute(element, kAXHelpAttribute)
        let subrole = getStringAttribute(element, kAXSubroleAttribute)
        let value = getStringAttribute(element, kAXValueAttribute)
        
        // Extract boolean attributes
        let enabled = getBoolAttribute(element, kAXEnabledAttribute) ?? true
        let focused = getBoolAttribute(element, kAXFocusedAttribute) ?? false
        let selected = getBoolAttribute(element, kAXSelectedAttribute) ?? false
        
        // Extract position and size
        let position = getPositionAttribute(element)
        let size = getSizeAttribute(element)
        
        // Extract parent and children info
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
    
    // MARK: - Attribute Extraction Helpers
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
              let value = valueRef as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
    
    private func getBoolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
              let value = valueRef as? Bool else {
            return nil
        }
        return value
    }
    
    private func getPositionAttribute(_ element: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef else {
            return nil
        }
        
        var position = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
            return nil
        }
        
        return position
    }
    
    private func getSizeAttribute(_ element: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sizeValue = sizeRef else {
            return nil
        }
        
        var size = CGSize.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        
        return size
    }
    
    private func getParentInfo(_ element: AXUIElement) -> String? {
        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
              let parent = parentRef as? AXUIElement else {
            return nil
        }
        
        // Get parent role for identification
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            return "Unknown Parent"
        }
        
        return role
    }
    
    private func getChildrenInfo(_ element: AXUIElement) -> [String] {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return []
        }
        
        return children.compactMap { child in
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success,
                  let role = roleRef as? String else {
                return nil
            }
            return role
        }
    }
} import Foundation
import Vision
import AppKit

// MARK: - OCR Engine

class OCREngine: TextRecognition {
    func extractText(from image: NSImage) -> [OCRData] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to get CGImage from NSImage")
            return []
        }
        
        return performOCR(on: cgImage)
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on cgImage: CGImage) -> [OCRData] {
        var ocrResults: [OCRData] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create OCR request
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("❌ OCR Error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ No OCR observations found")
                return
            }
            
            ocrResults = self?.processOCRObservations(observations) ?? []
        }
        
        // Configure OCR request for optimal performance
        configureOCRRequest(request)
        
        // Perform OCR
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
        } catch {
            print("❌ Failed to perform OCR: \(error)")
        }
        
        print("🔤 OCR extracted \(ocrResults.count) text elements")
        return ocrResults
    }
    
    private func configureOCRRequest(_ request: VNRecognizeTextRequest) {
        // Optimize for speed while maintaining accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01 // Detect small text
        
        // Set supported languages (English primarily, with fallbacks)
        request.recognitionLanguages = ["en-US", "en-GB"]
        
        // Enable automatic language detection
        request.automaticallyDetectsLanguage = true
    }
    
    private func processOCRObservations(_ observations: [VNRecognizedTextObservation]) -> [OCRData] {
        var ocrElements: [OCRData] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Filter out low-confidence or empty text
            guard confidence > Config.minElementConfidence,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            // Create OCR data with normalized bounding box
            let ocrData = OCRData(
                text: text,
                confidence: confidence,
                boundingBox: observation.boundingBox
            )
            
            ocrElements.append(ocrData)
        }
        
        return ocrElements
    }
    
    // MARK: - Text Processing
    
    func preprocessImage(_ image: NSImage) -> NSImage? {
        // Optional: Apply image preprocessing for better OCR results
        // This could include contrast enhancement, noise reduction, etc.
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // For now, return the original image
        // Future enhancements could include:
        // - Contrast adjustment
        // - Noise reduction
        // - Sharpening
        // - Binarization
        
        return image
    }
    
    func filterTextElements(_ elements: [OCRData]) -> [OCRData] {
        return elements.filter { element in
            let text = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Filter out very short text (likely noise)
            guard text.count > 1 else { return false }
            
            // Filter out purely numeric strings (often noise)
            guard !text.allSatisfy({ $0.isNumber }) else { return false }
            
            // Filter out strings with only special characters
            guard text.contains(where: { $0.isLetter }) else { return false }
            
            // Filter out very low confidence text
            guard element.confidence > Config.minElementConfidence else { return false }
            
            return true
        }
    }
    
    // MARK: - Coordinate Helpers
    
    func convertBoundingBox(_ boundingBox: CGRect, to windowFrame: CGRect) -> CGRect {
        // Convert Vision's normalized coordinates (0,0 at bottom-left)
        // to AppKit coordinates (0,0 at top-left) within the window frame
        
        let x = windowFrame.origin.x + (boundingBox.origin.x * windowFrame.width)
        let y = windowFrame.origin.y + ((1.0 - boundingBox.origin.y - boundingBox.height) * windowFrame.height)
        let width = boundingBox.width * windowFrame.width
        let height = boundingBox.height * windowFrame.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
} import Foundation
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
        if let accData = accData, let ocrData = ocrData {
            return "\(accData.role)+OCR"
        } else if let accData = accData {
            return accData.role
        } else if let ocrData = ocrData {
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
} import Foundation
import AppKit

// MARK: - Grid Sweep Mapper

class GridSweepMapper: GridMapping {
    private let windowFrame: CGRect
    private let coordinateSystem: CoordinateSystem
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
        self.coordinateSystem = CoordinateSystem(windowFrame: windowFrame)
    }
    
    func mapToGrid(_ elements: [UIElement]) -> [GridMappedElement] {
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
            let gridElement = GridMappedElement(
                originalElement: element,
                gridPosition: gridPos,
                mappingConfidence: calculateMappingConfidence(element, gridPos: gridPos),
                importance: calculateElementImportance(element)
            )
            
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
        
        let result = Array(uniqueElements.values).sorted { $0.importance > $1.importance }
        print("🗂️ Grid mapping complete: \(result.count) unique elements")
        return result
    }
    
    private func findBestElementForCell(_ gridPos: AdaptiveGridPosition, elements: [UIElement]) -> UIElement? {
        let cellBounds = coordinateSystem.cellBounds(for: gridPos)
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
        if let role = element.accessibilityData?.role {
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
            
            // Navigation keywords bonus
            let navWords = ["downloads", "applications", "documents", "desktop", "airdrop", 
                           "recents", "favorites", "network", "macintosh", "icloud", "shared"]
            let lowercaseText = text.lowercased()
            if navWords.contains(where: { lowercaseText.contains($0) }) {
                importance += 25 // Highest priority for navigation items
            }
        }
        
        return importance
    }
    
    private func calculateMappingConfidence(_ element: UIElement, gridPos: AdaptiveGridPosition) -> Double {
        let cellBounds = coordinateSystem.cellBounds(for: gridPos)
        let elementBounds = CGRect(origin: element.position, size: element.size)
        
        let intersection = cellBounds.intersection(elementBounds)
        let intersectionArea = intersection.width * intersection.height
        let elementArea = elementBounds.width * elementBounds.height
        
        if elementArea == 0 { return 0.5 }
        
        let overlapRatio = intersectionArea / elementArea
        return min(1.0, max(0.0, overlapRatio))
    }
    
    private func isMoreCentralPosition(_ pos1: AdaptiveGridPosition, vs pos2: AdaptiveGridPosition) -> Bool {
        let center = AdaptiveGridPosition("M", 15) // Middle of 26x30 grid
        
        let dist1 = abs(pos1.columnIndex - center.columnIndex) + abs(pos1.rowIndex - center.rowIndex)
        let dist2 = abs(pos2.columnIndex - center.columnIndex) + abs(pos2.rowIndex - center.rowIndex)
        
        return dist1 < dist2
    }
} import Foundation

// MARK: - Compression Engine

class CompressionEngine: UICompression {
    func compress(_ elements: [GridMappedElement]) -> AdaptiveCompressedUI {
        let regionGroups = groupByRegions(elements)
        let compressed = generateCompressedRepresentation(regionGroups)
        
        return AdaptiveCompressedUI(
            format: compressed,
            tokenCount: compressed.split(separator: ",").count,
            compressionRatio: calculateCompressionRatio(elements.count, compressed.count),
            regionBreakdown: calculateRegionBreakdown(regionGroups),
            confidence: calculateConfidence(elements)
        )
    }
    
    private func groupByRegions(_ elements: [GridMappedElement]) -> [GridRegion: [GridMappedElement]] {
        var groups: [GridRegion: [GridMappedElement]] = [:]
        
        for element in elements {
            for region in GridRegion.allCases {
                if region.contains(position: element.gridPosition) {
                    groups[region, default: []].append(element)
                    break
                }
            }
        }
        
        return groups
    }
    
    private func generateCompressedRepresentation(_ regionGroups: [GridRegion: [GridMappedElement]]) -> String {
        var parts: [String] = []
        
        // Add clickable elements first
        let clickableElements = regionGroups.values.flatMap { $0 }.filter { $0.originalElement.isClickable }
        if !clickableElements.isEmpty {
            let clickableStrings = clickableElements.map { "click:\($0.compressedRepresentation)" }
            parts.append(clickableStrings.joined(separator: ","))
        }
        
        // Add other elements by region
        for region in GridRegion.allCases {
            if let elements = regionGroups[region], !elements.isEmpty {
                let nonClickable = elements.filter { !$0.originalElement.isClickable }
                if !nonClickable.isEmpty {
                    let elementStrings = nonClickable.map { $0.compressedRepresentation }
                    parts.append(elementStrings.joined(separator: ","))
                }
            }
        }
        
        return parts.joined(separator: ",")
    }
    
    private func calculateCompressionRatio(_ elementCount: Int, _ compressedLength: Int) -> Double {
        guard compressedLength > 0 else { return 1.0 }
        return Double(elementCount * 100) / Double(compressedLength) // Rough estimate
    }
    
    private func calculateRegionBreakdown(_ regionGroups: [GridRegion: [GridMappedElement]]) -> [String: Int] {
        var breakdown: [String: Int] = [:]
        for (region, elements) in regionGroups {
            breakdown[region.rawValue] = elements.count
        }
        return breakdown
    }
    
    private func calculateConfidence(_ elements: [GridMappedElement]) -> Double {
        guard !elements.isEmpty else { return 0.0 }
        return elements.reduce(0) { $0 + $1.originalElement.confidence } / Double(elements.count)
    }
} import Foundation

// MARK: - Output Manager

class OutputManager: OutputFormatting {
    func toJSON(_ data: CompleteUIMap) -> Data {
        var jsonDict: [String: Any] = [:]
        
        // Window information
        jsonDict["window"] = [
            "title": data.windowTitle,
            "frame": [
                "x": data.windowFrame.origin.x,
                "y": data.windowFrame.origin.y,
                "width": data.windowFrame.width,
                "height": data.windowFrame.height
            ]
        ]
        
        // Elements
        jsonDict["elements"] = data.elements.map { element in
            var elementDict: [String: Any] = [
                "id": element.id,
                "type": element.type,
                "position": ["x": element.position.x, "y": element.position.y],
                "size": ["width": element.size.width, "height": element.size.height],
                "isClickable": element.isClickable,
                "confidence": element.confidence,
                "semanticMeaning": element.semanticMeaning
            ]
            
            if let visualText = element.visualText {
                elementDict["visualText"] = visualText
            }
            
            if let actionHint = element.actionHint {
                elementDict["actionHint"] = actionHint
            }
            
            elementDict["interactions"] = element.interactions
            
            // Accessibility data
            if let accData = element.accessibilityData {
                elementDict["accessibility"] = [
                    "role": accData.role,
                    "description": accData.description ?? NSNull(),
                    "title": accData.title ?? NSNull(),
                    "enabled": accData.enabled,
                    "focused": accData.focused
                ]
            }
            
            // OCR data
            if let ocrData = element.ocrData {
                elementDict["ocr"] = [
                    "text": ocrData.text,
                    "confidence": ocrData.confidence,
                    "boundingBox": [
                        "x": ocrData.boundingBox.origin.x,
                        "y": ocrData.boundingBox.origin.y,
                        "width": ocrData.boundingBox.width,
                        "height": ocrData.boundingBox.height
                    ]
                ]
            }
            
            return elementDict
        }
        
        // Metadata
        jsonDict["metadata"] = [
            "timestamp": ISO8601DateFormatter().string(from: data.timestamp),
            "processingTime": data.processingTime,
            "performance": [
                "accessibilityTime": data.performance.accessibilityTime,
                "screenshotTime": data.performance.screenshotTime,
                "ocrTime": data.performance.ocrTime,
                "fusionTime": data.performance.fusionTime,
                "totalElements": data.performance.totalElements,
                "fusedElements": data.performance.fusedElements,
                "memoryUsage": data.performance.memoryUsage
            ]
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        } catch {
            print("❌ JSON serialization failed: \(error)")
            return Data()
        }
    }
    
    func toCompressed(_ data: CompleteUIMap) -> String {
        // Create grid mapper and compression engine
        let gridMapper = GridSweepMapper(windowFrame: data.windowFrame)
        let gridMappedElements = gridMapper.mapToGrid(data.elements)
        
        let compressionEngine = CompressionEngine()
        let compressed = compressionEngine.compress(gridMappedElements)
        
        // Create window prefix
        let windowPrefix = "\(data.windowTitle.prefix(8))|\(String(format: "%.0f", data.windowFrame.width))x\(String(format: "%.0f", data.windowFrame.height))|"
        
        return windowPrefix + compressed.format
    }
} import Foundation

// MARK: - Performance Monitor

class PerformanceMonitor {
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
} #!/usr/bin/env swift

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