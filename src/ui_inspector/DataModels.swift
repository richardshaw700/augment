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
    
    /// Convert UIElement to dictionary for JSON serialization
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // Core properties
        dict["id"] = id
        dict["type"] = type
        dict["position"] = ["x": position.x, "y": position.y]
        dict["size"] = ["width": size.width, "height": size.height]
        dict["isClickable"] = isClickable
        dict["confidence"] = confidence
        dict["semanticMeaning"] = semanticMeaning
        dict["interactions"] = interactions
        
        // Optional properties
        if let visualText = visualText {
            dict["visualText"] = visualText
        }
        
        if let actionHint = actionHint {
            dict["actionHint"] = actionHint
        }
        
        // Accessibility data
        if let accData = accessibilityData {
            dict["accessibility"] = [
                "role": accData.role,
                "description": accData.description as Any? ?? NSNull(),
                "title": accData.title as Any? ?? NSNull(),
                "enabled": accData.enabled,
                "focused": accData.focused
            ]
        }
        
        // OCR data
        if let ocrData = ocrData {
            dict["ocr"] = [
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
        
        // Context
        if let context = context {
            dict["context"] = [
                "purpose": context.purpose,
                "region": context.region,
                "navigationPath": context.navigationPath,
                "availableActions": context.availableActions
            ]
        }
        
        return dict
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
    let systemContext: [String: Any]
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

protocol OutputFormatting {
    func toJSON(_ data: CompleteUIMap) -> Data
    func toCompressed(_ data: CompleteUIMap) -> String
}

