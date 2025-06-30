import Foundation
import AppKit

// MARK: - Compression Service
//
// Handles the conversion from cleaned JSON data to compressed text format
// This service takes the cleaned JSON and produces the final compressed output for human consumption

class CompressionService {
    
    // MARK: - Main Compression Methods
    
    /// Generate multi-line compressed format from cleaned JSON data
    static func generateCompressedFormat(from cleanedData: Data) throws -> String {
        // Parse the cleaned JSON
        guard let jsonObject = try JSONSerialization.jsonObject(with: cleanedData, options: []) as? [String: Any],
              let elements = jsonObject["elements"] as? [[String: Any]],
              let window = jsonObject["window"] as? [String: Any],
              let windowFrame = window["frame"] as? [String: Any] else {
            throw NSError(domain: "CompressionServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse cleaned JSON"])
        }
        
        // Get window dimensions
        let windowWidth = windowFrame["width"] as? Double ?? 660
        let windowHeight = windowFrame["height"] as? Double ?? 579
        
        // Extract app name from window title
        let windowTitle = window["title"] as? String ?? ""
        let appName = extractAppName(from: windowTitle)
        
        // Separate menu bar elements from window elements
        var menuBarElements: [String] = []
        var windowElements: [String] = []
        
        for element in elements {
            let type = element["type"] as? String ?? ""
            let isMenuitem = type.contains("Menu") || type.contains("menu")
            
            let compressedElement = compressElement(element, windowWidth: windowWidth, windowHeight: windowHeight)
            if !compressedElement.isEmpty {
                if isMenuitem {
                    menuBarElements.append(compressedElement)
                } else {
                    windowElements.append(compressedElement)
                }
            }
        }
        
        // Build multi-line structured output
        var output: [String] = []
        
        // Add app and window info
        output.append("\(appName) | \(String(format: "%.0f", windowWidth))x\(String(format: "%.0f", windowHeight))")
        output.append("")
        
        // Add menu bar section if we have menu items
        if !menuBarElements.isEmpty {
            output.append("MENU BAR")
            for menuElement in menuBarElements {
                output.append(menuElement)
            }
            output.append("")
        }
        
        // Add window section if we have window elements
        if !windowElements.isEmpty {
            output.append("APP WINDOW")
            for windowElement in windowElements {
                output.append(windowElement)
            }
        }
        
        return output.joined(separator: "\n")
    }
    
    /// Generate compressed format from CompleteUIMap (for backward compatibility)
    static func generateCompressedFormat(from completeMap: CompleteUIMap) -> String {
        // Convert CompleteUIMap elements to dictionary format
        var elements: [[String: Any]] = []
        
        for element in completeMap.elements {
            let elementDict = convertUIElementToDict(element, windowFrame: completeMap.windowFrame)
            elements.append(elementDict)
        }
        
        // Create window info
        let windowInfo: [String: Any] = [
            "title": completeMap.windowTitle,
            "frame": [
                "width": Double(completeMap.windowFrame.width),
                "height": Double(completeMap.windowFrame.height)
            ]
        ]
        
        // Create JSON structure
        let jsonObject: [String: Any] = [
            "elements": elements,
            "window": windowInfo
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            return try generateCompressedFormat(from: jsonData)
        } catch {
            print("⚠️ Failed to generate compressed format from CompleteUIMap: \(error)")
            return ""
        }
    }
    
    // MARK: - Element Compression
    
    private static func compressElement(_ element: [String: Any], windowWidth: Double, windowHeight: Double) -> String {
        guard let boundingBox = element["boundingBox"] as? [String: Any],
              let width = boundingBox["width"] as? Double,
              let height = boundingBox["height"] as? Double else {
            return ""
        }
        
        // Get center point coordinates (preferred for automation)
        let centerX: Double
        let centerY: Double
        
        if let center = boundingBox["center"] as? [String: Any],
           let cx = center["x"] as? Double,
           let cy = center["y"] as? Double {
            centerX = cx
            centerY = cy
        } else {
            // Fallback: calculate center from top-left + size
            let x = boundingBox["x"] as? Double ?? 0
            let y = boundingBox["y"] as? Double ?? 0
            centerX = x + (width / 2)
            centerY = y + (height / 2)
        }
        
        // Get element type to determine coordinate handling
        let type = element["type"] as? String ?? ""
        let isMenuitem = type.contains("Menu") || type.contains("menu")
        
        let positionString: String
        if isMenuitem {
            // For menu items, use their actual center coordinates
            positionString = String(format: "%.0f:%.0f", centerX, centerY)
        } else {
            // For regular elements, calculate percentage positions from center point
            let xPercent = Int((centerX / windowWidth) * 100)
            let yPercent = Int((centerY / windowHeight) * 100)
            positionString = "\(xPercent):\(yPercent)"
        }
        
        // Get element type abbreviation
        let elementType = TextExtractor.getElementTypeAbbreviation(from: element)
        
        // Get element text using TextExtractor
        let displayText = TextExtractor.extractDisplayText(from: element)
        
        // Filter out generic buttons with unhelpful text
        let lowercaseText = displayText.lowercased()
        if elementType == "btn" && (lowercaseText == "button" || lowercaseText == "radio button" || lowercaseText == "checkbox" || lowercaseText == "element" || displayText.isEmpty) {
            return "" // Skip generic buttons
        }
        
        // Format: type:text|widthxheight@x:y
        // Example: txt:JD|21x13@7:50 or menu:Apple|60x24@0:0
        return String(format: "%@:%@|%.0fx%.0f@%@", 
                     elementType, 
                     displayText, 
                     width, 
                     height, 
                     positionString)
    }
    
    // MARK: - Helper Methods
    
    private static func extractAppName(from windowTitle: String) -> String {
        if windowTitle.hasPrefix("activwndw: ") {
            let titleWithoutPrefix = String(windowTitle.dropFirst(11))
            if let dashIndex = titleWithoutPrefix.firstIndex(of: "-") {
                return String(titleWithoutPrefix[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            } else {
                return titleWithoutPrefix
            }
        }
        return String(windowTitle.prefix(8))
    }
    
    private static func convertUIElementToDict(_ element: UIElement, windowFrame: NSRect) -> [String: Any] {
        // Convert absolute screen coordinates to window-relative coordinates
        let windowRelativeX = Double(element.position.x - windowFrame.origin.x)
        let windowRelativeY = Double(element.position.y - windowFrame.origin.y)
        
        // Calculate center point using window-relative coordinates
        let centerX = windowRelativeX + Double(element.size.width) / 2
        let centerY = windowRelativeY + Double(element.size.height) / 2
        
        return [
            "id": element.id,
            "type": element.type,
            "text": element.visualText ?? "",
            "boundingBox": [
                "x": windowRelativeX,
                "y": windowRelativeY,
                "width": Double(element.size.width),
                "height": Double(element.size.height),
                "center": [
                    "x": centerX,
                    "y": centerY
                ]
            ],
            "isClickable": element.isClickable,
            "interactions": element.interactions
        ]
    }
} 