import Foundation
import AppKit
import ApplicationServices

class MenuBarInspector {
    
    // MARK: - Menu Bar Coordinate System
    
    struct MenuBarCoordinates {
        // Left side: App menus (M-M1 to M-M10)
        static let appMenuPositions = ["M-M1", "M-M2", "M-M3", "M-M4", "M-M5", "M-M6", "M-M7", "M-M8", "M-M9", "M-M10"]
        
        // Right side: System items (M-S1 to M-S10) 
        static let systemMenuPositions = ["M-S1", "M-S2", "M-S3", "M-S4", "M-S5", "M-S6", "M-S7", "M-S8", "M-S9", "M-S10"]
        
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
            
            // Get menu bar items using multiple approaches
            var allMenuItems: [[String: Any]] = []
            
            // Approach 1: Get app-specific menu items
            let appMenuItems = getAppMenuItems(for: frontmostApp)
            allMenuItems.append(contentsOf: appMenuItems)
            
            // Approach 2: Get system menu bar items (right side)
            let systemMenuItems = getSystemMenuBarItems()
            allMenuItems.append(contentsOf: systemMenuItems)
            
            // Approach 3: Fallback - get predictable menu structure
            if allMenuItems.isEmpty {
                allMenuItems = getMenuBarItemsFallback(for: frontmostApp)
            }
            
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
                    if index >= MenuBarCoordinates.appMenuPositions.count { break }
                    
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let title = titleRef as? String,
                       !title.isEmpty {
                        
                        let menuPosition = MenuBarCoordinates.appMenuPositions[index]
                        
                        menuItems.append([
                            "title": title,
                            "type": "appMenu",
                            "menuBarPosition": menuPosition,
                            "index": index,
                            "isSystemWide": false
                        ])
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
                if index >= MenuBarCoordinates.systemMenuPositions.count { break }
                
                var titleRef: CFTypeRef?
                var descriptionRef: CFTypeRef?
                
                // Try to get title or description
                let title = (AXUIElementCopyAttributeValue(extra, kAXTitleAttribute as CFString, &titleRef) == .success) 
                    ? (titleRef as? String) : nil
                let description = (AXUIElementCopyAttributeValue(extra, kAXDescriptionAttribute as CFString, &descriptionRef) == .success) 
                    ? (descriptionRef as? String) : nil
                
                let displayName = title ?? description ?? "System\(index + 1)"
                let menuPosition = MenuBarCoordinates.systemMenuPositions[index]
                
                menuItems.append([
                    "title": displayName,
                    "type": "systemMenu",
                    "menuBarPosition": menuPosition,
                    "index": index,
                    "isSystemWide": true
                ])
            }
        }
        
        return menuItems
    }
    
    // MARK: - Fallback Menu Detection
    
    private static func getMenuBarItemsFallback(for app: NSRunningApplication) -> [[String: Any]] {
        var menuItems: [[String: Any]] = []
        
        // Predictable menu structure for macOS apps
        let appName = app.localizedName ?? "App"
        let standardMenus = [
            ("Apple", "appMenu"),           // M1 - Always Apple menu
            (appName, "appMenu"),          // M2 - App name
            ("File", "appMenu"),           // M3 - File menu
            ("Edit", "appMenu"),           // M4 - Edit menu  
            ("View", "appMenu"),           // M5 - View menu
            ("Window", "appMenu"),         // M6 - Window menu
            ("Help", "appMenu")            // M7 - Help menu
        ]
        
        for (index, (menuTitle, menuType)) in standardMenus.enumerated() {
            if index >= MenuBarCoordinates.appMenuPositions.count { break }
            
            let menuPosition = MenuBarCoordinates.appMenuPositions[index]
            
            menuItems.append([
                "title": menuTitle,
                "type": menuType,
                "menuBarPosition": menuPosition,
                "index": index,
                "isSystemWide": false,
                "isFallback": true
            ])
        }
        
        // Add common system menu items (right side)
        let systemItems = [
            ("WiFi", "systemMenu"),        // S1
            ("Bluetooth", "systemMenu"),   // S2  
            ("Battery", "systemMenu"),     // S3
            ("Sound", "systemMenu"),       // S4
            ("Clock", "systemMenu"),       // S5
            ("Control Center", "systemMenu") // S6
        ]
        
        for (index, (itemTitle, itemType)) in systemItems.enumerated() {
            if index >= MenuBarCoordinates.systemMenuPositions.count { break }
            
            let menuPosition = MenuBarCoordinates.systemMenuPositions[index]
            
            menuItems.append([
                "title": itemTitle,
                "type": itemType,
                "menuBarPosition": menuPosition,
                "index": index,
                "isSystemWide": true,
                "isFallback": true
            ])
        }
        
        return menuItems
    }
} 