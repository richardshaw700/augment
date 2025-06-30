#!/usr/bin/env python3

# =============================================================================
# 🎛️ APP CONFIGURATION
# =============================================================================
# Change this to test different applications

APP_CONFIG = {
    # Choose which app to test by changing this value:
    # Options: "safari", "messages", "finder", "notes", "terminal"
    "CURRENT_APP": "safari",
    
    # App definitions
    "APPS": {
        "safari": {
            "name": "Safari",
            "bundle_id": "com.apple.Safari",
            "process_name": "Safari",
            "description": "Web browser with URL bar and page content",
            "expected_elements": ["text field", "button", "link"],
            "window_setup": """
            tell application "Safari"
                activate
                delay 1
                if (count of windows) = 0 then
                    make new document
                    delay 1
                end if
                -- Ensure we have a visible window
                if (count of windows) > 0 then
                    set visible of front window to true
                    set index of front window to 1
                end if
            end tell
            """
        },
        "messages": {
            "name": "Messages",
            "bundle_id": "com.apple.MobileSMS", 
            "process_name": "Messages",
            "description": "Messaging app with conversations and text input",
            "expected_elements": ["text field", "message", "conversation"],
            "window_setup": """
            tell application "Messages"
                activate
                delay 1
                if (count of windows) = 0 then
                    try
                        tell application "System Events"
                            tell process "Messages"
                                click menu item "New Message" of menu "File" of menu bar 1
                            end tell
                        end try
                    on error
                        activate
                    end try
                    delay 1
                end if
            end tell
            """
        },
        "finder": {
            "name": "Finder",
            "bundle_id": "com.apple.finder",
            "process_name": "Finder", 
            "description": "File manager with folders and files",
            "expected_elements": ["folder", "file", "sidebar"],
            "window_setup": """
            tell application "Finder"
                activate
                delay 1
                if (count of windows) = 0 then
                    make new Finder window
                    delay 1
                end if
                set target of front window to (path to desktop)
            end tell
            """
        },
        "notes": {
            "name": "Notes",
            "bundle_id": "com.apple.Notes",
            "process_name": "Notes",
            "description": "Note-taking app with text editing",
            "expected_elements": ["note", "text field", "list"],
            "window_setup": """
            tell application "Notes"
                activate
                delay 1
                if (count of windows) = 0 then
                    try
                        tell application "System Events"
                            tell process "Notes"
                                click menu item "New Note" of menu "File" of menu bar 1
                            end tell
                        end try
                    end try
                    delay 1
                end if
            end tell
            """
        },
        "terminal": {
            "name": "Terminal",
            "bundle_id": "com.apple.Terminal",
            "process_name": "Terminal",
            "description": "Command line interface",
            "expected_elements": ["text field", "terminal", "window"],
            "window_setup": """
            tell application "Terminal"
                activate
                delay 1
                if (count of windows) = 0 then
                    do script ""
                    delay 1
                end if
            end tell
            """
        }
    }
}

# =============================================================================
# 🚀 APPLICATION OPENING LOGIC
# =============================================================================

import subprocess
import time
import os
from datetime import datetime

def get_current_app_config():
    """Get the configuration for the currently selected app"""
    current_app = APP_CONFIG["CURRENT_APP"]
    if current_app not in APP_CONFIG["APPS"]:
        raise ValueError(f"App '{current_app}' not found in configuration. Available apps: {list(APP_CONFIG['APPS'].keys())}")
    
    return APP_CONFIG["APPS"][current_app]

def ensure_app_open():
    """Ensure the configured app is open and focused"""
    app_config = get_current_app_config()
    app_name = app_config["name"]
    bundle_id = app_config["bundle_id"]
    process_name = app_config["process_name"]
    window_setup = app_config["window_setup"]
    
    print(f"🚀 Opening {app_name}...")
    
    try:
        # Create a Swift script that ensures the app opens with a visible window
        swift_script = f'''
import Foundation
import AppKit

// App bundle ID and info
let appBundleID = "{bundle_id}"
let appName = "{app_name}"

// Check if app is already running
let runningApps = NSWorkspace.shared.runningApplications
let targetApps = runningApps.filter {{ $0.bundleIdentifier == appBundleID }}

if let targetApp = targetApps.first {{
    print("📱 \\(appName) app found running")
    
    // Activate the app
    targetApp.activate(options: [])
    
    // Wait for activation
    Thread.sleep(forTimeInterval: 1.0)
    
    // Check if app has visible windows
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let appWindows = windowList.filter {{ window in
        if let ownerName = window[kCGWindowOwnerName as String] as? String {{
            return ownerName == "{process_name}"
        }}
        return false
    }}
    
    print("🪟 Found \\(appWindows.count) \\(appName) windows")
    
    if appWindows.isEmpty {{
        print("⚠️ \\(appName) running but no visible windows - trying to open main window")
        
        // Use AppleScript to open main window
        let script = NSAppleScript(source: """
        {window_setup}
        """)
        
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        
        if let error = error {{
            print("⚠️ AppleScript error: \\(error)")
        }} else {{
            print("✅ Attempted to open \\(appName) window")
        }}
        
        Thread.sleep(forTimeInterval: 2.0)
    }}
    
    // Verify it's frontmost
    if let frontmost = NSWorkspace.shared.frontmostApplication {{
        print("🎯 Frontmost app: \\(frontmost.localizedName ?? "Unknown") (\\(frontmost.bundleIdentifier ?? "Unknown"))")
        
        if frontmost.bundleIdentifier == appBundleID {{
            print("✅ \\(appName) app is now frontmost")
        }} else {{
            print("⚠️ \\(appName) app activated but not frontmost")
        }}
    }}
}} else {{
    print("❌ \\(appName) app not found in running applications")
    
    // Try to launch it
    let workspace = NSWorkspace.shared
    let success = workspace.launchApplication(withBundleIdentifier: appBundleID, 
                                            options: [], 
                                            additionalEventParamDescriptor: nil, 
                                            launchIdentifier: nil)
    
    if success {{
        print("🚀 Launched \\(appName) app")
        Thread.sleep(forTimeInterval: 3.0)
        
        // Try to activate after launch
        let newRunningApps = NSWorkspace.shared.runningApplications
        if let newTargetApp = newRunningApps.first(where: {{ $0.bundleIdentifier == appBundleID }}) {{
            newTargetApp.activate(options: [])
            Thread.sleep(forTimeInterval: 1.0)
            print("✅ \\(appName) app launched and activated")
            
            // Ensure window is visible after launch
            let script = NSAppleScript(source: """
            {window_setup}
            """)
            
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            
            Thread.sleep(forTimeInterval: 1.0)
        }}
    }} else {{
        print("❌ Failed to launch \\(appName) app")
    }}
}}

// Final check for visible windows
let finalWindowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let finalAppWindows = finalWindowList.filter {{ window in
    if let ownerName = window[kCGWindowOwnerName as String] as? String {{
        return ownerName == "{process_name}"
    }}
    return false
}}

print("🏁 Final check: \\(finalAppWindows.count) visible \\(appName) windows")

if !finalAppWindows.isEmpty {{
    for (index, window) in finalAppWindows.enumerated() {{
        if let bounds = window[kCGWindowBounds as String] as? [String: Any],
           let width = bounds["Width"] as? Double,
           let height = bounds["Height"] as? Double {{
            print("   Window \\(index + 1): \\(Int(width))x\\(Int(height))")
        }}
    }}
}}
'''
        
        # Write the Swift script to a temporary file
        script_path = f"/tmp/activate_{APP_CONFIG['CURRENT_APP']}.swift"
        with open(script_path, 'w') as f:
            f.write(swift_script)
        
        # Run the Swift script
        print("🔧 Running Swift activation script...")
        result = subprocess.run([
            'swift', script_path
        ], capture_output=True, text=True, timeout=15)
        
        if result.returncode == 0:
            print("✅ Swift script completed successfully")
            print(f"📝 Output: {result.stdout.strip()}")
            
            # Additional wait for app to fully load
            time.sleep(2)
            
            # Clean up temp file
            os.remove(script_path)
            
            # Check if we have visible windows
            if f"0 visible {app_name} windows" in result.stdout:
                print(f"❌ No visible {app_name} windows found")
                return False
            else:
                print(f"✅ {app_name} windows should be visible")
                return True
        else:
            print(f"❌ Swift script failed: {result.stderr}")
            if os.path.exists(script_path):
                os.remove(script_path)
            return False
            
    except Exception as e:
        print(f"❌ Error in ensure_app_open: {e}")
        return False

def run_ui_inspector():
    """Run the main UI inspector on the current window"""
    print("🔍 Running Main UI Inspector...")
    
    # Get current directory and navigate to ui_inspector
    current_dir = os.path.dirname(os.path.abspath(__file__))
    ui_inspector_dir = os.path.dirname(current_dir)
    
    # Change to ui_inspector directory and run
    original_cwd = os.getcwd()
    os.chdir(ui_inspector_dir)
    
    try:
        # Run the main compiled UI inspector (not the regional one)
        result = subprocess.run(
            ['./compiled_ui_inspector'], 
            capture_output=True, 
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print("✅ Main UI Inspector completed successfully")
            
            # Write the output to latest_run_logs.txt in the output directory
            combined_output = result.stdout
            if result.stderr:
                combined_output += "\n" + result.stderr
            
            # Create output directory if it doesn't exist
            output_dir = os.path.join(ui_inspector_dir, 'output')
            os.makedirs(output_dir, exist_ok=True)
            
            logs_file = os.path.join(output_dir, 'latest_run_logs.txt')
            try:
                with open(logs_file, 'w') as f:
                    f.write(combined_output)
                print(f"📝 Performance logs written to: {logs_file}")
            except Exception as e:
                print(f"⚠️ Could not write performance logs: {e}")
            
            return result.stdout, result.stderr
        else:
            print(f"❌ Main UI Inspector failed with return code {result.returncode}")
            print(f"Error: {result.stderr}")
            
            # Still write logs even on failure for debugging
            combined_output = result.stdout + "\n" + result.stderr
            
            # Create output directory if it doesn't exist
            output_dir = os.path.join(ui_inspector_dir, 'output')
            os.makedirs(output_dir, exist_ok=True)
            
            logs_file = os.path.join(output_dir, 'latest_run_logs.txt')
            try:
                with open(logs_file, 'w') as f:
                    f.write(combined_output)
                print(f"📝 Error logs written to: {logs_file}")
            except Exception as e:
                print(f"⚠️ Could not write error logs: {e}")
            
            return None, result.stderr
            
    except subprocess.TimeoutExpired:
        print("⏰ UI Inspector timed out after 30 seconds")
        return None, "Timeout"
    except Exception as e:
        print(f"❌ Error running UI Inspector: {e}")
        return None, str(e)
    finally:
        # Return to original directory
        os.chdir(original_cwd)

def check_output_files():
    """Check what files were generated in the output directory"""
    ui_inspector_dir = os.path.dirname(os.path.dirname(__file__))
    output_files_dir = os.path.join(ui_inspector_dir, 'output')
    
    print(f"📁 Checking output directory: {output_files_dir}")
    
    if os.path.exists(output_files_dir):
        try:
            files = os.listdir(output_files_dir)
            if files:
                print(f"📋 Found {len(files)} files in output directory:")
                
                # Group files by type
                raw_files = [f for f in files if f.startswith('ui_raw_') and f.endswith('.json')]
                cleaned_files = [f for f in files if f.startswith('ui_cleaned_') and f.endswith('.json')]
                compressed_files = [f for f in files if f.startswith('ui_compressed_') and f.endswith('.txt')]
                log_files = [f for f in files if f.startswith('latest_run_logs') and f.endswith('.txt')]
                
                if raw_files:
                    latest_raw = max(raw_files, key=lambda f: os.path.getctime(os.path.join(output_files_dir, f)))
                    print(f"   📄 Raw JSON: {latest_raw}")
                
                if cleaned_files:
                    latest_cleaned = max(cleaned_files, key=lambda f: os.path.getctime(os.path.join(output_files_dir, f)))
                    print(f"   🧹 Cleaned JSON: {latest_cleaned}")
                
                if compressed_files:
                    latest_compressed = max(compressed_files, key=lambda f: os.path.getctime(os.path.join(output_files_dir, f)))
                    print(f"   📦 Compressed: {latest_compressed}")
                
                if log_files:
                    latest_logs = max(log_files, key=lambda f: os.path.getctime(os.path.join(output_files_dir, f)))
                    print(f"   📝 Logs: {latest_logs}")
                
                return True
            else:
                print("   📭 Output directory is empty")
                return False
                
        except Exception as e:
            print(f"⚠️ Could not read output directory: {e}")
            return False
    else:
        print("   ❌ Output directory does not exist")
        return False

def main():
    app_config = get_current_app_config()
    app_name = app_config["name"]
    description = app_config["description"]
    expected_elements = ", ".join(app_config["expected_elements"])
    
    print(f"🧪 Starting {app_name} UI Inspector Test")
    print("=" * 60)
    print(f"📱 App: {app_name}")
    print(f"📝 Description: {description}")
    print(f"🎯 Expected elements: {expected_elements}")
    print(f"🔧 Configuration: {APP_CONFIG['CURRENT_APP']}")
    print("=" * 60)
    print("📝 Using main UI inspector (generates raw, cleaned, compressed files)")
    
    try:
        # Step 1: Open the configured app
        if not ensure_app_open():
            print(f"❌ Failed to open {app_name} - aborting test")
            return 1
        
        # Step 2: Run main UI inspector
        stdout, stderr = run_ui_inspector()
        
        # Step 3: Check what files were generated
        files_generated = check_output_files()
        
        if stdout:
            print(f"\n📝 UI Inspector output ({len(stdout)} characters):")
            print("─" * 50)
            # Show last few lines of output
            lines = stdout.strip().split('\n')
            for line in lines[-10:]:
                print(f"   {line}")
        
        if stderr:
            print(f"\n⚠️ UI Inspector stderr ({len(stderr)} characters):")
            print("─" * 50)
            # Show last few lines of stderr
            lines = stderr.strip().split('\n')
            for line in lines[-5:]:
                print(f"   {line}")
        
        print(f"\n✅ {app_name} test completed successfully!")
        
        if files_generated:
            ui_inspector_dir = os.path.dirname(os.path.dirname(__file__))
            output_files_dir = os.path.join(ui_inspector_dir, 'output')
            print("\n📁 All output files are available in the main output directory:")
            print(f"   {os.path.abspath(output_files_dir)}")
            print("\n📋 File types generated:")
            print("• Raw JSON: Complete data with all accessibility/OCR information")
            print("• Cleaned JSON: Simplified data with essential element information")
            print("• Compressed: LLM-ready format for processing")
            print("• Performance Logs: Detailed timing and debug information")
        else:
            print("\n⚠️ No output files were generated - check for errors above")
        
        print(f"\n🚀 {app_name} Features Tested:")
        for element in app_config["expected_elements"]:
            print(f"• {element.title()} detection and analysis")
        print("• Window control detection (red/yellow/green buttons)")
        print("• Visual element detection and coordinate mapping")
        print("• Accessibility API integration")
        print("• OCR text recognition")
        
        print("\n💡 Next steps:")
        print("1. Check the output/ folder for all generated files")
        print("2. Review performance logs for timing and element count metrics")
        print(f"3. Compare the outputs with the {app_name} interface")
        print("4. Analyze improvements in element capture accuracy")
        
        print(f"\n🎛️ To test other apps, change CURRENT_APP in the config:")
        available_apps = [app for app in APP_CONFIG["APPS"].keys() if app != APP_CONFIG["CURRENT_APP"]]
        for app in available_apps:
            app_info = APP_CONFIG["APPS"][app]
            print(f"   • '{app}' - {app_info['description']}")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main()) 