import Foundation
import AppKit
import ApplicationServices

// MARK: - Accessibility Engine

class AccessibilityEngine: AccessibilityScanning {
    private static var cachedWindowData: [String: Any] = [:]
    private static var lastCacheTime: Date?
    
    func scanElements() -> [AccessibilityData] {
        let scanStart = Date()
        print("🔍 DEBUG: Starting accessibility scan...")
        
        guard let (_, accessibilityElements) = getAccessibilityData() else {
            print("❌ Failed to get accessibility data")
            return []
        }
        
        let scanTime = Date().timeIntervalSince(scanStart)
        print("🔧 Found \(accessibilityElements.count) accessibility elements in \(String(format: "%.3f", scanTime))s")
        return accessibilityElements
    }
    
    // MARK: - Accessibility Data Collection
    
    private func getAccessibilityData() -> ([String: Any], [AccessibilityData])? {
        // Check cache first
        let now = Date()
        if let lastCache = Self.lastCacheTime,
           now.timeIntervalSince(lastCache) < Config.cacheTimeout,
           !Self.cachedWindowData.isEmpty {
            
            let cachedData = Self.cachedWindowData
            
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
        
        // Recursively traverse the accessibility tree with increased depth for containers
        traverseAccessibilityTree(
            element: window,
            allElements: &allElements,
            processedElements: &processedElements,
            depth: 0,
            maxDepth: 20  // Increased from 10 to 20 for deeper browser/list traversal
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
        } else {
            // Special handling for container elements that might have lazy-loaded children
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String,
               isContainerRole(role) {
                print("🔍 DEBUG: Container \(role) at depth \(depth) has no immediate children - trying alternative methods")
                
                // Try to force refresh of children for browser/list elements
                tryAlternativeChildrenAccess(element: element, allElements: &allElements, processedElements: &processedElements, depth: depth, maxDepth: maxDepth)
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
        let description = getStringAttribute(element, kAXDescriptionAttribute as CFString)
        let title = getStringAttribute(element, kAXTitleAttribute as CFString)
        let help = getStringAttribute(element, kAXHelpAttribute as CFString)
        let subrole = getStringAttribute(element, kAXSubroleAttribute as CFString)
        let value = getStringAttribute(element, kAXValueAttribute as CFString)
        
        // Extract boolean attributes
        let enabled = getBoolAttribute(element, kAXEnabledAttribute as CFString) ?? true
        let focused = getBoolAttribute(element, kAXFocusedAttribute as CFString) ?? false
        let selected = getBoolAttribute(element, kAXSelectedAttribute as CFString) ?? false
        
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
              let parent = parentRef else {
            return nil
        }
        let parentElement = parent as! AXUIElement
        
        // Get parent role for identification
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parentElement, kAXRoleAttribute as CFString, &roleRef) == .success,
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
    
    // MARK: - Container Handling
    
    private func isContainerRole(_ role: String) -> Bool {
        return ["AXBrowser", "AXList", "AXScrollArea", "AXTable", "AXOutline", "AXWebArea", "AXGroup"].contains(role)
    }
    
    // MARK: - Enhanced Input Field Detection
    
    private func isInputFieldRole(_ role: String) -> Bool {
        // Extended list of input-related accessibility roles
        return [
            "AXTextField", "AXTextArea", "AXSearchField", "AXComboBox",
            "AXPopUpButton", "AXButton", "AXCheckBox", "AXRadioButton",
            "AXSlider", "AXIncrementor", "AXDateField", "AXTimeField",
            "AXPasswordField", "AXSecureTextField"
        ].contains(role)
    }
    
    private func tryAlternativeChildrenAccess(
        element: AXUIElement,
        allElements: inout [AccessibilityData],
        processedElements: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) {
        // Try alternative attributes that might contain children
        let alternativeAttributes = [
            kAXRowsAttribute as CFString,
            kAXVisibleRowsAttribute as CFString,
            kAXSelectedRowsAttribute as CFString,
            kAXColumnsAttribute as CFString,
            kAXVisibleColumnsAttribute as CFString
        ]
        
        for attribute in alternativeAttributes {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
               let elements = valueRef as? [AXUIElement] {
                print("🔍 DEBUG: Found \(elements.count) children via \(attribute)")
                
                for child in elements {
                    traverseAccessibilityTree(
                        element: child,
                        allElements: &allElements,
                        processedElements: &processedElements,
                        depth: depth + 1,
                        maxDepth: maxDepth
                    )
                }
                break // Stop after first successful alternative
            }
        }
        
        // Special handling for web content - try to find form elements
        if depth < maxDepth - 2 { // Only try for shallow depths to avoid infinite recursion
            tryWebFormElementAccess(
                element: element,
                allElements: &allElements,
                processedElements: &processedElements,
                depth: depth,
                maxDepth: maxDepth
            )
        }
    }
    
    private func tryWebFormElementAccess(
        element: AXUIElement,
        allElements: inout [AccessibilityData],
        processedElements: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) {
        // Try to find form elements using web-specific attributes
        let webAttributes = [
            kAXValueAttribute as CFString,
            kAXPlaceholderValueAttribute as CFString,
            kAXInsertionPointLineNumberAttribute as CFString
        ]
        
        for attribute in webAttributes {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success {
                // If element has web form attributes, it might be an input field
                if let accessibilityData = createAccessibilityData(from: element) {
                    let elementId = getElementIdentifier(accessibilityData)
                    if !processedElements.contains(elementId) {
                        print("🔍 DEBUG: Found potential web form element with \(attribute): \(accessibilityData.role)")
                        allElements.append(accessibilityData)
                        processedElements.insert(elementId)
                    }
                }
                break
            }
        }
    }
    
    private func getElementIdentifier(_ accessibilityData: AccessibilityData) -> String {
        // Create a unique identifier for accessibility elements
        var identifier = accessibilityData.role
        
        if let position = accessibilityData.position {
            identifier += "_\(Int(position.x))_\(Int(position.y))"
        }
        
        if let title = accessibilityData.title {
            identifier += "_\(title)"
        }
        
        if let description = accessibilityData.description {
            identifier += "_\(description)"
        }
        
        return identifier
    }
} 