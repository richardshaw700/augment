import Foundation
import AppKit
import ApplicationServices

class MenuBarInspector {
    
    // MARK: - Menu Bar Coordinate System
    
    struct MenuBarCoordinates {
        // Standard menu bar height and positioning
        static let menuBarHeight = 24
        static let menuBarY = 0  // Always at top of screen
    }
    
    // MARK: - Main Inspection Method
    
    static func inspectMenuBar() -> [String: Any] {
        var menuBarInfo: [String: Any] = [:]
        
        // Get the frontmost application info
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            menuBarInfo["activeApplication"] = [
                "name": frontmostApp.localizedName ?? "Unknown",
                "bundleIdentifier": frontmostApp.bundleIdentifier ?? "unknown"
            ]
            
            // Get menu bar items using accessibility API only
            var allMenuItems: [[String: Any]] = []
            
            // Get app-specific menu items
            let appMenuItems = getAppMenuItems(for: frontmostApp)
            allMenuItems.append(contentsOf: appMenuItems)
            
            // Get system menu bar items (right side)
            let systemMenuItems = getSystemMenuBarItems()
            allMenuItems.append(contentsOf: systemMenuItems)
            
            menuBarInfo["menuItems"] = allMenuItems
        }
        
        menuBarInfo["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        return menuBarInfo
    }
    
    // MARK: - App-Specific Menu Items
    
    private static func getAppMenuItems(for app: NSRunningApplication) -> [[String: Any]] {
        var menuItems: [[String: Any]] = []
        
        // Create accessibility element for the app
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Try to get the menu bar from the app
        var menuBarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)
        
        if result == .success, let menuBar = menuBarRef {
            let menuBarElement = menuBar as! AXUIElement
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                
                // Get main menu items (Apple, App, File, Edit, View, etc.)
                for (index, child) in children.enumerated() {
                    if index >= 10 { break } // Limit to first 10 menu items
                    
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let title = titleRef as? String,
                       !title.isEmpty {
                        
                        // Try to get actual position and size from accessibility API
                        var frameRef: CFTypeRef?
                        
                        // Only proceed if we can get real position and size data
                        var positionRef: CFTypeRef?
                        var sizeRef: CFTypeRef?
                        
                        if AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionRef) == .success,
                           let positionValue = positionRef,
                           AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef) == .success,
                           let sizeValue = sizeRef {
                            var position = CGPoint.zero
                            var size = CGSize.zero
                            
                            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) &&
                               AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                                print("📍 Menu '\(title)': position=\(position), size=\(size)")
                                
                                menuItems.append([
                                    "title": title,
                                    "type": "appMenu",
                                    "index": index,
                                    "isSystemWide": false,
                                    "actualPosition": ["x": Double(position.x), "y": Double(position.y)],
                                    "actualSize": ["width": Double(size.width), "height": Double(size.height)]
                                ])
                            } else {
                                print("⚠️ Could not extract position/size values for menu '\(title)'")
                            }
                        } else {
                            print("⚠️ No position/size attributes available for menu '\(title)' - skipping")
                        }
                    }
                }
            }
        }
        
        return menuItems
    }
    
    // MARK: - System Menu Bar Items
    
    private static func getSystemMenuBarItems() -> [[String: Any]] {
        var menuItems: [[String: Any]] = []
        
        // Get system-wide accessibility element
        let systemElement = AXUIElementCreateSystemWide()
        
        // Try to get menu bar extras (right side of menu bar)
        var menuExtrasRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemElement, "AXMenuBarExtras" as CFString, &menuExtrasRef) == .success,
           let menuExtras = menuExtrasRef as? [AXUIElement] {
            
            for (index, extra) in menuExtras.enumerated() {
                if index >= 10 { break } // Limit to first 10 system menu items
                
                var titleRef: CFTypeRef?
                var descriptionRef: CFTypeRef?
                
                // Try to get title or description
                let title = (AXUIElementCopyAttributeValue(extra, kAXTitleAttribute as CFString, &titleRef) == .success) 
                    ? (titleRef as? String) : nil
                let description = (AXUIElementCopyAttributeValue(extra, kAXDescriptionAttribute as CFString, &descriptionRef) == .success) 
                    ? (descriptionRef as? String) : nil
                
                let displayName = title ?? description ?? "System\(index + 1)"
                
                menuItems.append([
                    "title": displayName,
                    "type": "systemMenu",
                    "index": index,
                    "isSystemWide": true
                ])
            }
        }
        
        return menuItems
    }
} 