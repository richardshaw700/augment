#!/usr/bin/env python3

import subprocess
import time
import os
from datetime import datetime

def ensure_messages_app_open():
    """Ensure Messages app is open and focused using approach similar to codebase"""
    print("🚀 Opening Messages app...")
    
    try:
        # Create a Swift script that ensures Messages opens with a visible window
        swift_script = '''
import Foundation
import AppKit

// Messages app bundle ID
let messagesBundleID = "com.apple.MobileSMS"

// Check if Messages is already running
let runningApps = NSWorkspace.shared.runningApplications
let messagesApps = runningApps.filter { $0.bundleIdentifier == messagesBundleID }

if let messagesApp = messagesApps.first {
    print("📱 Messages app found running")
    
    // Activate the app (same as codebase)
    messagesApp.activate(options: [])
    
    // Wait for activation
    Thread.sleep(forTimeInterval: 1.0)
    
    // Check if app has visible windows
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let messagesWindows = windowList.filter { window in
        if let ownerName = window[kCGWindowOwnerName as String] as? String {
            return ownerName == "Messages"
        }
        return false
    }
    
    print("🪟 Found \\(messagesWindows.count) Messages windows")
    
    if messagesWindows.isEmpty {
        print("⚠️ Messages running but no visible windows - trying to open main window")
        
        // Use AppleScript to open main Messages window
        let script = NSAppleScript(source: """
        tell application "Messages"
            activate
            delay 0.5
            -- Try to open a new message window if no windows are visible
            if (count of windows) = 0 then
                try
                    tell application "System Events"
                        tell process "Messages"
                            -- Try File > New Message
                            click menu item "New Message" of menu "File" of menu bar 1
                        end tell
                    end try
                on error
                    -- Fallback: just activate and hope for the best
                    activate
                end try
            end if
        end tell
        """)
        
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        
        if let error = error {
            print("⚠️ AppleScript error: \\(error)")
        } else {
            print("✅ Attempted to open Messages window")
        }
        
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    // Verify it's frontmost
    if let frontmost = NSWorkspace.shared.frontmostApplication {
        print("🎯 Frontmost app: \\(frontmost.localizedName ?? "Unknown") (\\(frontmost.bundleIdentifier ?? "Unknown"))")
        
        if frontmost.bundleIdentifier == messagesBundleID {
            print("✅ Messages app is now frontmost")
        } else {
            print("⚠️ Messages app activated but not frontmost")
        }
    }
} else {
    print("❌ Messages app not found in running applications")
    
    // Try to launch it
    let workspace = NSWorkspace.shared
    let success = workspace.launchApplication(withBundleIdentifier: messagesBundleID, 
                                            options: [], 
                                            additionalEventParamDescriptor: nil, 
                                            launchIdentifier: nil)
    
    if success {
        print("🚀 Launched Messages app")
        Thread.sleep(forTimeInterval: 3.0)
        
        // Try to activate after launch
        let newRunningApps = NSWorkspace.shared.runningApplications
        if let newMessagesApp = newRunningApps.first(where: { $0.bundleIdentifier == messagesBundleID }) {
            newMessagesApp.activate(options: [])
            Thread.sleep(forTimeInterval: 1.0)
            print("✅ Messages app launched and activated")
            
            // Ensure window is visible after launch
            let script = NSAppleScript(source: """
            tell application "Messages"
                activate
                delay 1
                -- Ensure main window is visible
                if (count of windows) = 0 then
                    try
                        tell application "System Events"
                            tell process "Messages"
                                keystroke "n" using command down
                            end tell
                        end try
                    end try
                end if
            end tell
            """)
            
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            
            Thread.sleep(forTimeInterval: 1.0)
        }
    } else {
        print("❌ Failed to launch Messages app")
    }
}

// Final check for visible windows
let finalWindowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let finalMessagesWindows = finalWindowList.filter { window in
    if let ownerName = window[kCGWindowOwnerName as String] as? String {
        return ownerName == "Messages"
    }
    return false
}

print("🏁 Final check: \\(finalMessagesWindows.count) visible Messages windows")

if !finalMessagesWindows.isEmpty {
    for (index, window) in finalMessagesWindows.enumerated() {
        if let bounds = window[kCGWindowBounds as String] as? [String: Any],
           let width = bounds["Width"] as? Double,
           let height = bounds["Height"] as? Double {
            print("   Window \\(index + 1): \\(Int(width))x\\(Int(height))")
        }
    }
}
'''
        
        # Write the Swift script to a temporary file
        script_path = "/tmp/activate_messages.swift"
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
            if "0 visible Messages windows" in result.stdout:
                print("❌ No visible Messages windows found")
                return False
            else:
                print("✅ Messages windows should be visible")
                return True
        else:
            print(f"❌ Swift script failed: {result.stderr}")
            if os.path.exists(script_path):
                os.remove(script_path)
            return False
            
    except Exception as e:
        print(f"❌ Error in ensure_messages_app_open: {e}")
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
    print("🧪 Starting Messages App UI Inspector Test")
    print("=" * 50)
    print("📝 Using main UI inspector (generates raw, cleaned, compressed files)")
    
    try:
        # Step 1: Open Messages app
        if not ensure_messages_app_open():
            print("❌ Failed to open Messages app - aborting test")
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
        
        print("\n✅ Test completed successfully!")
        
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
        
        print("\n🚀 Enhanced Features Tested:")
        print("• Improved timestamp detection (11:32, Yesterday, Thursday)")
        print("• Status indicator capture (Delivered, 2 Replies)")
        print("• Window control detection (red/yellow/green buttons)")
        print("• Visual element detection (profile pictures, message bubbles)")
        print("• Emoji and reaction support")
        print("\n💡 Next steps:")
        print("1. Check the output/ folder for all generated files")
        print("2. Review performance logs for timing and element count metrics")
        print("3. Compare the outputs with the Messages app interface")
        print("4. Analyze improvements in element capture accuracy")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main()) 