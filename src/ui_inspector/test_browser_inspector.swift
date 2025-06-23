#!/usr/bin/env swift

import Foundation
import AppKit

// MARK: - Browser Types (copied from BrowserInspector.swift)

enum BrowserType: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"
    case opera = "Opera"
    case brave = "Brave"
}

// MARK: - Minimal BrowserInspector (for testing)

class BrowserInspector {
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
}

// MARK: - Simple Test Data Structures

struct TestUIElement {
    let type: String
    let position: CGPoint
    let size: CGSize
    let text: String
    let isClickable: Bool
    let confidence: Double
    let metadata: [String: Any]
}

struct TestAccessibilityData {
    let role: String
    let description: String?
    let title: String?
    let enabled: Bool
    let focused: Bool
}

// MARK: - Browser Inspector Test

class BrowserInspectorTest {
    
    func runTest() {
        print("🧪 Browser Inspector Test Suite")
        print(String(repeating: "=", count: 50))
        
        // Test 1: Check if we can detect browsers
        testBrowserDetection()
        
        // Test 2: Test JavaScript injection on current website
        testJavaScriptInjection()
        
        // Test 3: Test specific browser types
        testSpecificBrowsers()
        
        print("\n✅ Test suite completed!")
    }
    
    // MARK: - Test Browser Detection
    
    func testBrowserDetection() {
        print("\n🔍 Testing Browser Detection...")
        
        let testBundleIDs = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.unknown.app"
        ]
        
        for bundleID in testBundleIDs {
            let isBrowser = BrowserInspector.isBrowserApp(bundleID)
            let browserType = BrowserInspector.getBrowserType(bundleID)
            print("  \(bundleID): \(isBrowser ? "✅" : "❌") Browser, Type: \(browserType?.rawValue ?? "None")")
        }
    }
    
    // MARK: - Test JavaScript Injection
    
    func testJavaScriptInjection() {
        print("\n🌐 Testing JavaScript Injection...")
        
        // Get currently running browsers
        let runningApps = NSWorkspace.shared.runningApplications
        let browsers = runningApps.compactMap { app -> (NSRunningApplication, BrowserType)? in
            guard let bundleID = app.bundleIdentifier,
                  let browserType = BrowserInspector.getBrowserType(bundleID) else {
                return nil
            }
            return (app, browserType)
        }
        
        if browsers.isEmpty {
            print("❌ No supported browsers are currently running")
            print("💡 Please open Safari, Chrome, or Edge and navigate to a website")
            return
        }
        
        print("Found \(browsers.count) running browser(s):")
        for (app, browserType) in browsers {
            print("  - \(browserType.rawValue) (\(app.bundleIdentifier ?? "unknown"))")
        }
        
        // Prioritize Safari on macOS, then test others
        let sortedBrowsers = browsers.sorted { (first, second) in
            if first.1 == .safari { return true }
            if second.1 == .safari { return false }
            return first.1.rawValue < second.1.rawValue
        }
        
        for (_, browserType) in sortedBrowsers {
            print("\n🧪 Testing with \(browserType.rawValue)...")
            
            // Pre-check Safari permissions
            if browserType == .safari {
                if !testSafariPermissions() {
                    print("⏭️  Skipping Safari - permissions not enabled")
                    continue
                }
            }
            
            let testElements = testJavaScriptExtraction(browserType: browserType)
            
            if let elements = testElements, !elements.isEmpty {
                print("✅ JavaScript injection successful!")
                print("📊 Found \(elements.count) elements")
                saveTestResults(elements: elements, browserType: browserType)
                printElementSummary(elements: elements)
                return // Success! Stop testing other browsers
            } else {
                print("❌ JavaScript injection failed or returned no elements")
                testJavaScriptPermissions(browserType: browserType)
            }
        }
        
        print("\n❌ All browser tests failed. Please check permissions and try again.")
    }
    
    // MARK: - Safari Permission Testing
    
    func testSafariPermissions() -> Bool {
        print("🔐 Checking Safari JavaScript permissions...")
        
        // First check if Safari has windows open
        let windowCheckScript = """
        tell application "Safari"
            try
                return count of windows
            on error
                return 0
            end try
        end tell
        """
        
        let windowCheck = NSAppleScript(source: windowCheckScript)
        var error: NSDictionary?
        
        guard let windowResult = windowCheck?.executeAndReturnError(&error),
              let windowCount = windowResult.int32Value as Int32?,
              windowCount > 0 else {
            print("❌ Safari has no windows open")
            print("💡 Please open Safari and navigate to any website (e.g., https://netflix.com)")
            return false
        }
        
        print("✅ Safari has \(windowCount) window(s) open")
        
        // Test JavaScript permission with a simple command
        let jsTestScript = """
        tell application "Safari"
            try
                set testResult to do JavaScript "window.location.href" in document 1
                return "SUCCESS: " & testResult
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """
        
        let jsTest = NSAppleScript(source: jsTestScript)
        guard let jsResult = jsTest?.executeAndReturnError(&error),
              let resultString = jsResult.stringValue else {
            print("❌ AppleScript execution failed")
            return false
        }
        
        if resultString.hasPrefix("SUCCESS:") {
            let url = String(resultString.dropFirst(9))
            print("✅ JavaScript permissions enabled - Current URL: \(url)")
            return true
        } else {
            print("❌ JavaScript permissions not enabled")
            print("📋 To enable JavaScript in Safari:")
            print("   1. Safari → Settings (⌘,)")
            print("   2. Go to 'Advanced' tab")
            print("   3. Check 'Show features for developers'")
            print("   4. Click 'Developer' tab in the top right")
            print("   5. Check 'Allow JavaScript from Apple Events'")
            print("   6. Run this test again")
            return false
        }
    }
    
    // MARK: - JavaScript Extraction Test
    
    func testJavaScriptExtraction(browserType: BrowserType) -> [TestUIElement]? {
        let javascript = """
        (function() {
            console.log('🧪 BrowserInspector Test - Starting element detection...');
            const results = [];
            
            // Get current page info
            results.push({
                type: 'page_info',
                url: window.location.href,
                title: document.title,
                timestamp: new Date().toISOString(),
                viewport: {
                    width: window.innerWidth,
                    height: window.innerHeight
                }
            });
            
            // Find all clickable elements
            const clickables = document.querySelectorAll('a, button, input[type="submit"], input[type="button"], [role="button"], [onclick], nav a, .nav a, header a');
            console.log('Found', clickables.length, 'clickable elements');
            
            clickables.forEach((element, index) => {
                const rect = element.getBoundingClientRect();
                const style = window.getComputedStyle(element);
                
                // Only include visible elements
                if (rect.width > 0 && rect.height > 0 && 
                    style.display !== 'none' && 
                    style.visibility !== 'hidden' &&
                    parseFloat(style.opacity) > 0) {
                    
                    const text = element.textContent?.trim() || 
                                element.value || 
                                element.getAttribute('aria-label') || 
                                element.getAttribute('title') || 
                                element.getAttribute('alt') || '';
                    
                    results.push({
                        type: 'clickable',
                        tagName: element.tagName.toLowerCase(),
                        text: text,
                        href: element.href || '',
                        id: element.id || '',
                        className: element.className || '',
                        role: element.getAttribute('role') || '',
                        ariaLabel: element.getAttribute('aria-label') || '',
                        x: Math.round(rect.left + window.scrollX),
                        y: Math.round(rect.top + window.scrollY),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        isVisible: true,
                        isClickable: true,
                        zIndex: style.zIndex || 'auto',
                        fontSize: style.fontSize || '',
                        color: style.color || '',
                        backgroundColor: style.backgroundColor || ''
                    });
                }
            });
            
            // Find form inputs
            const inputs = document.querySelectorAll('input, textarea, select, [contenteditable="true"]');
            console.log('Found', inputs.length, 'input elements');
            
            inputs.forEach((input, index) => {
                const rect = input.getBoundingClientRect();
                const style = window.getComputedStyle(input);
                
                if (rect.width > 0 && rect.height > 0 && 
                    style.display !== 'none' && 
                    style.visibility !== 'hidden') {
                    
                    results.push({
                        type: 'input',
                        tagName: input.tagName.toLowerCase(),
                        inputType: input.type || 'text',
                        placeholder: input.placeholder || '',
                        value: input.value || '',
                        name: input.name || '',
                        id: input.id || '',
                        x: Math.round(rect.left + window.scrollX),
                        y: Math.round(rect.top + window.scrollY),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        isRequired: input.required || false,
                        isDisabled: input.disabled || false,
                        isFocused: document.activeElement === input
                    });
                }
            });
            
            console.log('Total elements found:', results.length);
            return JSON.stringify(results, null, 2);
        })();
        """
        
        return executeJavaScriptForBrowser(javascript: javascript, browserType: browserType)
    }
    
    // MARK: - Browser-Specific JavaScript Execution
    
    func executeJavaScriptForBrowser(javascript: String, browserType: BrowserType) -> [TestUIElement]? {
        print("🔧 Executing JavaScript in \(browserType.rawValue)...")
        
        let escapedJS = javascript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        
        let script: String
        
        switch browserType {
        case .safari:
            script = """
            tell application "Safari"
                try
                    if (count of windows) = 0 then
                        error "No Safari windows open"
                    end if
                    set jsResult to do JavaScript "\(escapedJS)" in document 1
                    return jsResult
                on error errMsg
                    return "ERROR: " & errMsg
                end try
            end tell
            """
            
        case .chrome, .edge, .brave:
            let appName = browserType == .chrome ? "Google Chrome" : 
                         browserType == .edge ? "Microsoft Edge" : "Brave Browser"
            script = """
            tell application "\(appName)"
                try
                    if (count of windows) = 0 then
                        error "No \(appName) windows open"
                    end if
                    set jsResult to execute active tab of window 1 javascript "\(escapedJS)"
                    return jsResult
                on error errMsg
                    return "ERROR: " & errMsg
                end try
            end tell
            """
            
        default:
            print("❌ Browser type \(browserType.rawValue) not supported for testing")
            return nil
        }
        
        // Execute AppleScript
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        guard let result = appleScript?.executeAndReturnError(&error) else {
            if let error = error {
                print("❌ AppleScript execution failed: \(error)")
                analyzeAppleScriptError(error)
            }
            return nil
        }
        
        guard let jsonString = result.stringValue else {
            print("❌ No string result from AppleScript")
            return nil
        }
        
        if jsonString.hasPrefix("ERROR:") {
            print("❌ JavaScript execution error: \(jsonString)")
            return nil
        }
        
        // Parse JSON result
        return parseTestResults(jsonString: jsonString)
    }
    
    // MARK: - Result Parsing
    
    func parseTestResults(jsonString: String) -> [TestUIElement]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert result to data")
            return nil
        }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                print("❌ Failed to parse JSON array")
                print("Raw result: \(jsonString.prefix(500))...")
                return nil
            }
            
            return jsonArray.compactMap { dict in
                parseTestElement(dict: dict)
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
            print("Raw result: \(jsonString.prefix(500))...")
            return nil
        }
    }
    
    func parseTestElement(dict: [String: Any]) -> TestUIElement? {
        guard let type = dict["type"] as? String else { return nil }
        
        if type == "page_info" {
            // Handle page info separately
            print("📄 Page Info:")
            print("  URL: \(dict["url"] as? String ?? "unknown")")
            print("  Title: \(dict["title"] as? String ?? "unknown")")
            if let viewport = dict["viewport"] as? [String: Any] {
                print("  Viewport: \(viewport["width"] ?? 0) x \(viewport["height"] ?? 0)")
            }
            return nil
        }
        
        guard let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let width = dict["width"] as? Double,
              let height = dict["height"] as? Double else {
            return nil
        }
        
        let text = dict["text"] as? String ?? ""
        let isClickable = dict["isClickable"] as? Bool ?? false
        
        return TestUIElement(
            type: type,
            position: CGPoint(x: x, y: y),
            size: CGSize(width: width, height: height),
            text: text,
            isClickable: isClickable,
            confidence: 0.95,
            metadata: dict
        )
    }
    
    // MARK: - Test Specific Browsers
    
    func testSpecificBrowsers() {
        print("\n🌐 Testing Specific Browser Capabilities...")
        
        // Test each browser type's AppleScript support
        for browserType in BrowserType.allCases {
            testBrowserAppleScriptSupport(browserType: browserType)
        }
    }
    
    func testBrowserAppleScriptSupport(browserType: BrowserType) {
        let appName = browserType == .chrome ? "Google Chrome" :
                     browserType == .edge ? "Microsoft Edge" :
                     browserType == .brave ? "Brave Browser" :
                     browserType.rawValue
        
        let script = """
        tell application "\(appName)"
            try
                if (count of windows) > 0 then
                    return "RUNNING"
                else
                    return "NO_WINDOWS"
                end if
            on error
                return "NOT_RUNNING"
            end try
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)
        
        let status = result?.stringValue ?? "ERROR"
        print("  \(browserType.rawValue): \(status)")
    }
    
    // MARK: - Permission Testing
    
    func testJavaScriptPermissions(browserType: BrowserType) {
        print("\n🔐 Testing JavaScript Permissions...")
        
        switch browserType {
        case .safari:
            print("📋 Safari JavaScript Permission Checklist:")
            print("  1. Safari > Preferences > Advanced > Show Develop menu")
            print("  2. Develop > Allow JavaScript from Apple Events")
            print("  3. Make sure Safari has a tab open with a website")
            
        case .chrome, .edge, .brave:
            print("📋 Chromium Browser Permission Checklist:")
            print("  1. Make sure browser allows AppleScript automation")
            print("  2. Check if browser has tabs open")
            print("  3. Some Chromium browsers may not support JavaScript via AppleScript")
            
        default:
            print("📋 Browser \(browserType.rawValue) may not support JavaScript injection")
        }
    }
    
    // MARK: - Error Analysis
    
    func analyzeAppleScriptError(_ error: NSDictionary) {
        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        
        print("🔍 AppleScript Error Analysis:")
        print("  Error Number: \(errorNumber)")
        print("  Error Message: \(errorMessage)")
        
        switch errorNumber {
        case -1728:
            print("  💡 This usually means the application doesn't understand the command")
            print("     Try enabling JavaScript permissions or check if the browser supports AppleScript")
        case -1743:
            print("  💡 This usually means the application is not running")
        case -10810:
            print("  💡 This usually means JavaScript execution is not allowed")
            print("     Enable 'Allow JavaScript from Apple Events' in Safari's Develop menu")
        default:
            print("  💡 Unknown error - check browser permissions and AppleScript support")
        }
    }
    
    // MARK: - Output and Reporting
    
    func saveTestResults(elements: [TestUIElement], browserType: BrowserType) {
        let timestamp = DateFormatter().string(from: Date()).replacingOccurrences(of: " ", with: "_")
        let filename = "browser_test_\(browserType.rawValue.lowercased())_\(timestamp).json"
        let outputPath = "src/ui_inspector/output/\(filename)"
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: elements.map { element in
                [
                    "type": element.type,
                    "position": ["x": element.position.x, "y": element.position.y],
                    "size": ["width": element.size.width, "height": element.size.height],
                    "text": element.text,
                    "isClickable": element.isClickable,
                    "confidence": element.confidence,
                    "metadata": element.metadata
                ]
            }, options: .prettyPrinted)
            
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            print("💾 Test results saved to: \(outputPath)")
        } catch {
            print("❌ Failed to save test results: \(error)")
        }
    }
    
    func printElementSummary(elements: [TestUIElement]) {
        print("\n📊 Element Summary:")
        
        let clickableElements = elements.filter { $0.isClickable }
        let inputElements = elements.filter { $0.type == "input" }
        
        print("  Total Elements: \(elements.count)")
        print("  Clickable Elements: \(clickableElements.count)")
        print("  Input Elements: \(inputElements.count)")
        
        print("\n🔗 Sample Clickable Elements:")
        for element in clickableElements.prefix(5) {
            let text = element.text.isEmpty ? "[no text]" : element.text.prefix(30)
            print("  - \(element.metadata["tagName"] ?? "unknown"): '\(text)' at (\(Int(element.position.x)), \(Int(element.position.y)))")
        }
        
        if !inputElements.isEmpty {
            print("\n📝 Sample Input Elements:")
            for element in inputElements.prefix(3) {
                let placeholder = element.metadata["placeholder"] as? String ?? ""
                print("  - \(element.metadata["inputType"] ?? "text"): '\(placeholder)' at (\(Int(element.position.x)), \(Int(element.position.y)))")
            }
        }
    }
}

// MARK: - Main Execution

let test = BrowserInspectorTest()
test.runTest() 