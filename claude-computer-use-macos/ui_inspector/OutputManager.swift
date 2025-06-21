import Foundation

// MARK: - Output Manager

class OutputManager: OutputFormatting {
    func toJSON(_ data: CompleteUIMap) -> Data {
        // Performance optimization: Pre-allocate dictionary capacity
        var jsonDict: [String: Any] = [:]
        jsonDict.reserveCapacity(3) // window, elements, metadata
        
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
        
        // Elements - Performance optimization: Pre-allocate array capacity
        var elementsArray: [[String: Any]] = []
        elementsArray.reserveCapacity(data.elements.count)
        
        for element in data.elements {
            var elementDict: [String: Any] = [:]
            elementDict.reserveCapacity(12) // Estimate max keys per element
            
            // Core properties
            elementDict["id"] = element.id
            elementDict["type"] = element.type
            elementDict["position"] = ["x": element.position.x, "y": element.position.y]
            elementDict["size"] = ["width": element.size.width, "height": element.size.height]
            elementDict["isClickable"] = element.isClickable
            elementDict["confidence"] = element.confidence
            elementDict["semanticMeaning"] = element.semanticMeaning
            elementDict["interactions"] = element.interactions
            
            // Optional properties - only add if present
            if let visualText = element.visualText {
                elementDict["visualText"] = visualText
            }
            
            if let actionHint = element.actionHint {
                elementDict["actionHint"] = actionHint
            }
            
            // Accessibility data
            if let accData = element.accessibilityData {
                elementDict["accessibility"] = [
                    "role": accData.role,
                    "description": accData.description ?? NSNull(),
                    "title": accData.title as Any? ?? NSNull(),
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
            
            elementsArray.append(elementDict)
        }
        
        jsonDict["elements"] = elementsArray
        
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
} 