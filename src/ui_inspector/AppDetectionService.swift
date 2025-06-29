import Foundation
import AppKit

/// Service responsible for detecting and focusing target applications
class AppDetectionService {
    
    struct AppInfo {
        let bundleID: String
        let appName: String
        let displayName: String
        let runningApp: NSRunningApplication?
    }
    
    /// Detect the target application without activating it
    static func detectTargetApp() -> AppInfo? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Strategy 1: If frontmost is NOT the notch, use it
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let frontBundleID = frontApp.bundleIdentifier ?? ""
            if frontBundleID != "com.augment.augment" {
                return createAppInfo(from: frontApp)
            }
        }
        
        // Strategy 2: Notch is frontmost, find the "real" working app
        print("🔍 Notch detected as frontmost, finding target app...")
        if let targetApp = findBestTargetApp(runningApps) {
            return createAppInfo(from: targetApp)
        }
        
        // Strategy 3: Fallback to Safari
        print("⚠️  No suitable target app found, falling back to Safari")
        return createSafariAppInfo()
    }
    
    /// Complete app detection and focusing workflow
    static func detectAndFocusActiveApp() {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Strategy 1: If frontmost is NOT the notch, use it (but still focus it properly)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let frontBundleID = frontApp.bundleIdentifier ?? ""
            if frontBundleID != "com.augment.augment" {
                setBundleInfo(frontApp)
                ensureAppIsProperlyFocused(frontApp)
                return
            }
        }
        
        // Strategy 2: Notch is frontmost, find the "real" working app
        print("🔍 Notch detected as frontmost, finding target app...")
        let targetApp = findBestTargetApp(runningApps)
        if let app = targetApp {
            setBundleInfo(app)
            ensureAppIsProperlyFocused(app)
            return
        }
        
        // Strategy 3: Fallback to Safari
        print("⚠️  No suitable target app found, falling back to Safari")
        fallbackToSafari()
    }
    
    // MARK: - App Information Management
    
    static func setBundleInfo(_ app: NSRunningApplication) {
        AppConfig.bundleID = app.bundleIdentifier ?? ""
        AppConfig.appName = app.localizedName ?? ""
        AppConfig.displayName = app.localizedName ?? ""
        print("🎯 Selected target app: \(AppConfig.displayName) (\(AppConfig.bundleID))")
    }
    
    private static func createAppInfo(from app: NSRunningApplication) -> AppInfo {
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""
        let displayName = app.localizedName ?? ""
        print("🎯 Selected target app: \(displayName) (\(bundleID))")
        return AppInfo(bundleID: bundleID, appName: appName, displayName: displayName, runningApp: app)
    }
    
    static func findBestTargetApp(_ apps: [NSRunningApplication]) -> NSRunningApplication? {
        print("🔍 Finding target app (GPT will choose the best one from available apps list)...")
        
        // Simple strategy: Just avoid the notch and pick the most recently active app
        // GPT gets the full app list and can intelligently choose which app to use
        let candidateApps = apps.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return bundleID != "com.augment.augment" &&  // Not the notch
                   !app.isHidden &&                      // Not hidden
                   app.activationPolicy == .regular       // Regular app (not background service)
        }
        
        // Sort by activity (most recently active first)
        let sortedApps = candidateApps.sorted { app1, app2 in
            // Active apps first
            if app1.isActive && !app2.isActive { return true }
            if !app1.isActive && app2.isActive { return false }
            
            // Then by launch time (more recently launched first)
            let app1LaunchTime = app1.launchDate?.timeIntervalSinceNow ?? -Double.infinity
            let app2LaunchTime = app2.launchDate?.timeIntervalSinceNow ?? -Double.infinity
            return app1LaunchTime > app2LaunchTime
        }
        
        if let bestApp = sortedApps.first {
            print("✅ Selected most recently active app: \(bestApp.localizedName ?? "Unknown") (\(bestApp.bundleIdentifier ?? ""))")
            print("💡 GPT will choose the optimal app from the available apps list based on task context")
            return bestApp
        }
        
        print("❌ No suitable apps found")
        return nil
    }
    
    // MARK: - App Focusing and Window Management
    
    static func ensureAppIsProperlyFocused(_ app: NSRunningApplication) {
        print("🎯 Focusing target app: \(app.localizedName ?? "Unknown")")
        
        // Skip if app is already active and focused - no need to refocus
        if app.isActive && app.ownsMenuBar {
            print("  ✅ App already active and focused - skipping")
            return
        }
        
        // Activate the app to bring it to front (but keep notch visible)
        let activateStart = Date()
        app.activate(options: [])
        let activateTime = Date().timeIntervalSince(activateStart)
        print("  📱 App activation: \(String(format: "%.3f", activateTime))s")
        
        // Reduced polling for app to become active and focused 
        let pollStart = Date()
        let maxWaitTime: TimeInterval = 0.3 // Reduced from 2.0s to 0.3s
        let pollInterval: TimeInterval = 0.02 // Reduced from 0.05s to 0.02s (20ms)
        var attempts = 0
        let maxAttempts = Int(maxWaitTime / pollInterval)
        
        while attempts < maxAttempts {
            if app.isActive && app.ownsMenuBar {
                break
            }
            Thread.sleep(forTimeInterval: pollInterval)
            attempts += 1
        }
        
        let pollTime = Date().timeIntervalSince(pollStart)
        print("  🔄 App focus polling: \(String(format: "%.3f", pollTime))s (\(attempts) checks)")
        
        // Skip window arrangement if app is already properly focused
        if app.isActive && app.ownsMenuBar {
            print("  ✅ App properly focused - skipping window arrangement")
        } else {
            // Bring specific windows to front if needed
            let windowStart = Date()
            bringAppWindowsToFront(app)
            let windowTime = Date().timeIntervalSince(windowStart)
            print("  🪟 Window arrangement: \(String(format: "%.3f", windowTime))s")
        }
        
        // Reduced window availability polling
        let windowPollStart = Date()
        let windowMaxWait: TimeInterval = 0.1 // Reduced from 0.5s to 0.1s
        let windowAttempts = Int(windowMaxWait / pollInterval)
        var windowChecks = 0
        
        while windowChecks < windowAttempts {
            // Quick check for visible window - simplified logic
            let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            let hasVisibleWindow = windows.contains { window in
                guard let ownerName = window[kCGWindowOwnerName as String] as? String else { return false }
                return ownerName == (app.localizedName ?? "")
            }
            
            if hasVisibleWindow {
                break
            }
            Thread.sleep(forTimeInterval: pollInterval)
            windowChecks += 1
        }
        
        let windowPollTime = Date().timeIntervalSince(windowPollStart)
        print("  🪟 Window availability polling: \(String(format: "%.3f", windowPollTime))s (\(windowChecks) checks)")
        
        print("✅ App focusing complete")
    }
    
    static func bringAppWindowsToFront(_ app: NSRunningApplication) {
        guard let appName = app.localizedName, !appName.isEmpty else {
            print("⚠️  Cannot bring windows to front: missing app name")
            return
        }
        
        print("📱 Arranging windows for \(appName)")
        
        // Use AppleScript to bring windows forward without affecting the notch
        let script = """
        tell application "\(appName)"
            try
                if (count of windows) > 0 then
                    set index of front window to 1
                    set visible of front window to true
                end if
            on error errMsg
                -- Silently handle apps that don't support window management
            end try
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("⚠️  Window arrangement note: \(error.description)")
            } else {
                print("✅ Windows arranged successfully")
            }
        }
    }
    
    static func fallbackToSafari() {
        AppConfig.bundleID = "com.apple.Safari"
        AppConfig.appName = "Safari"
        AppConfig.displayName = "Safari"
        
        // Try to ensure Safari is running and focused
        if let safariApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first {
            ensureAppIsProperlyFocused(safariApp)
        } else {
            print("⚠️  Safari not running, will attempt to launch if needed")
        }
    }
    
    private static func createSafariAppInfo() -> AppInfo {
        let safariApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first
        
        if safariApp == nil {
            print("⚠️  Safari not running, will need to be launched")
        }
        
        return AppInfo(bundleID: "com.apple.Safari", appName: "Safari", displayName: "Safari", runningApp: safariApp)
    }
}

// MARK: - App Configuration
// Enhanced dynamic configuration - intelligently detects target application
struct AppConfig {
    static var bundleID: String = ""
    static var appName: String = ""
    static var displayName: String = ""
    
    /// Main detection method that coordinates the entire app detection workflow
    static func detectActiveApp() {
        AppDetectionService.detectAndFocusActiveApp()
    }
    
    // Other popular app configurations (examples):
    
    // Finder
    // static let bundleID = "com.apple.finder"
    // static let appName = "Finder"
    // static let displayName = "Finder"
    
    // Chrome
    // static let bundleID = "com.google.Chrome"
    // static let appName = "Google Chrome"
    // static let displayName = "Chrome"
    
    // Firefox
    // static let bundleID = "org.mozilla.firefox"
    // static let appName = "Firefox"
    // static let displayName = "Firefox"
    
    // VS Code
    // static let bundleID = "com.microsoft.VSCode"
    // static let appName = "Visual Studio Code"
    // static let displayName = "VS Code"
    
    // Terminal
    // static let bundleID = "com.apple.Terminal"
    // static let appName = "Terminal"
    // static let displayName = "Terminal"
    
    // TextEdit
    // static let bundleID = "com.apple.TextEdit"
    // static let appName = "TextEdit"
    // static let displayName = "TextEdit"
} 