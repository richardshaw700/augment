"""
Handles macOS specific security and permissions checks.
"""

from ApplicationServices import AXIsProcessTrustedWithOptions, kAXTrustedCheckOptionPrompt
from Cocoa import NSWorkspace

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