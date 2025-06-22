import Foundation
import AppKit
import ApplicationServices

// MARK: - Window Manager

class WindowManager: WindowDetecting {
    private static var cachedImage: NSImage?
    private static var lastCacheTime: Date?
    private static let cacheTimeout: TimeInterval = 2.0 // Extended cache for better performance
    private static var lastWindowFrame: CGRect?
    
    // NEW: Performance monitoring
    private static var captureAttempts = 0
    private static var cacheHits = 0
    private static var fallbackCount = 0
    private static var inMemorySuccesses = 0
    private static var tempFileSuccesses = 0
    private static var totalInMemoryTime: TimeInterval = 0
    private static var totalTempFileTime: TimeInterval = 0
    private static var totalFullScreenTime: TimeInterval = 0
    
    func getActiveWindow() -> WindowInfo? {
        return getAppWindow()
    }
    
    func captureWindow(_ window: WindowInfo) -> NSImage? {
        Self.captureAttempts += 1
        return captureWindowBoundsOptimized(window.frame)
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
    
    // MARK: - Optimized Screenshot Capture
    
    private func captureWindowBoundsOptimized(_ windowFrame: CGRect) -> NSImage? {
        // Advanced cache check with frame validation
        let now = Date()
        if let cachedImage = Self.cachedImage,
           let lastCache = Self.lastCacheTime,
           let lastFrame = Self.lastWindowFrame,
           now.timeIntervalSince(lastCache) < Self.cacheTimeout,
           lastFrame == windowFrame {
            Self.cacheHits += 1
            return cachedImage
        }
        
        // Strategy 1: Fast temp file capture (most reliable for window regions)
        if let image = captureWindowWithTempFileOptimized(windowFrame) {
            updateCache(image: image, frame: windowFrame, time: now)
            return image
        }
        
        // Strategy 2: Full-screen in-memory capture as fallback
        Self.fallbackCount += 1
        if let image = captureFullScreenInMemory() {
            updateCache(image: image, frame: windowFrame, time: now)
            return image
        }
        
        // Strategy 3: Full-screen temp file (last resort)
        if let image = captureFullScreenTempFile() {
            updateCache(image: image, frame: windowFrame, time: now)
            return image
        }
        
        return nil
    }
    
    // NEW: Ultra-fast temp file capture with optimizations
    private func captureWindowWithTempFileOptimized(_ windowFrame: CGRect) -> NSImage? {
        let startTime = Date()
        
        // Use RAM disk path for faster I/O (if available)
        let tempPath = "/tmp/ui_\(ProcessInfo.processInfo.processIdentifier).jpg"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        let x = Int(windowFrame.origin.x)
        let y = Int(windowFrame.origin.y)
        let w = Int(windowFrame.size.width)
        let h = Int(windowFrame.size.height)
        
        // Optimized arguments: -x (no sound), -t jpg (faster), -R (region)
        task.arguments = ["-x", "-t", "jpg", "-R", "\(x),\(y),\(w),\(h)", tempPath]
        task.standardError = Pipe() // Suppress error output
        task.standardOutput = Pipe() // Suppress stdout
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                
                // Immediate cleanup
                try? FileManager.default.removeItem(atPath: tempPath)
                Self.tempFileSuccesses += 1
                let captureTime = Date().timeIntervalSince(startTime)
                Self.totalTempFileTime += captureTime
                return image
            } else {
                try? FileManager.default.removeItem(atPath: tempPath)
            }
        } catch {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        return nil
    }
    
    // NEW: Reliable full-screen in-memory capture
    private func captureFullScreenInMemory() -> NSImage? {
        let startTime = Date()
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        // Full screen in-memory (this works reliably)
        task.arguments = ["-m", "-x", "-t", "png", "-"]
        task.standardError = Pipe()
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 && !data.isEmpty {
                Self.inMemorySuccesses += 1
                let image = NSImage(data: data)
                let captureTime = Date().timeIntervalSince(startTime)
                Self.totalFullScreenTime += captureTime
                return image
            }
        } catch {
            // Continue to next method
        }
        
        return nil
    }
    
    // NEW: Full-screen temp file fallback
    private func captureFullScreenTempFile() -> NSImage? {
        let startTime = Date()
        let tempPath = "/tmp/ui_full_\(ProcessInfo.processInfo.processIdentifier).png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-m", "-x", "-t", "png", tempPath]
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0,
               let image = NSImage(contentsOfFile: tempPath) {
                try? FileManager.default.removeItem(atPath: tempPath)
                Self.tempFileSuccesses += 1
                let captureTime = Date().timeIntervalSince(startTime)
                Self.totalFullScreenTime += captureTime
                return image
            }
        } catch {
            // Silent failure
        }
        
        try? FileManager.default.removeItem(atPath: tempPath)
        return nil
    }
    
    // NEW: Optimized cache management
    private func updateCache(image: NSImage, frame: CGRect, time: Date) {
        Self.cachedImage = image
        Self.lastCacheTime = time
        Self.lastWindowFrame = frame
    }
    
    // NEW: Performance diagnostics
    static func printCaptureStats() {
        guard DebugConfig.isEnabled else { return }
        
        let hitRate = captureAttempts > 0 ? Double(cacheHits) / Double(captureAttempts) * 100 : 0
        print("📊 Window Capture Stats:")
        print("   • Total attempts: \(captureAttempts)")
        print("   • Cache hits: \(cacheHits) (\(String(format: "%.1f", hitRate))%)")
        print("   • Fallbacks: \(fallbackCount)")
        print("   • In-memory successes: \(inMemorySuccesses) (\(String(format: "%.1f", Double(inMemorySuccesses) / Double(captureAttempts) * 100))%)")
        print("   • Temp file successes: \(tempFileSuccesses) (\(String(format: "%.1f", Double(tempFileSuccesses) / Double(captureAttempts) * 100))%)")
        print("   • Total in-memory time: \(totalInMemoryTime)s")
        print("   • Total temp file time: \(totalTempFileTime)s")
        print("   • Total full-screen time: \(totalFullScreenTime)s")
    }
    

    
    // MARK: - Batch Capture for Multiple Windows
    
    func captureWindowsBatch(_ windows: [WindowInfo]) -> [NSImage?] {
        // Parallel capture for multiple windows
        let dispatchGroup = DispatchGroup()
        var results: [NSImage?] = Array(repeating: nil, count: windows.count)
        let resultsQueue = DispatchQueue(label: "com.windowmanager.batch", attributes: .concurrent)
        
        for (index, window) in windows.enumerated() {
            dispatchGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let image = self.captureWindow(window)
                
                resultsQueue.async(flags: .barrier) {
                    results[index] = image
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.wait()
        return results
    }
    
    // MARK: - App Management
    
    func ensureAppWindow() {
        // OPTIMIZATION: Universal app activation using NSWorkspace (much faster than AppleScript)
        let bundleID = AppConfig.bundleID
        let appName = AppConfig.appName
        
        // Quick check if already active and has windows
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID && hasAppWindows(bundleIdentifier: bundleID) {
            // print("⚡ \(AppConfig.displayName) already active with windows, skipping setup")
            return
        }
        
        // Reduced debug output for performance
        // print("🔄 Activating \(AppConfig.displayName) using NSWorkspace...")
        
        // Use fast NSWorkspace APIs instead of slow AppleScript
        let workspace = NSWorkspace.shared
        
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            // App is running - just activate it
            app.activate(options: [])
            // print("⚡ Activated existing \(AppConfig.displayName) process")
        } else {
            // App not running - launch it using modern API
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                
                workspace.openApplication(at: appURL, configuration: configuration) { app, error in
                    if let error = error {
                        print("❌ Failed to launch \(AppConfig.displayName): \(error.localizedDescription)")
                    } else {
                        // print("🚀 Launched \(AppConfig.displayName) application")
                    }
                }
            } else {
                print("❌ Could not find application with bundle ID: \(bundleID)")
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