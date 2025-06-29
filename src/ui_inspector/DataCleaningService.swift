import Foundation
import Vision
import AppKit
import ApplicationServices

// MARK: - Data Cleaning Service
//
// Handles the conversion from raw UI data to cleaned, merged, and formatted data
// This service takes the raw JSON output and produces the cleaned JSON used for compression

class DataCleaningService {
    
    /// Generate cleaned JSON from raw JSON data
    static func generateCleanedJSON(from rawData: Data) throws -> Data {
        // Parse the raw JSON
        guard let jsonObject = try JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any],
              let elements = jsonObject["elements"] as? [[String: Any]] else {
            throw NSError(domain: "DataCleaningServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse raw JSON"])
        }
        
        // Extract window position for coordinate conversion
        var windowX: Double = 0
        var windowY: Double = 0
        if let window = jsonObject["window"] as? [String: Any],
           let frame = window["frame"] as? [String: Any] {
            windowX = frame["x"] as? Double ?? 0
            windowY = frame["y"] as? Double ?? 0
        }
        
        // Clean each element
        var cleanedElements: [[String: Any]] = []
        
        for element in elements {
            let cleanedElement = cleanElement(element, windowX: windowX, windowY: windowY)
            cleanedElements.append(cleanedElement)
        }
        
        // Merge proximate text elements (only for TextContent elements)
        cleanedElements = mergeProximateTextElements(cleanedElements)
        
        // Create cleaned output structure
        var cleanedOutput: [String: Any] = [:]
        
        // Copy window information
        if let window = jsonObject["window"] {
            cleanedOutput["window"] = window
        }
        
        // Add timestamp
        let formatter = ISO8601DateFormatter()
        cleanedOutput["timestamp"] = formatter.string(from: Date())
        
        // Add total elements count
        cleanedOutput["totalElements"] = cleanedElements.count
        
        // Add cleaned elements
        cleanedOutput["elements"] = cleanedElements
        
        // Serialize to JSON with custom formatting for arrays
        let jsonData = try JSONSerialization.data(withJSONObject: cleanedOutput, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        // Format arrays to be on single lines
        let formattedString = formatArraysOnSingleLine(jsonString)
        
        return formattedString.data(using: .utf8) ?? jsonData
    }
    
    // MARK: - Text Merging
    
    private static func mergeProximateTextElements(_ elements: [[String: Any]]) -> [[String: Any]] {
        // Separate different types of elements
        let textElements = elements.filter { ($0["type"] as? String) == "TextContent" }
        let textFieldElements = elements.filter { 
            let type = $0["type"] as? String ?? ""
            return type.contains("TextField") || type.contains("AXTextField")
        }
        let otherElements = elements.filter { 
            let type = $0["type"] as? String ?? ""
            return type != "TextContent" && !type.contains("TextField") && !type.contains("AXTextField")
        }
        
        guard textElements.count > 1 else {
            return elements // Nothing to merge
        }
        
        // Filter out text elements that are inside text fields (to prevent merging placeholder text)
        let textElementsToMerge = textElements.filter { textElement in
            !isTextInsideTextField(textElement, textFields: textFieldElements)
        }
        
        let textElementsToPreserve = textElements.filter { textElement in
            isTextInsideTextField(textElement, textFields: textFieldElements)
        }
        
        // Use 2D spatial clustering on the filtered text elements
        let clusters = clusterElementsBySpatialProximity(textElementsToMerge)
        
        var mergedElements: [[String: Any]] = []
        
        for cluster in clusters {
            if cluster.count > 1 {
                let merged = mergeElementGroup(cluster)
                mergedElements.append(merged)
            } else {
                mergedElements.append(contentsOf: cluster)
            }
        }
        
        // Combine all elements: merged text + preserved text + text fields + other elements
        let allElements = mergedElements + textElementsToPreserve + textFieldElements + otherElements
        
        print("🔗 Text merging: \(textElements.count) → \(mergedElements.count + textElementsToPreserve.count) text elements (\(clusters.count) clusters, \(textElementsToPreserve.count) preserved)")
        
        return allElements
    }
    
    private static func clusterElementsBySpatialProximity(_ elements: [[String: Any]]) -> [[[String: Any]]] {
        var clusters: [[[String: Any]]] = []
        var unprocessed = elements
        
        while !unprocessed.isEmpty {
            let seed = unprocessed.removeFirst()
            var cluster = [seed]
            
            // Find all elements that should be merged with this seed
            var i = 0
            while i < unprocessed.count {
                let candidate = unprocessed[i]
                
                // Check if candidate should be merged with any element in current cluster
                var shouldAddToCluster = false
                for clusterElement in cluster {
                    if shouldMergeElements(clusterElement, candidate) {
                        shouldAddToCluster = true
                        break
                    }
                }
                
                if shouldAddToCluster {
                    cluster.append(candidate)
                    unprocessed.remove(at: i)
                    i = 0 // Restart search since cluster changed
                } else {
                    i += 1
                }
            }
            
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    private static func isTextInsideTextField(_ textElement: [String: Any], textFields: [[String: Any]]) -> Bool {
        let textBbox = textElement["boundingBox"] as? [String: Any] ?? [:]
        let textX = textBbox["x"] as? Double ?? 0
        let textY = textBbox["y"] as? Double ?? 0
        let textWidth = textBbox["width"] as? Double ?? 0
        let textHeight = textBbox["height"] as? Double ?? 0
        
        let textCenter = CGPoint(x: textX + textWidth/2, y: textY + textHeight/2)
        
        for textField in textFields {
            let fieldBbox = textField["boundingBox"] as? [String: Any] ?? [:]
            let fieldX = fieldBbox["x"] as? Double ?? 0
            let fieldY = fieldBbox["y"] as? Double ?? 0
            let fieldWidth = fieldBbox["width"] as? Double ?? 0
            let fieldHeight = fieldBbox["height"] as? Double ?? 0
            
            let fieldRect = CGRect(x: fieldX, y: fieldY, width: fieldWidth, height: fieldHeight)
            
            if fieldRect.contains(textCenter) {
                print("🔒 Preserving text '\(textElement["text"] as? String ?? "")' inside text field")
                return true
            }
        }
        
        return false
    }
    
    private static func shouldMergeElements(_ element1: [String: Any], _ element2: [String: Any]) -> Bool {
        let bbox1 = element1["boundingBox"] as? [String: Any] ?? [:]
        let bbox2 = element2["boundingBox"] as? [String: Any] ?? [:]
        
        let x1 = bbox1["x"] as? Double ?? 0
        let y1 = bbox1["y"] as? Double ?? 0
        let width1 = bbox1["width"] as? Double ?? 0
        let height1 = bbox1["height"] as? Double ?? 0
        
        let x2 = bbox2["x"] as? Double ?? 0
        let y2 = bbox2["y"] as? Double ?? 0
        let width2 = bbox2["width"] as? Double ?? 0
        let height2 = bbox2["height"] as? Double ?? 0
        
        // Calculate the actual gap between bounding boxes
        let verticalGap = abs(y2 - (y1 + height1)) // Gap when element2 is below element1
        let reverseVerticalGap = abs(y1 - (y2 + height2)) // Gap when element1 is below element2
        let minVerticalGap = min(verticalGap, reverseVerticalGap)
        
        // Only merge if vertical gap is 10px or less
        guard minVerticalGap <= 10.0 else { return false }
        
        // Check horizontal relationship
        let leftEdge1 = x1
        let rightEdge1 = x1 + width1
        let leftEdge2 = x2
        let rightEdge2 = x2 + width2
        
        // Calculate horizontal overlap or gap
        let horizontalOverlap = max(0, min(rightEdge1, rightEdge2) - max(leftEdge1, leftEdge2))
        let horizontalGap = max(0, max(leftEdge2 - rightEdge1, leftEdge1 - rightEdge2))
        
        // Merge if elements overlap horizontally OR are within 20px horizontally
        return horizontalOverlap > 0 || horizontalGap <= 20.0
    }
    
    private static func mergeElementGroup(_ group: [[String: Any]]) -> [String: Any] {
        guard !group.isEmpty else {
            return [:]
        }
        
        // Use first element as base
        var merged = group[0]
        
        // Combine text from all elements
        let combinedText = group.compactMap { $0["text"] as? String }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        
        // Calculate merged bounding box
        let mergedBoundingBox = calculateMergedBoundingBox(group)
        
        // Update merged element
        merged["text"] = combinedText
        merged["boundingBox"] = mergedBoundingBox
        merged["type"] = "MergedTextContent"
        
        // Generate new ID for merged element
        merged["id"] = "MERGED_\(UUID().uuidString)"
        
        return merged
    }
    
    private static func calculateMergedBoundingBox(_ group: [[String: Any]]) -> [String: Any] {
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        
        for element in group {
            let bbox = element["boundingBox"] as? [String: Any] ?? [:]
            let x = bbox["x"] as? Double ?? 0
            let y = bbox["y"] as? Double ?? 0
            let width = bbox["width"] as? Double ?? 0
            let height = bbox["height"] as? Double ?? 0
            
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x + width)
            maxY = max(maxY, y + height)
        }
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Calculate center point
        let centerX = minX + (width / 2)
        let centerY = minY + (height / 2)
        
        return [
            "x": minX,
            "y": minY,
            "width": width,
            "height": height,
            "center": [
                "x": centerX,
                "y": centerY
            ]
        ]
    }
    
    // MARK: - Element Cleaning
    
    private static func cleanElement(_ element: [String: Any], windowX: Double, windowY: Double) -> [String: Any] {
        // Extract text from multiple possible sources
        let textSources = [
            element["visualText"] as? String ?? "",
            element["label"] as? String ?? "",
            element["title"] as? String ?? "",
            element["value"] as? String ?? "",
            element["semanticMeaning"] as? String ?? ""
        ]
        
        // Find the first non-empty text
        let text = textSources.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        
        // Create bounding box from position and size
        let position = element["position"] as? [String: Any] ?? [:]
        let size = element["size"] as? [String: Any] ?? [:]
        
        let screenX = position["x"] as? Double ?? 0
        let screenY = position["y"] as? Double ?? 0
        let width = size["width"] as? Double ?? 0
        let height = size["height"] as? Double ?? 0
        
        // Check if this is a menu item (should keep screen-absolute coordinates)
        let type = element["type"] as? String ?? ""
        let isMenuitem = type.contains("Menu") || type.contains("menu")
        
        // Convert coordinates based on element type
        let x: Double
        let y: Double
        
        if isMenuitem {
            // Menu items keep their screen-absolute coordinates
            x = screenX
            y = screenY
        } else {
            // Regular elements get window-relative coordinates
            x = screenX - windowX
            y = screenY - windowY
        }
        
        // Calculate center point (also window-relative)
        let centerX = x + (width / 2)
        let centerY = y + (height / 2)
        
        let boundingBox: [String: Any] = [
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "center": [
                "x": centerX,
                "y": centerY
            ]
        ]
        
        // Clean up interactions list - handle both [String] and [Any] cases
        var interactions: [String] = []
        if let interactionsArray = element["interactions"] as? [Any] {
            interactions = interactionsArray.compactMap { $0 as? String }
        } else if let interactionsStringArray = element["interactions"] as? [String] {
            interactions = interactionsStringArray
        }
        
        // Extract accessibility properties if present (only the essential ones)
        var accessibility: [String: Any]? = nil
        if let accessibilityData = element["accessibility"] as? [String: Any] {
            var cleanedAccessibility: [String: Any] = [:]
            
            if let description = accessibilityData["description"] as? String, !description.isEmpty {
                cleanedAccessibility["description"] = description
            }
            if let enabled = accessibilityData["enabled"] as? Bool {
                cleanedAccessibility["enabled"] = enabled
            }
            if let focused = accessibilityData["focused"] as? Bool {
                cleanedAccessibility["focused"] = focused
            }
            
            // Only include accessibility if it has meaningful content
            if !cleanedAccessibility.isEmpty {
                accessibility = cleanedAccessibility
            }
        }
        
        // Create cleaned element with base properties
        var cleanedElement: [String: Any] = [
            "id": element["id"] as? String ?? "",
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            "boundingBox": boundingBox,
            "isClickable": element["isClickable"] as? Bool ?? false,
            "type": element["type"] as? String ?? "",
            "interactions": interactions
        ]
        
        // Add semanticMeaning if it exists
        if let semanticMeaning = element["semanticMeaning"] as? String, !semanticMeaning.isEmpty {
            cleanedElement["semanticMeaning"] = semanticMeaning
        }
        
        // Add accessibility properties if they exist
        if let accessibility = accessibility {
            cleanedElement["accessibility"] = accessibility
        }
        
        return cleanedElement
    }
    
    // MARK: - Formatting Helpers
    
    private static func formatArraysOnSingleLine(_ jsonString: String) -> String {
        let lines = jsonString.components(separatedBy: .newlines)
        var formattedLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check if this line contains an array start (like "interactions" : [)
            if line.contains("\"interactions\"") && line.hasSuffix("[") {
                var arrayContent: [String] = []
                
                // Extract the indentation from the original line
                let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                let arrayLine = line.replacingOccurrences(of: "[", with: "").trimmingCharacters(in: .whitespaces)
                
                // Collect array elements
                i += 1
                while i < lines.count {
                    let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                    
                    if currentLine == "]" || currentLine == "]," {
                        // End of array found
                        let arrayElements = arrayContent.isEmpty ? "" : arrayContent.joined(separator: ", ")
                        let formattedArray = "\(leadingWhitespace)\(arrayLine)[\(arrayElements)]"
                        if currentLine.hasSuffix(",") {
                            formattedLines.append(formattedArray + ",")
                        } else {
                            formattedLines.append(formattedArray)
                        }
                        break
                    } else if currentLine.hasPrefix("\"") {
                        // This is an array element
                        arrayContent.append(currentLine.replacingOccurrences(of: ",", with: ""))
                    }
                    i += 1
                }
            } else {
                formattedLines.append(line)
            }
            i += 1
        }
        
        return formattedLines.joined(separator: "\n")
    }
}

// MARK: - Text Extraction Service
//
// Handles text extraction and type mapping for data cleaning operations
// This service is used exclusively by DataCleaningService during the raw→cleaned conversion

class TextExtractor {
    /// Extract display text from a cleaned JSON element
    static func extractDisplayText(from element: [String: Any]) -> String {
        let text = element["text"] as? String ?? ""
        let type = element["type"] as? String ?? ""
        
        let displayText: String
        if text.isEmpty {
            displayText = "Element"
        } else {
            displayText = text
        }
        
        let cleanedText = displayText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if this is already a merged text field with placeholder format
        if cleanedText.contains(",plchldr:") {
            return cleanedText // Already has the correct format
        }
        
        // Add focus state for regular text inputs
        if isTextInput(type: type) {
            let focusState = getFocusState(from: element)
            return "\(cleanedText) \(focusState)"
        }
        
        return cleanedText
    }
    
    /// Extract display text from a UIElement
    static func extractDisplayText(from element: UIElement) -> String {
        var baseText: String
        
        if let text = element.visualText, !text.isEmpty {
            baseText = cleanText(text)
        } else if let actionHint = element.actionHint, 
           !actionHint.isEmpty,
           !actionHint.lowercased().contains("clickable element"),
           actionHint.count > 3 {
            let cleanAction = actionHint.replacingOccurrences(of: "Click ", with: "")
            baseText = cleanText(cleanAction)
        } else if let accData = element.accessibilityData,
           let title = accData.title, !title.isEmpty {
            baseText = cleanText(title)
        } else if let accData = element.accessibilityData,
           let description = accData.description, !description.isEmpty {
            baseText = cleanText(description)
        } else if let accData = element.accessibilityData {
            baseText = accData.role.replacingOccurrences(of: "AX", with: "")
        } else {
            baseText = element.type
        }
        
        // Check if this is already a merged text field with placeholder format
        if baseText.contains(",plchldr:") {
            return baseText // Already has the correct format
        }
        
        // Add focus state for regular text inputs
        if isTextInput(element: element) {
            let focusState = getFocusState(from: element)
            return "\(baseText) \(focusState)"
        }
        
        return baseText
    }
    
    private static func cleanText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get element type abbreviation from JSON element
    static func getElementTypeAbbreviation(from element: [String: Any]) -> String {
        let type = element["type"] as? String ?? ""
        let isClickable = element["isClickable"] as? Bool ?? false
        
        if let accessibility = element["accessibility"] as? [String: Any],
           let description = accessibility["description"] as? String {
            let desc = description.lowercased()
            
            if desc.contains("button") { return "btn" }
            if desc.contains("text field") || desc.contains("search") { return "txtinp" }
            if desc.contains("menu") { return "menu" }
            if desc.contains("dropdown") { return "dropdown" }
        }
        
        let lowerType = type.lowercased()
        if lowerType.contains("button") || lowerType.contains("axbutton") {
            return "btn"
        } else if lowerType.contains("textfield") || lowerType.contains("input") || lowerType.contains("search") {
            return "txtinp"
        } else if lowerType.contains("text") || lowerType.contains("merged") {
            return "txt"
        } else if lowerType.contains("image") {
            return "img"
        } else if lowerType.contains("link") {
            return "link"
        } else if lowerType.contains("menu") {
            return "menu"
        } else if isClickable {
            return "btn"
        } else {
            return "txt"
        }
    }
    
    /// Get element type abbreviation from UIElement
    static func getElementTypeAbbreviation(from element: UIElement) -> String {
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXButton": return "btn"
            case "AXPopUpButton": return "dropdown"
            case "AXTextField", "AXTextArea", "AXSearchField": return "txtinp"
            case "AXCheckBox": return "checkbox"
            case "AXRadioButton": return "radio"
            case "AXSlider": return "slider"
            case "AXScrollArea": return "scroll"
            case "AXLink": return "link"
            case "AXImage": return "img"
            case "AXStaticText": return "txt"
            case "AXMenuButton": return "menu"
            case "AXTab": return "tab"
            default: break
            }
        }
        
        let type = element.type.lowercased()
        if type.contains("button") {
            return "btn"
        } else if type.contains("textfield") || type.contains("input") {
            return "txtinp"
        } else if type.contains("text") {
            return "txt"
        } else if type.contains("image") {
            return "img"
        } else if type.contains("link") {
            return "link"
        }
        
        if element.isClickable {
            return "btn"
        }
        
        return "txt"
    }
    
    // MARK: - Helper Methods for Focus State
    
    private static func isTextInput(type: String) -> Bool {
        let lowerType = type.lowercased()
        return lowerType.contains("textfield") || 
               lowerType.contains("input") || 
               lowerType.contains("search") ||
               lowerType.contains("axtextfield") ||
               lowerType.contains("axtextarea") ||
               lowerType.contains("axsearchfield")
    }
    
    private static func isTextInput(element: UIElement) -> Bool {
        if let accData = element.accessibilityData {
            switch accData.role {
            case "AXTextField", "AXTextArea", "AXSearchField":
                return true
            default:
                break
            }
        }
        
        return isTextInput(type: element.type)
    }
    
    private static func getFocusState(from element: [String: Any]) -> String {
        if let accessibility = element["accessibility"] as? [String: Any],
           let focused = accessibility["focused"] as? Bool {
            return focused ? "[FOCUSED]" : "[UNFOCUSED]"
        }
        return "[UNKNOWN]"
    }
    
    private static func getFocusState(from element: UIElement) -> String {
        if let accData = element.accessibilityData {
            return accData.focused ? "[FOCUSED]" : "[UNFOCUSED]"
        }
        return "[UNKNOWN]"
    }
} 