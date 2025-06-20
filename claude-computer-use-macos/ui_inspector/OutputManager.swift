import Foundation

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
} 