"""
Handles macOS specific security and permissions checks.
"""

from ApplicationServices import AXIsProcessTrustedWithOptions, kAXTrustedCheckOptionPrompt
from Cocoa import NSWorkspace
import subprocess

def check_accessibility_permissions() -> bool:
    """
    Checks if the application has Accessibility (Input Monitoring) permissions
    without prompting the user.

    Returns:
        True if permissions are granted, False otherwise.
    """
    # This is the correct way to check for trust without triggering a prompt.
    # The function and key are imported directly from ApplicationServices.
    return AXIsProcessTrustedWithOptions({kAXTrustedCheckOptionPrompt: False})

def check_screen_recording_permissions() -> bool:
    """
    Checks if the application has Screen Recording permissions without prompting.
    
    Returns:
        True if permissions are granted, False otherwise.
    """
    try:
        # Test screen recording permission by trying a minimal screencapture
        # If this succeeds without prompting, we have permission
        result = subprocess.run([
            '/usr/sbin/screencapture', 
            '-x',  # no sound
            '-t', 'png',  # PNG format
            '-R', '0,0,1,1',  # minimal 1x1 region at 0,0
            '-'  # output to stdout (so we don't create files)
        ], capture_output=True, timeout=5)
        
        # If screencapture succeeded (exit code 0), we have permission
        return result.returncode == 0
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, Exception):
        # If screencapture fails, times out, or errors, assume no permission
        return False

def check_all_permissions() -> tuple[bool, str]:
    """
    Checks all required permissions for workflow recording.
    
    Returns:
        Tuple of (has_all_permissions, error_message)
    """
    accessibility_ok = check_accessibility_permissions()
    screen_recording_ok = check_screen_recording_permissions()
    
    if not accessibility_ok and not screen_recording_ok:
        return False, "Missing both Accessibility and Screen Recording permissions"
    elif not accessibility_ok:
        return False, "Missing Accessibility (Input Monitoring) permissions"
    elif not screen_recording_ok:
        return False, "Missing Screen Recording permissions"
    else:
        return True, "All permissions granted"

def get_frontmost_app_name() -> str:
    """
    Gets the name of the currently active application.

    Returns:
        The name of the frontmost application, or "Unknown" if it cannot be determined.
    """
    try:
        workspace = NSWorkspace.sharedWorkspace()
        active_app = workspace.frontmostApplication()
        if active_app:
            app_name = active_app.localizedName()
            bundle_id = active_app.bundleIdentifier()
            print(f"🔍 Detected app: {app_name} ({bundle_id})")  # Debug
            return app_name
        else:
            print("⚠️ No frontmost application found")  # Debug
    except Exception as e:
        print(f"❌ Error getting frontmost app: {e}")  # Debug
        # This can fail if called very rapidly or if there's no active GUI app.
        # Silently failing is better than crashing the recording process.
        pass
    return "Unknown" 