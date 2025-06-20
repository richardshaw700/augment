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
    static let COLUMNS = 40         // Extended columns: A-Z, AA-AN (40 total)
    static let ROWS = 50           // High vertical resolution
    static let TOTAL_CELLS = 2000  // 40 × 50 = 2000 addressable positions
    
    static let COLUMN_RANGE = "A"..."Z"  // Base range, extends to AA-AN
    static let ROW_RANGE = 1...50
    
    static let TOP_LEFT = "A1"
    static let TOP_RIGHT = "AN1"   // 40th column
    static let BOTTOM_LEFT = "A50"
    static let BOTTOM_RIGHT = "AN50"
    static let CENTER = "T25"      // Middle of 40x50 grid (T=20th column)
}

struct AdaptiveGridPosition: Hashable, CustomStringConvertible {
    let columnString: String  // A-Z, AA-AN for extended columns
    let row: Int             // 1-50
    
    init(_ columnString: String, _ row: Int) {
        precondition(!columnString.isEmpty, "Column string cannot be empty")
        precondition(row >= 1 && row <= 50, "Row must be 1-50")
        
        self.columnString = columnString
        self.row = row
    }
    
    // Convenience initializer for single character columns (A-Z)
    init(_ column: Character, _ row: Int) {
        self.init(String(column), row)
    }
    
    init?(gridString: String) {
        guard gridString.count >= 2 else { return nil }
        
        // Extract column part (letters) and row part (numbers)
        let columnPart = String(gridString.prefix(while: { $0.isLetter }))
        let rowPart = String(gridString.dropFirst(columnPart.count))
        
        guard !columnPart.isEmpty,
              let rowValue = Int(rowPart),
              rowValue >= 1 && rowValue <= 50 else {
            return nil
        }
        
        self.columnString = columnPart
        self.row = rowValue
    }
    
    var description: String {
        return "\(columnString)\(row)"
    }
    
    var columnIndex: Int {
        if columnString.count == 1 {
            // Single letter: A=0, B=1, ..., Z=25
            let char = columnString.first!
            return Int(char.asciiValue! - Character("A").asciiValue!)
        } else if columnString.count == 2 && columnString.hasPrefix("A") {
            // Double letter starting with A: AA=26, AB=27, ..., AN=39
            let secondChar = columnString.last!
            return 26 + Int(secondChar.asciiValue! - Character("A").asciiValue!)
        } else {
            // Fallback for unsupported formats
            return 0
        }
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
    
    // Helper function to create column string from index (0-39)
    static func columnString(from index: Int) -> String {
        if index < 26 {
            // Single letter: 0=A, 1=B, ..., 25=Z
            return String(Character(UnicodeScalar(65 + index)!))
        } else {
            // Double letter: 26=AA, 27=AB, ..., 39=AN
            let secondIndex = index - 26
            return "A" + String(Character(UnicodeScalar(65 + secondIndex)!))
        }
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

// Removed GridRegion enum - using pure grid-based approach

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
        // Simple grid position: "A1", "B2", etc.
        return position.description
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
    
    // Grid configuration - Higher resolution for better precision
    static let gridColumns = 40  // Extended columns beyond A-Z
    static let gridRows = 50      // High vertical resolution
    
    // Performance thresholds
    static let maxProcessingTime: TimeInterval = 5.0
    static let minElementConfidence: Double = 0.1  // Temporarily lowered for debugging
    
    // Feature flags
    static let enableCaching = true
    static let enableGridSweep = true
    static let enablePerformanceMonitoring = true
} 