import Foundation
import AppKit
import QuartzCore

// MARK: - Application Constants
struct AppConstants {
    
    // MARK: - File Paths
    struct Paths {
        static let projectRoot = getProjectRoot()
        static let pythonExecutable = "\(projectRoot)/venv/bin/python3"
        static let mainScript = "\(projectRoot)/src/main.py"
        static let pythonPath = "\(projectRoot)/src"
        static let debugOutputDirectory = "\(projectRoot)/src/debug_output"
        static let swiftFrontendLog = "\(debugOutputDirectory)/swift_frontend.txt"
        static let swiftCrashLog = "\(debugOutputDirectory)/swift_crash_logs.txt"
        static let chatDebugLog = "\(debugOutputDirectory)/chat_debug.txt"
        
        // MARK: - Dynamic Project Root Detection
        private static func getProjectRoot() -> String {
            // Try to get the bundle path first (for when running as an app)
            if let bundlePath = Bundle.main.bundlePath as String? {
                let bundleURL = URL(fileURLWithPath: bundlePath)
                var currentURL = bundleURL.deletingLastPathComponent()
                
                // Look for characteristic files that indicate project root
                let projectMarkers = ["src", "augment", "Makefile", "requirements.txt"]
                
                // Search up to 5 levels up from the bundle
                for _ in 0..<5 {
                    let hasMarkers = projectMarkers.allSatisfy { marker in
                        FileManager.default.fileExists(atPath: currentURL.appendingPathComponent(marker).path)
                    }
                    
                    if hasMarkers {
                        return currentURL.path
                    }
                    
                    currentURL = currentURL.deletingLastPathComponent()
                }
            }
            
            // Fallback: try current working directory and its parents
            let currentDir = FileManager.default.currentDirectoryPath
            var currentURL = URL(fileURLWithPath: currentDir)
            let projectMarkers = ["src", "augment", "Makefile", "requirements.txt"]
            
            for _ in 0..<5 {
                let hasMarkers = projectMarkers.allSatisfy { marker in
                    FileManager.default.fileExists(atPath: currentURL.appendingPathComponent(marker).path)
                }
                
                if hasMarkers {
                    return currentURL.path
                }
                
                currentURL = currentURL.deletingLastPathComponent()
            }
            
            // Final fallback: use environment variable if set
            if let envRoot = ProcessInfo.processInfo.environment["AUGMENT_PROJECT_ROOT"] {
                return envRoot
            }
            
            // Last resort: current directory
            print("⚠️ Warning: Could not detect project root automatically. Using current directory: \(currentDir)")
            print("💡 Hint: Set AUGMENT_PROJECT_ROOT environment variable if needed")
            return currentDir
        }
    }
    
    // MARK: - UI Constants
    struct UI {
        struct Notch {
            static let baseWidth: CGFloat = 200
            static let expandedWidthPadding: CGFloat = 280
            static let collapsedWidthPadding: CGFloat = 80
            static let expandedHeightExtension: CGFloat = 112
            static let collapsedHeightExtension: CGFloat = 2
            static let hoverWidthIncrease: CGFloat = 16
            static let hoverHeightIncrease: CGFloat = 2
            static let cornerRadius: CGFloat = 16
        }
        
        struct Chat {
            static let messageMaxWidth: CGFloat = .infinity
            static let messagePadding: CGFloat = 12
            static let messageSpacing: CGFloat = 12
            static let avatarSize: CGFloat = 32
            static let minimumTrailingSpace: CGFloat = 40
        }
        
        struct Controls {
            static let leftPanelMinWidth: CGFloat = 350
            static let leftPanelMaxWidth: CGFloat = 450
            static let rightPanelMinWidth: CGFloat = 400
            static let textEditorMinHeight: CGFloat = 120
            static let errorViewMaxHeight: CGFloat = 100
        }
    }
    
    // MARK: - Animation Constants
    struct Animations {
        static let hoverDuration: Double = 0.2
        static let expansionDuration: Double = 0.5
        static let collapseDuration: Double = 0.4
        static let scrollAnimationDuration: Double = 0.2
        static let focusDelay: Double = 0.6
        static let scrollDelay: Double = 0.1
        
        static let expansionTimingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
        static let collapseTimingFunction = CAMediaTimingFunction(controlPoints: 0.8, 0.2, 0.2, 1.0)
    }
    
    // MARK: - Process Constants
    struct Process {
        static let terminationGraceTime: Double = 2.0
        static let pythonUnbufferedFlag = "-u"
        static let taskArgumentFlag = "--task"
    }
    
    // MARK: - Default Values
    struct Defaults {
        static let defaultInstruction = "Open Safari and go to Apple website"
        static let menuBarHeight: CGFloat = 24
        static let statusBarLevel: Int = Int(CGWindowLevelForKey(.statusWindow)) + 1
    }
    
    // MARK: - Debug Constants
    struct Debug {
        static let timestampFormat = "HH:mm:ss.SSS"
        static let contentPreviewLength = 200
        static let errorPreviewLength = 50
        static let linePreviewLength = 100
        static let contentMatchLength = 30
    }
}