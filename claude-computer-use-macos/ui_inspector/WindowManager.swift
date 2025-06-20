import Foundation
import AppKit
import ApplicationServices

// MARK: - Window Manager

class WindowManager: WindowDetecting {
    private static var cachedImage: NSImage?
    private static var lastCacheTime: Date?
    private static let cacheTimeout: TimeInterval = 0.5 // 500ms cache
    
    func getActiveWindow() -> WindowInfo? {
        return getAppWindow()
    }
    
    func captureWindow(_ window: WindowInfo) -> NSImage? {
        return captureWindowBounds(window.frame)
    }
    
    // MARK: - Window Detection
    
    private func getAppWindow() -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find the frontmost app window
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowBounds = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  ownerName == AppConfig.appName,
                  layer == 0 else { // layer 0 = normal windows
                continue
            }
            
            // Extract bounds
            guard let x = windowBounds["X"] as? CGFloat,
                  let y = windowBounds["Y"] as? CGFloat,
                  let width = windowBounds["Width"] as? CGFloat,
                  let height = windowBounds["Height"] as? CGFloat,
                  width > 100, height > 100 else { // Filter out tiny windows
                continue
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            let title = window[kCGWindowName as String] as? String ?? AppConfig.displayName
            
            return WindowInfo(
                title: title,
                frame: frame,
                ownerName: ownerName,
                windowID: windowID,
                layer: layer
            )
        }
        
        return nil
    }
    
    // MARK: - Screenshot Capture
    
    private func captureWindowBounds(_ windowFrame: CGRect) -> NSImage? {
        // Check cache first for performance
        let now = Date()
        if let cachedImage = Self.cachedImage,
           let lastCache = Self.lastCacheTime,
           now.timeIntervalSince(lastCache) < Self.cacheTimeout {
            return cachedImage
        }
        
        print("📐 Capturing window bounds: \(windowFrame)")
        
        // Capture only the window region using screencapture with -R flag
        let tempPath = "/tmp/ui_window_\(Int(Date().timeIntervalSince1970)).png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // -R x,y,w,h captures specific region
        let x = Int(windowFrame.origin.x)
        let y = Int(windowFrame.origin.y)  
        let w = Int(windowFrame.size.width)
        let h = Int(windowFrame.size.height)
        
        task.arguments = ["-x", "-t", "png", "-R", "\(x),\(y),\(w),\(h)", tempPath]
        
        print("🔍 DEBUG: Attempting window capture with region: \(x),\(y),\(w),\(h)")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            print("🔍 DEBUG: Screencapture exit status: \(task.terminationStatus)")
            
            if task.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                // Cache for immediate reuse
                Self.cachedImage = image
                Self.lastCacheTime = now
                
                // Async cleanup
                DispatchQueue.global(qos: .utility).async {
                    try? FileManager.default.removeItem(atPath: tempPath)
                }
                print("✅ Window capture successful!")
                return image
            } else {
                print("❌ Window capture failed - no image created or exit status: \(task.terminationStatus)")
            }
        } catch {
            print("❌ Window capture failed: \(error)")
        }
        
        // Fallback to full screen if window capture fails
        print("⚠️ Falling back to full screen capture")
        return captureFullScreen()
    }
    
    private func captureFullScreen() -> NSImage? {
        // PERFORMANCE: Try direct capture first, fallback to temp file
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // -m: capture main display only, -x: no sounds, -t png: PNG format
        task.arguments = ["-m", "-x", "-t", "png", "-"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 && !data.isEmpty {
                return NSImage(data: data)
            }
        } catch {
            // Fallback to temp file method
        }
        
        // Fallback: Fast temp file capture
        let tempPath = "/tmp/ui_fast_\(Int(Date().timeIntervalSince1970)).png"
        let fallbackTask = Process()
        fallbackTask.launchPath = "/usr/sbin/screencapture"
        fallbackTask.arguments = ["-m", "-x", "-t", "png", tempPath]
        
        do {
            try fallbackTask.run()
            fallbackTask.waitUntilExit()
            
            if fallbackTask.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                // Async cleanup
                DispatchQueue.global(qos: .utility).async {
                    try? FileManager.default.removeItem(atPath: tempPath)
                }
                return image
            }
        } catch {
            print("❌ Both capture methods failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - App Management
    
    func ensureAppWindow() {
        // OPTIMIZATION: Universal app activation using NSWorkspace (much faster than AppleScript)
        let bundleID = AppConfig.bundleID
        let appName = AppConfig.appName
        
        // Quick check if already active and has windows
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID && hasAppWindows(bundleIdentifier: bundleID) {
            print("⚡ \(AppConfig.displayName) already active with windows, skipping setup")
            return
        }
        
        print("🔄 Activating \(AppConfig.displayName) using NSWorkspace...")
        
        // Use fast NSWorkspace APIs instead of slow AppleScript
        let workspace = NSWorkspace.shared
        
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            // App is running - just activate it
            app.activate(options: .activateIgnoringOtherApps)
            print("⚡ Activated existing \(AppConfig.displayName) process")
        } else {
            // App not running - launch it
            let success = workspace.launchApplication(appName)
            if success {
                print("🚀 Launched \(AppConfig.displayName) application")
            } else {
                print("❌ Failed to launch \(AppConfig.displayName)")
                return
            }
        }
        
        // OPTIMIZATION: Smart polling for any app windows
        waitForAppWindow(bundleIdentifier: bundleID, appName: appName, maxWait: Config.defaultWindowTimeout)
    }
    
    private func waitForAppWindow(bundleIdentifier: String, appName: String, maxWait: TimeInterval) {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWait {
            if hasAppWindows(bundleIdentifier: bundleIdentifier) {
                let actualWait = Date().timeIntervalSince(startTime)
                print("⚡ \(appName) window ready in \(String(format: "%.3f", actualWait))s")
                return
            }
            Thread.sleep(forTimeInterval: Config.gridSweepPollingInterval) // Poll every 50ms
        }
        
        let actualWait = Date().timeIntervalSince(startTime)
        print("⚠️  \(appName) window not ready after \(String(format: "%.3f", actualWait))s (timeout)")
    }
    
    private func hasAppWindows(bundleIdentifier: String) -> Bool {
        // Universal window detection using fast CGWindowList API
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Get the app name from bundle identifier
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              let appName = app.localizedName else {
            return false
        }
        
        // Look for windows from this specific app that are actually visible
        let appWindows = windowList.filter({ window in
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  ownerName == appName,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  windowLayer == 0, // Normal window layer (not background/overlay)
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                return false
            }
            
            // Window must have reasonable size (not just tiny UI elements)
            return width > 200 && height > 150
        })
        
        return !appWindows.isEmpty
    }
} 