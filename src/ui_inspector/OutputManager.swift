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
        
        // System context
        jsonDict["systemContext"] = data.systemContext
        
        // Compressed output for GPT consumption (includes focus indicators)
        jsonDict["compressedOutput"] = toCompressed(data)
        
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
        // Separate menu bar elements from window elements
        let menuBarElements = data.elements.filter { $0.type == "appMenu" || $0.type == "systemMenu" }
        let windowElements = data.elements.filter { $0.type != "appMenu" && $0.type != "systemMenu" }
        
        // Process window elements with grid mapping
        let gridMapper = GridSweepMapper(windowFrame: data.windowFrame)
        let gridMappedElements = gridMapper.mapToGrid(windowElements)
        
        let compressionEngine = CompressionEngine()
        let compressed = compressionEngine.compress(gridMappedElements)
        
        // Process menu bar elements with menu bar coordinates
        let menuBarCompressed = compressMenuBarElements(menuBarElements)
        
        // Create window prefix - extract app name and current URL from window title
        let appName: String
        var currentURL: String = ""
        
        if data.windowTitle.hasPrefix("activwndw: ") {
            let titleWithoutPrefix = String(data.windowTitle.dropFirst(11)) // Remove "activwndw: "
            if let dashIndex = titleWithoutPrefix.firstIndex(of: "-") {
                appName = String(titleWithoutPrefix[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                let pageTitle = String(titleWithoutPrefix[titleWithoutPrefix.index(after: dashIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // For browsers, extract URL from address bar text field (primary) or page title (fallback)
                if appName.lowercased().contains("safari") || appName.lowercased().contains("chrome") || appName.lowercased().contains("firefox") {
                    // Primary: Look for URL in text field elements (address bar)
                    for element in windowElements {
                        if element.type.contains("TextField") || element.type.contains("textField") {
                            if let visualText = element.visualText,
                               !visualText.isEmpty,
                               (visualText.hasPrefix("http://") || visualText.hasPrefix("https://") || 
                                visualText.contains(".com") || visualText.contains(".org") || visualText.contains(".net")) {
                                // Clean up the URL (remove protocols for brevity)
                                var cleanURL = visualText
                                if cleanURL.hasPrefix("https://") {
                                    cleanURL = String(cleanURL.dropFirst(8))
                                } else if cleanURL.hasPrefix("http://") {
                                    cleanURL = String(cleanURL.dropFirst(7))
                                }
                                if cleanURL.hasPrefix("www.") {
                                    cleanURL = String(cleanURL.dropFirst(4))
                                }
                                currentURL = String(cleanURL.prefix(30)) // Limit URL length
                                break
                            }
                        }
                    }
                    
                    // Fallback: Use page title patterns if no URL found
                    if currentURL.isEmpty && !pageTitle.isEmpty {
                        let lowercaseTitle = pageTitle.lowercased()
                        if lowercaseTitle.contains("google") {
                            currentURL = "google.com"
                        } else if lowercaseTitle.contains("apple") {
                            currentURL = "apple.com"
                        } else if lowercaseTitle.contains("github") {
                            currentURL = "github.com"
                        } else if lowercaseTitle.contains("youtube") {
                            currentURL = "youtube.com"
                        } else if lowercaseTitle.contains("facebook") {
                            currentURL = "facebook.com"
                        } else if lowercaseTitle.contains("twitter") {
                            currentURL = "twitter.com"
                        } else if lowercaseTitle.contains("linkedin") {
                            currentURL = "linkedin.com"
                        } else if lowercaseTitle.contains("stackoverflow") {
                            currentURL = "stackoverflow.com"
                        } else {
                            currentURL = "page:\(String(pageTitle.prefix(20)))"
                        }
                    }
                    
                    // Final fallback
                    if currentURL.isEmpty {
                        currentURL = "new-tab"
                    }
                }
            } else {
                appName = titleWithoutPrefix
            }
        } else {
            appName = String(data.windowTitle.prefix(8))
        }
        
        // Create window prefix with URL if available
        let urlPart = currentURL.isEmpty ? "" : "|\(currentURL)"
        let windowPrefix = "\(appName)|\(String(format: "%.0f", data.windowFrame.width))x\(String(format: "%.0f", data.windowFrame.height))\(urlPart)|"
        
        // Combine menu bar and window elements
        let combinedFormat = menuBarCompressed.isEmpty ? compressed.format : "\(menuBarCompressed),\(compressed.format)"
        
        return windowPrefix + combinedFormat
    }
    
    private func compressMenuBarElements(_ menuBarElements: [UIElement]) -> String {
        var menuBarItems: [String] = []
        
        for element in menuBarElements {
            guard let visualText = element.visualText,
                  let context = element.context else { continue }
            
            let navigationPath = context.navigationPath
            
            // Extract menu bar position from navigation path (e.g., "MenuBar[M1] > Apple")
            var menuBarPosition = ""
            if let startIndex = navigationPath.firstIndex(of: "["),
               let endIndex = navigationPath.firstIndex(of: "]") {
                let start = navigationPath.index(after: startIndex)
                menuBarPosition = String(navigationPath[start..<endIndex])
            }
            
            if !menuBarPosition.isEmpty {
                let elementType = element.type == "systemMenu" ? "sys" : "menu"
                let shortText = visualText.prefix(8) // Limit text length for compression
                menuBarItems.append("\(elementType):\(shortText)@\(menuBarPosition)")
            }
        }
        
        return menuBarItems.joined(separator: ",")
    }
} 