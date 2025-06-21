import Foundation
import AppKit
import ApplicationServices

// MARK: - Browser Inspector

class BrowserInspector {
    
    // MARK: - Browser Detection
    
    static func isBrowserApp(_ bundleID: String) -> Bool {
        let browserBundleIDs = [
            "com.apple.Safari",
            "com.google.Chrome", 
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.operasoftware.Opera",
            "com.brave.Browser"
        ]
        return browserBundleIDs.contains(bundleID)
    }
    
    static func getBrowserType(_ bundleID: String) -> BrowserType? {
        switch bundleID {
        case "com.apple.Safari":
            return .safari
        case "com.google.Chrome":
            return .chrome
        case "com.microsoft.edgemac":
            return .edge
        case "org.mozilla.firefox":
            return .firefox
        case "com.operasoftware.Opera":
            return .opera
        case "com.brave.Browser":
            return .brave
        default:
            return nil
        }
    }
    
    // MARK: - Enhanced Browser Element Detection
    
    func enhanceBrowserElements(_ elements: [UIElement], browserType: BrowserType) -> [UIElement] {
        print("🌐 Enhancing browser elements for \(browserType.rawValue)")
        
        // Try to find form elements using JavaScript injection
        if let formElements = extractFormElements(browserType: browserType), !formElements.isEmpty {
            print("📝 Found \(formElements.count) form elements via JavaScript")
            
            // Merge with existing elements, avoiding duplicates
            return mergeFormElements(existing: elements, formElements: formElements)
        } else if extractFormElements(browserType: browserType) != nil {
            print("⚠️ JavaScript executed successfully but found 0 form elements")
        } else {
            print("🔍 JavaScript injection failed - browser may require permission or doesn't support AppleScript")
        }
        
        // Return original elements unchanged if JavaScript injection fails
        print("📝 Browser enhancement complete - using existing accessibility/OCR detection")
        return elements
    }
    
    // MARK: - JavaScript Injection for Form Detection
    
    private func extractFormElements(browserType: BrowserType) -> [UIElement]? {
        let javascript = """
        (function() {
            const results = [];
            console.log('Starting form element detection...');
            
            // Find all input elements using standard web selectors
            const inputs = document.querySelectorAll('input, textarea, select, [contenteditable="true"], [role="textbox"], [role="searchbox"], [role="combobox"]');
            console.log('Found', inputs.length, 'potential input elements');
            
            inputs.forEach((input, index) => {
                const rect = input.getBoundingClientRect();
                const style = window.getComputedStyle(input);
                
                console.log('Checking input', index, ':', input.tagName, input.type, rect);
                
                // Only include visible elements
                if (rect.width > 5 && rect.height > 5 && 
                    style.display !== 'none' && 
                    style.visibility !== 'hidden' &&
                    style.opacity !== '0') {
                    
                    results.push({
                        type: input.tagName.toLowerCase(),
                        inputType: input.type || input.getAttribute('role') || 'text',
                        placeholder: input.placeholder || input.getAttribute('aria-label') || '',
                        value: input.value || input.textContent || '',
                        id: input.id || '',
                        name: input.name || '',
                        className: input.className || '',
                        x: Math.round(rect.left + window.scrollX),
                        y: Math.round(rect.top + window.scrollY),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        isRequired: input.required || false,
                        isDisabled: input.disabled || false,
                        isFocused: document.activeElement === input,
                        ariaLabel: input.getAttribute('aria-label') || ''
                    });
                    console.log('Added input element:', results[results.length - 1]);
                }
            });
            
            // Find clickable buttons and links using standard selectors
            const clickables = document.querySelectorAll('button, input[type="submit"], input[type="button"], [role="button"], a[href], [onclick]');
            console.log('Found', clickables.length, 'potential clickable elements');
            
            clickables.forEach((element, index) => {
                const rect = element.getBoundingClientRect();
                const style = window.getComputedStyle(element);
                
                if (rect.width > 5 && rect.height > 5 && 
                    style.display !== 'none' && 
                    style.visibility !== 'hidden' &&
                    style.opacity !== '0') {
                    
                    results.push({
                        type: element.tagName.toLowerCase(),
                        text: element.textContent?.trim() || element.value || element.getAttribute('aria-label') || '',
                        title: element.title || element.getAttribute('aria-label') || '',
                        href: element.href || '',
                        role: element.getAttribute('role') || '',
                        className: element.className || '',
                        x: Math.round(rect.left + window.scrollX),
                        y: Math.round(rect.top + window.scrollY),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        isClickable: true
                    });
                }
            });
            
            console.log('Total results:', results.length);
            return JSON.stringify(results);
        })();
        """
        
        // Execute JavaScript based on browser type
        switch browserType {
        case .safari:
            return executeSafariJavaScript(javascript)
        case .chrome, .edge, .brave:
            return executeChromiumJavaScript(javascript, browserType: browserType)
        case .firefox:
            return executeFirefoxJavaScript(javascript)
        case .opera:
            return executeOperaJavaScript(javascript)
        }
    }
    
    // MARK: - Browser-Specific JavaScript Execution
    
    private func executeSafariJavaScript(_ javascript: String) -> [UIElement]? {
        let script = """
        tell application "Safari"
            try
                set jsResult to do JavaScript "\(javascript.replacingOccurrences(of: "\"", with: "\\\""))" in document 1
                return jsResult
            on error
                return "[]"
            end try
        end tell
        """
        
        return executeAppleScript(script)
    }
    
    private func executeChromiumJavaScript(_ javascript: String, browserType: BrowserType) -> [UIElement]? {
        let appName = browserType == .chrome ? "Google Chrome" : 
                     browserType == .edge ? "Microsoft Edge" :
                     browserType == .brave ? "Brave Browser" : "Chrome"
        
        let script = """
        tell application "\(appName)"
            try
                set jsResult to execute active tab of window 1 javascript "\(javascript.replacingOccurrences(of: "\"", with: "\\\""))"
                return jsResult
            on error
                return "[]"
            end try
        end tell
        """
        
        return executeAppleScript(script)
    }
    
    private func executeFirefoxJavaScript(_ javascript: String) -> [UIElement]? {
        // Firefox doesn't have good AppleScript support for JavaScript execution
        // Could use Firefox's WebDriver interface or command line tools
        print("⚠️ Firefox JavaScript injection not implemented yet")
        return nil
    }
    
    private func executeOperaJavaScript(_ javascript: String) -> [UIElement]? {
        // Opera might support Chromium-style AppleScript
        let script = """
        tell application "Opera"
            try
                -- Opera may not support JavaScript execution via AppleScript
                return "[]"
            on error
                return "[]"
            end try
        end tell
        """
        
        return executeAppleScript(script)
    }
    
    // MARK: - AppleScript Execution
    
    private func executeAppleScript(_ script: String) -> [UIElement]? {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        guard let result = appleScript?.executeAndReturnError(&error),
              error == nil else {
            let errorDesc = error?.description ?? "Unknown error"
            
            if errorDesc.contains("Allow JavaScript from Apple Events") {
                print("⚠️ Safari JavaScript injection requires enabling 'Allow JavaScript from Apple Events' in Safari > Developer Settings")
            } else if errorDesc.contains("Application isn't running") {
                print("⚠️ Target browser application is not running")
            } else if errorDesc.contains("doesn't understand") {
                print("⚠️ Browser doesn't support JavaScript execution via AppleScript")
            }
            return nil
        }
        
        guard let jsonString = result.stringValue else {
            return nil
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        return parseFormElementsJSON(jsonData)
    }
    
    // MARK: - JSON Parsing
    
    private func parseFormElementsJSON(_ jsonData: Data) -> [UIElement]? {
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                print("❌ Failed to parse JSON array")
                return nil
            }
            
            return jsonArray.compactMap { dict in
                createUIElementFromJSON(dict)
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
            return nil
        }
    }
    
    private func createUIElementFromJSON(_ dict: [String: Any]) -> UIElement? {
        guard let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let width = dict["width"] as? Double,
              let height = dict["height"] as? Double else {
            return nil
        }
        
        let position = CGPoint(x: x, y: y)
        let size = CGSize(width: width, height: height)
        
        // Determine element type and properties
        let elementType = dict["type"] as? String ?? "unknown"
        let isClickable = dict["isClickable"] as? Bool ?? false
        let text = dict["text"] as? String ?? dict["placeholder"] as? String ?? ""
        
        // Create appropriate element type
        let type: String
        
        if elementType == "input" || elementType == "textarea" {
            type = "WebTextField"
        } else if elementType == "select" {
            type = "WebSelect"
        } else if isClickable {
            type = "WebButton"
        } else {
            type = "WebElement"
        }
        
        // Create accessibility data
        let accessibilityData = AccessibilityData(
            role: type,
            description: dict["title"] as? String,
            title: dict["name"] as? String ?? dict["id"] as? String,
            help: nil,
            enabled: !(dict["isDisabled"] as? Bool ?? false),
            focused: dict["isFocused"] as? Bool ?? false,
            position: position,
            size: size,
            element: nil, // No AXUIElement for web elements
            subrole: dict["inputType"] as? String,
            value: dict["value"] as? String,
            selected: false,
            parent: nil,
            children: []
        )
        
        return UIElement(
            type: type,
            position: position,
            size: size,
            accessibilityData: accessibilityData,
            ocrData: text.isEmpty ? nil : OCRData(
                text: text,
                confidence: 0.9, // High confidence for DOM-extracted text
                boundingBox: CGRect(origin: position, size: size)
            ),
            isClickable: isClickable,
            confidence: 0.95 // High confidence for JavaScript-detected elements
        )
    }
    
    // MARK: - Element Merging
    
    private func mergeFormElements(existing: [UIElement], formElements: [UIElement]) -> [UIElement] {
        var merged = existing
        
        for formElement in formElements {
            // Check if this form element is already represented in existing elements
            let isDuplicate = existing.contains { existingElement in
                let distance = sqrt(
                    pow(existingElement.position.x - formElement.position.x, 2) +
                    pow(existingElement.position.y - formElement.position.y, 2)
                )
                return distance < 30 // Within 30 pixels
            }
            
            if !isDuplicate {
                merged.append(formElement)
                print("➕ Added web form element: \(formElement.type) at (\(formElement.position.x), \(formElement.position.y))")
            }
        }
        
        return merged
    }
}

// MARK: - Browser Types

enum BrowserType: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"
    case opera = "Opera"
    case brave = "Brave"
}

// MARK: - Browser Inspector Protocol

protocol BrowserInspecting {
    func enhanceBrowserElements(_ elements: [UIElement], browserType: BrowserType) -> [UIElement]
}

extension BrowserInspector: BrowserInspecting {} 